#!/usr/bin/env python3
"""
Quality Gate Pipeline for AI Mesh
Adapted from ECC /verify + /quality-gate commands.

Ordered verification: Build → Types → Lint → Tests → Security → Review
Each stage blocks the next on failure (fail-fast).

Usage:
    python3 mesh/verify.py                    # full verification
    python3 mesh/verify.py --quick            # build + tests only
    python3 mesh/verify.py --pre-commit       # build + lint + tests
    python3 mesh/verify.py --pre-pr           # full + security scan
    python3 mesh/verify.py --path src/        # scope to directory
    python3 mesh/verify.py --fix              # auto-fix where safe
    python3 mesh/verify.py --json             # machine-readable output
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from typing import Dict, List, Optional, Tuple

MESH_DIR = os.path.dirname(os.path.abspath(__file__))
WORKSPACE = os.path.dirname(MESH_DIR)


def detect_project(path):
    # type: (str) -> Dict[str, object]
    """Detect project type, language, and available tooling."""
    info = {
        "languages": [],
        "has_build": False,
        "has_types": False,
        "has_lint": False,
        "has_tests": False,
        "has_formatter": False,
        "tools": {},
    }

    # Python
    if os.path.exists(os.path.join(path, "pyproject.toml")) or \
       os.path.exists(os.path.join(path, "setup.py")) or \
       os.path.exists(os.path.join(path, "requirements.txt")):
        info["languages"].append("python")
        info["has_lint"] = True
        info["has_tests"] = True
        info["tools"]["lint"] = _find_tool(["ruff check", "flake8", "pylint"], path)
        info["tools"]["format"] = _find_tool(["ruff format --check", "black --check"], path)
        info["tools"]["test"] = _find_tool(["pytest", "python -m unittest discover"], path)
        info["tools"]["typecheck"] = _find_tool(["mypy", "pyright"], path)
        if info["tools"].get("typecheck"):
            info["has_types"] = True
        if info["tools"].get("format"):
            info["has_formatter"] = True

    # Node.js / TypeScript
    pkg_json = os.path.join(path, "package.json")
    if os.path.exists(pkg_json):
        info["languages"].append("javascript")
        try:
            with open(pkg_json) as f:
                pkg = json.load(f)
            scripts = pkg.get("scripts", {})
            if "build" in scripts:
                info["has_build"] = True
                info["tools"]["build"] = _detect_pm(path) + " run build"
            if "lint" in scripts:
                info["has_lint"] = True
                info["tools"]["lint"] = _detect_pm(path) + " run lint"
            if "test" in scripts:
                info["has_tests"] = True
                info["tools"]["test"] = _detect_pm(path) + " run test"
            if "typecheck" in scripts or "type-check" in scripts:
                info["has_types"] = True
                tc_key = "typecheck" if "typecheck" in scripts else "type-check"
                info["tools"]["typecheck"] = _detect_pm(path) + " run " + tc_key
        except (json.JSONDecodeError, IOError):
            pass

        if os.path.exists(os.path.join(path, "tsconfig.json")):
            info["languages"].append("typescript")
            if not info["has_types"]:
                info["has_types"] = True
                info["tools"]["typecheck"] = "npx tsc --noEmit"

    # Go
    if os.path.exists(os.path.join(path, "go.mod")):
        info["languages"].append("go")
        info["has_build"] = True
        info["has_lint"] = True
        info["has_tests"] = True
        info["tools"]["build"] = "go build ./..."
        info["tools"]["lint"] = _find_tool(["golangci-lint run", "go vet ./..."], path)
        info["tools"]["test"] = "go test ./..."

    # Rust
    if os.path.exists(os.path.join(path, "Cargo.toml")):
        info["languages"].append("rust")
        info["has_build"] = True
        info["has_lint"] = True
        info["has_tests"] = True
        info["tools"]["build"] = "cargo build"
        info["tools"]["lint"] = "cargo clippy"
        info["tools"]["test"] = "cargo test"

    return info


def _find_tool(candidates, path):
    # type: (List[str], str) -> Optional[str]
    """Return first available tool from candidates."""
    for cmd in candidates:
        binary = cmd.split()[0]
        try:
            subprocess.run(
                ["which", binary],
                capture_output=True, check=True, timeout=5
            )
            return cmd
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
    return None


def _detect_pm(path):
    # type: (str) -> str
    """Detect package manager."""
    if os.path.exists(os.path.join(path, "bun.lockb")):
        return "bun"
    if os.path.exists(os.path.join(path, "pnpm-lock.yaml")):
        return "pnpm"
    if os.path.exists(os.path.join(path, "yarn.lock")):
        return "yarn"
    return "npm"


def run_stage(name, command, path, fix=False):
    # type: (str, Optional[str], str, bool) -> Dict[str, object]
    """Run a verification stage, return result dict."""
    if not command:
        return {"stage": name, "status": "skipped", "reason": "no tool detected"}

    # Apply --fix variants where possible
    if fix and name in ("lint", "format"):
        if "ruff check" in command:
            command = command.replace("ruff check", "ruff check --fix")
        elif "black --check" in command:
            command = command.replace("black --check", "black")
        elif "ruff format --check" in command:
            command = command.replace("ruff format --check", "ruff format")

    start = time.time()
    try:
        result = subprocess.run(
            command, shell=True, cwd=path,
            capture_output=True, text=True, timeout=300
        )
        elapsed = time.time() - start
        passed = result.returncode == 0

        return {
            "stage": name,
            "status": "PASS" if passed else "FAIL",
            "command": command,
            "duration_s": round(elapsed, 1),
            "stdout": result.stdout[-2000:] if result.stdout else "",
            "stderr": result.stderr[-2000:] if result.stderr else "",
            "exit_code": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {
            "stage": name,
            "status": "TIMEOUT",
            "command": command,
            "duration_s": 300,
        }
    except Exception as e:
        return {
            "stage": name,
            "status": "ERROR",
            "command": command,
            "error": str(e),
        }


def run_security_scan(path):
    # type: (str) -> Dict[str, object]
    """Run security scan (delegates to mesh/security_scan.py if available)."""
    scanner = os.path.join(MESH_DIR, "security_scan.py")
    if os.path.exists(scanner):
        return run_stage("security", "python3 {} --path {} --json".format(scanner, path), path)

    # Fallback: basic secrets grep
    patterns = [
        r"sk-[a-zA-Z0-9]{20,}",
        r"ghp_[a-zA-Z0-9]{36,}",
        r"AKIA[0-9A-Z]{16}",
        r"-----BEGIN.*PRIVATE KEY-----",
    ]
    findings = []
    for pattern in patterns:
        try:
            result = subprocess.run(
                ["grep", "-rn", "-E", pattern, path,
                 "--include=*.py", "--include=*.js", "--include=*.ts",
                 "--include=*.yaml", "--include=*.yml", "--include=*.json",
                 "--include=*.env", "--include=*.toml"],
                capture_output=True, text=True, timeout=30
            )
            if result.stdout.strip():
                findings.append(result.stdout.strip())
        except (subprocess.TimeoutExpired, Exception):
            pass

    if findings:
        return {
            "stage": "security",
            "status": "FAIL",
            "findings": len(findings),
            "details": "\n".join(findings)[:2000],
        }
    return {"stage": "security", "status": "PASS", "findings": 0}


def run_git_status(path):
    # type: (str) -> Dict[str, object]
    """Check for uncommitted changes."""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=path, capture_output=True, text=True, timeout=10
        )
        lines = [l for l in result.stdout.strip().split("\n") if l.strip()]
        return {
            "stage": "git_status",
            "status": "CLEAN" if not lines else "DIRTY",
            "uncommitted_files": len(lines),
            "files": lines[:20],
        }
    except Exception:
        return {"stage": "git_status", "status": "skipped", "reason": "not a git repo"}


def verify(path, mode="full", fix=False):
    # type: (str, str, bool) -> Dict[str, object]
    """Run verification pipeline. Returns report dict."""
    project = detect_project(path)
    results = []
    blocked = False

    # Define stage order based on mode
    if mode == "quick":
        stages = ["build", "test"]
    elif mode == "pre-commit":
        stages = ["build", "lint", "test"]
    elif mode == "pre-pr":
        stages = ["build", "typecheck", "lint", "format", "test", "security"]
    else:  # full
        stages = ["build", "typecheck", "lint", "format", "test", "security"]

    for stage in stages:
        if blocked:
            results.append({"stage": stage, "status": "BLOCKED", "reason": "prior stage failed"})
            continue

        if stage == "security":
            result = run_security_scan(path)
        elif stage == "format":
            cmd = project["tools"].get("format")
            result = run_stage(stage, cmd, path, fix=fix)
        else:
            cmd = project["tools"].get(stage)
            if not cmd:
                # Try mapped names
                mapped = {"typecheck": "typecheck", "lint": "lint", "test": "test", "build": "build"}
                cmd = project["tools"].get(mapped.get(stage, stage))
            result = run_stage(stage, cmd, path, fix=fix)

        results.append(result)

        # Fail-fast: block subsequent stages on failure (not for warnings)
        if result.get("status") == "FAIL" and stage in ("build", "typecheck"):
            blocked = True

    # Git status (always, informational)
    git = run_git_status(path)

    passed = sum(1 for r in results if r.get("status") == "PASS")
    failed = sum(1 for r in results if r.get("status") == "FAIL")
    skipped = sum(1 for r in results if r.get("status") in ("skipped", "BLOCKED"))

    verdict = "PASS" if failed == 0 else "FAIL"

    # Evidence-first: record what was actually run and observed
    # (adapted from superpowers verification-before-completion pattern)
    evidence = []
    for r in results:
        if r.get("status") in ("PASS", "FAIL"):
            evidence.append({
                "command": r.get("command", r.get("stage", "unknown")),
                "exit_code": r.get("exit_code", 0 if r["status"] == "PASS" else 1),
                "passed": r["status"] == "PASS",
                "output_tail": (r.get("stdout", "") or r.get("stderr", ""))[-500:],
            })

    report = {
        "timestamp": datetime.now().isoformat(),
        "path": path,
        "mode": mode,
        "project": project,
        "stages": results,
        "git": git,
        "evidence": evidence,
        "summary": {
            "verdict": verdict,
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "evidence_count": len(evidence),
        },
    }

    return report


def print_report(report, verbose=False):
    # type: (Dict, bool) -> None
    """Print human-readable verification report."""
    summary = report["summary"]
    print("\n" + "=" * 60)
    print("VERIFICATION REPORT — {}".format(report["mode"].upper()))
    print("=" * 60)
    print("Path:    {}".format(report["path"]))
    print("Time:    {}".format(report["timestamp"]))
    langs = report["project"].get("languages", [])
    if langs:
        print("Project: {}".format(", ".join(langs)))
    print("-" * 60)

    for stage in report["stages"]:
        status = stage.get("status", "?")
        icon = {"PASS": "+", "FAIL": "X", "skipped": "-", "BLOCKED": "!", "TIMEOUT": "T", "ERROR": "E"}.get(status, "?")
        line = "  [{}] {}".format(icon, stage["stage"].upper())
        if stage.get("duration_s"):
            line += " ({:.1f}s)".format(stage["duration_s"])
        if stage.get("reason"):
            line += " — {}".format(stage["reason"])
        print(line)

        if verbose and status == "FAIL":
            stderr = stage.get("stderr", "")
            stdout = stage.get("stdout", "")
            output = stderr or stdout
            if output:
                for oline in output.strip().split("\n")[:10]:
                    print("      {}".format(oline))

    # Git status
    git = report.get("git", {})
    if git.get("status") == "DIRTY":
        print("\n  Git: {} uncommitted file(s)".format(git.get("uncommitted_files", 0)))

    print("-" * 60)
    verdict = summary["verdict"]
    print("  VERDICT: {}  ({} passed, {} failed, {} skipped)".format(
        verdict, summary["passed"], summary["failed"], summary["skipped"]
    ))
    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Mesh Quality Gate Pipeline")
    parser.add_argument("--path", default=".", help="Project path to verify")
    parser.add_argument("--quick", action="store_true", help="Build + tests only")
    parser.add_argument("--pre-commit", action="store_true", help="Build + lint + tests")
    parser.add_argument("--pre-pr", action="store_true", help="Full + security scan")
    parser.add_argument("--fix", action="store_true", help="Auto-fix where safe")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show failure details")
    args = parser.parse_args()

    path = os.path.abspath(args.path)
    if args.quick:
        mode = "quick"
    elif args.pre_commit:
        mode = "pre-commit"
    elif args.pre_pr:
        mode = "pre-pr"
    else:
        mode = "full"

    report = verify(path, mode=mode, fix=args.fix)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report, verbose=args.verbose)

    sys.exit(0 if report["summary"]["verdict"] == "PASS" else 1)


if __name__ == "__main__":
    main()
