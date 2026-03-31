#!/usr/bin/env python3
"""
Quality Gate Hook
Adapted from ECC quality-gate.js

Runs lightweight quality checks after file edits.
For Python files: ruff check, black --check.
Returns pass/fail with details.
"""

import os
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def _run_command(
    cmd: List[str],
    cwd: Optional[str] = None,
    timeout: int = 15,
) -> Tuple[int, str, str]:
    """
    Run a command and return (returncode, stdout, stderr).
    Returns (-1, '', error_message) if the command is not found or times out.
    """
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd or os.getcwd(),
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, "", "command not found: {}".format(cmd[0])
    except subprocess.TimeoutExpired:
        return -1, "", "timeout after {}s".format(timeout)
    except Exception as e:
        return -1, "", str(e)


def _check_python(file_path: str, fix: bool = False) -> List[Dict]:
    """Run Python quality checks: ruff and black."""
    results = []

    # Ruff check
    ruff_args = ["ruff", "check"]
    if fix:
        ruff_args.append("--fix")
    ruff_args.append(file_path)

    code, stdout, stderr = _run_command(ruff_args)
    if code == -1 and "not found" in stderr:
        pass  # ruff not installed, skip
    elif code != 0:
        results.append({
            "tool": "ruff",
            "passed": False,
            "output": (stdout + stderr).strip()[:500],
        })
    else:
        results.append({"tool": "ruff", "passed": True, "output": ""})

    # Ruff format check (replaces black)
    fmt_args = ["ruff", "format"]
    if not fix:
        fmt_args.append("--check")
    fmt_args.append(file_path)

    code, stdout, stderr = _run_command(fmt_args)
    if code == -1 and "not found" in stderr:
        # Try black as fallback
        black_args = ["black"]
        if not fix:
            black_args.append("--check")
        black_args.append(file_path)

        code, stdout, stderr = _run_command(black_args)
        if code == -1 and "not found" in stderr:
            pass  # neither ruff format nor black installed
        elif code != 0:
            results.append({
                "tool": "black",
                "passed": False,
                "output": (stdout + stderr).strip()[:500],
            })
        else:
            results.append({"tool": "black", "passed": True, "output": ""})
    elif code != 0:
        results.append({
            "tool": "ruff-format",
            "passed": False,
            "output": (stdout + stderr).strip()[:500],
        })
    else:
        results.append({"tool": "ruff-format", "passed": True, "output": ""})

    return results


def _check_go(file_path: str, fix: bool = False) -> List[Dict]:
    """Run Go quality checks: gofmt."""
    results = []

    if fix:
        args = ["gofmt", "-w", file_path]
    else:
        args = ["gofmt", "-l", file_path]

    code, stdout, stderr = _run_command(args)
    if code == -1 and "not found" in stderr:
        return results

    if fix:
        passed = code == 0
    else:
        passed = code == 0 and not stdout.strip()

    results.append({
        "tool": "gofmt",
        "passed": passed,
        "output": (stdout + stderr).strip()[:500] if not passed else "",
    })

    return results


def run_quality_gate(
    file_path: str,
    fix: bool = False,
) -> Dict:
    """
    Run quality gate checks on a file based on its extension.

    Args:
        file_path: Path to the edited file.
        fix: If True, attempt to auto-fix issues.

    Returns:
        Dict with 'passed' (bool), 'checks' (list of check results),
        and 'file_path'.
    """
    if not file_path or not os.path.exists(file_path):
        return {"passed": True, "checks": [], "file_path": file_path, "skipped": True}

    file_path = os.path.abspath(file_path)
    ext = os.path.splitext(file_path)[1].lower()

    checks = []

    if ext == ".py":
        checks = _check_python(file_path, fix=fix)
    elif ext == ".go":
        checks = _check_go(file_path, fix=fix)
    else:
        return {"passed": True, "checks": [], "file_path": file_path, "skipped": True}

    all_passed = all(c["passed"] for c in checks) if checks else True

    return {
        "passed": all_passed,
        "checks": checks,
        "file_path": file_path,
        "skipped": False,
    }


def run_quality_gate_from_input(tool_input: Dict, fix: bool = False) -> Dict:
    """Run quality gate from a tool input dict."""
    file_path = tool_input.get("file_path", "")
    return run_quality_gate(file_path, fix=fix)


if __name__ == "__main__":
    import json
    import sys

    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        file_path = data.get("tool_input", {}).get("file_path", "")
        fix = os.environ.get("MESH_QUALITY_GATE_FIX", "").lower() == "true"
        result = run_quality_gate(file_path, fix=fix)
        if not result["passed"]:
            sys.stderr.write("[QualityGate] Checks failed for {}\n".format(file_path))
            for check in result["checks"]:
                if not check["passed"]:
                    sys.stderr.write("  {}: {}\n".format(check["tool"], check["output"][:200]))
    except Exception:
        pass
    sys.stdout.write(raw)
