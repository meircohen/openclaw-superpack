#!/usr/bin/env python3
"""
Security Scanner for AI Mesh
Adapted from ECC security-reviewer agent + AgentShield.

Scans for:
- Hardcoded secrets (API keys, tokens, passwords)
- OWASP Top 10 patterns (SQL injection, XSS, CSRF, etc.)
- Dangerous shell patterns (command injection)
- Insecure configurations
- Dependency vulnerabilities (if audit tools available)

Usage:
    python3 mesh/security_scan.py                     # scan current directory
    python3 mesh/security_scan.py --path src/
    python3 mesh/security_scan.py --json              # machine-readable
    python3 mesh/security_scan.py --severity critical # filter by severity
    python3 mesh/security_scan.py --pre-commit        # check staged files only
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

MESH_DIR = os.path.dirname(os.path.abspath(__file__))

# Severity levels
CRITICAL = "CRITICAL"
HIGH = "HIGH"
MEDIUM = "MEDIUM"
LOW = "LOW"
INFO = "INFO"

# Secret patterns: (name, regex, severity, false_positive_hints)
SECRET_PATTERNS = [
    ("OpenAI API Key", r"sk-[a-zA-Z0-9]{20,}", CRITICAL,
     ["sk-example", "sk-test", "sk-your-key", "sk-xxx"]),
    ("GitHub PAT", r"ghp_[a-zA-Z0-9]{36,}", CRITICAL, []),
    ("GitHub OAuth", r"gho_[a-zA-Z0-9]{36,}", CRITICAL, []),
    ("AWS Access Key", r"AKIA[0-9A-Z]{16}", CRITICAL, ["AKIAIOSFODNN7EXAMPLE"]),
    ("AWS Secret Key", r"(?i)aws.{0,20}secret.{0,20}['\"][a-zA-Z0-9/+=]{40}['\"]", CRITICAL, []),
    ("Slack Token", r"xox[bpsa]-[a-zA-Z0-9-]+", HIGH, []),
    ("Slack Webhook", r"https://hooks\.slack\.com/services/T[a-zA-Z0-9_]+/B[a-zA-Z0-9_]+/[a-zA-Z0-9_]+", HIGH, []),
    ("Private Key", r"-----BEGIN.*PRIVATE KEY-----", CRITICAL, []),
    ("Generic API Key", r"(?i)(api[_-]?key|apikey)\s*[=:]\s*['\"][a-zA-Z0-9]{20,}['\"]", HIGH,
     ["your-api-key", "api-key-here", "example"]),
    ("Generic Secret", r"(?i)(secret|password|passwd|pwd)\s*[=:]\s*['\"][^'\"]{8,}['\"]", HIGH,
     ["your-secret", "password-here", "example", "changeme", "placeholder"]),
    ("Bearer Token", r"(?i)bearer\s+[a-zA-Z0-9_.~+/=-]{20,}", HIGH, ["your-token"]),
    ("Database URL with password", r"(?i)(postgres|mysql|mongodb)://[^:]+:[^@]+@", HIGH, []),
    ("Anthropic API Key", r"sk-ant-[a-zA-Z0-9-]{20,}", CRITICAL, []),
    ("Perplexity API Key", r"pplx-[a-zA-Z0-9]{20,}", HIGH, []),
]

# Code vulnerability patterns: (name, regex, severity, languages, description)
VULN_PATTERNS = [
    ("SQL Injection", r"(?i)(execute|query)\s*\(\s*['\"].*%s|\.format\(|f['\"].*\{.*\}.*(?:SELECT|INSERT|UPDATE|DELETE)",
     HIGH, ["python", "javascript", "typescript"],
     "Use parameterized queries instead of string interpolation"),
    ("Command Injection", r"(?i)(os\.system|subprocess\.call|exec\(|eval\(|child_process\.exec)\s*\(",
     HIGH, ["python", "javascript"],
     "Use subprocess.run with list args, avoid shell=True"),
    ("Shell=True", r"subprocess\.\w+\([^)]*shell\s*=\s*True",
     MEDIUM, ["python"],
     "Avoid shell=True; use list of arguments instead"),
    ("XSS innerHTML", r"\.innerHTML\s*=",
     HIGH, ["javascript", "typescript"],
     "Use textContent or sanitize with DOMPurify"),
    ("XSS dangerouslySetInnerHTML", r"dangerouslySetInnerHTML",
     MEDIUM, ["javascript", "typescript"],
     "Ensure input is sanitized before rendering"),
    ("Hardcoded IP/Host", r"(?:https?://)?(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?",
     LOW, ["*"],
     "Use environment variables for hosts/IPs"),
    ("Disabled SSL Verify", r"(?i)(verify\s*=\s*False|SSL_VERIFY.*false|rejectUnauthorized.*false)",
     HIGH, ["python", "javascript"],
     "Never disable SSL verification in production"),
    ("Debug Mode", r"(?i)(DEBUG\s*=\s*True|debug\s*:\s*true|NODE_ENV.*development)",
     MEDIUM, ["*"],
     "Ensure debug mode is disabled in production"),
    ("CORS Allow All", r"(?i)(Access-Control-Allow-Origin.*\*|cors\(\s*\)|allowedOrigins.*\*)",
     MEDIUM, ["*"],
     "Restrict CORS to specific origins"),
    ("Weak Crypto", r"(?i)(md5|sha1)\s*\(",
     MEDIUM, ["python", "javascript"],
     "Use SHA-256 or stronger hashing"),
    ("Pickle Load", r"pickle\.load\s*\(",
     HIGH, ["python"],
     "Pickle is unsafe for untrusted data; use json instead"),
    ("YAML Unsafe Load", r"yaml\.load\s*\([^)]*\)(?!\s*,\s*Loader)",
     MEDIUM, ["python"],
     "Use yaml.safe_load() instead of yaml.load()"),
]

# Files to skip
SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "__pycache__", ".tox",
             "dist", "build", ".next", ".nuxt", "vendor", ".eggs"}
SKIP_FILES = {".env.example", ".env.sample", ".env.template",
              "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
              "Cargo.lock", "go.sum", "poetry.lock"}
SCAN_EXTENSIONS = {".py", ".js", ".ts", ".tsx", ".jsx", ".go", ".rs",
                   ".java", ".kt", ".rb", ".php", ".yaml", ".yml",
                   ".json", ".toml", ".env", ".sh", ".bash", ".zsh",
                   ".conf", ".cfg", ".ini"}


def should_scan(filepath):
    # type: (str) -> bool
    """Determine if file should be scanned."""
    basename = os.path.basename(filepath)
    if basename in SKIP_FILES:
        return False
    _, ext = os.path.splitext(filepath)
    if ext not in SCAN_EXTENSIONS:
        return False
    parts = filepath.split(os.sep)
    for part in parts:
        if part in SKIP_DIRS:
            return False
    return True


def is_false_positive(match_text, hints):
    # type: (str, List[str]) -> bool
    """Check if match is a known false positive."""
    lower = match_text.lower()
    for hint in hints:
        if hint.lower() in lower:
            return True
    # Skip test files and examples for some patterns
    return False


def scan_file_secrets(filepath, content):
    # type: (str, str) -> List[Dict[str, Any]]
    """Scan a single file for secrets."""
    findings = []
    lines = content.split("\n")

    for line_num, line in enumerate(lines, 1):
        # Skip comments
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("//") or stripped.startswith("*"):
            continue

        for name, pattern, severity, fp_hints in SECRET_PATTERNS:
            for match in re.finditer(pattern, line):
                matched_text = match.group()
                if is_false_positive(matched_text, fp_hints):
                    continue
                # Check if it's in a test/example file
                if any(x in filepath.lower() for x in ["test", "example", "mock", "fixture", "spec"]):
                    severity = INFO  # Downgrade in test files

                findings.append({
                    "type": "secret",
                    "name": name,
                    "severity": severity,
                    "file": filepath,
                    "line": line_num,
                    "match": matched_text[:60] + "..." if len(matched_text) > 60 else matched_text,
                    "context": stripped[:100],
                })
    return findings


def scan_file_vulns(filepath, content):
    # type: (str, str) -> List[Dict[str, Any]]
    """Scan a single file for vulnerability patterns."""
    findings = []
    _, ext = os.path.splitext(filepath)
    file_lang = {
        ".py": "python", ".js": "javascript", ".ts": "typescript",
        ".tsx": "typescript", ".jsx": "javascript", ".go": "go",
        ".rs": "rust", ".java": "java", ".kt": "kotlin",
    }.get(ext, "unknown")

    lines = content.split("\n")

    for name, pattern, severity, languages, description in VULN_PATTERNS:
        if "*" not in languages and file_lang not in languages:
            continue

        for line_num, line in enumerate(lines, 1):
            stripped = line.strip()
            # Skip comments
            if stripped.startswith("#") or stripped.startswith("//"):
                continue

            if re.search(pattern, line):
                # Downgrade in test files
                effective_severity = severity
                if any(x in filepath.lower() for x in ["test", "mock", "fixture"]):
                    effective_severity = INFO

                findings.append({
                    "type": "vulnerability",
                    "name": name,
                    "severity": effective_severity,
                    "file": filepath,
                    "line": line_num,
                    "description": description,
                    "context": stripped[:100],
                })
    return findings


def scan_directory(path, staged_only=False):
    # type: (str, bool) -> List[Dict[str, Any]]
    """Scan directory tree for security issues."""
    all_findings = []

    if staged_only:
        # Only scan git staged files
        try:
            result = subprocess.run(
                ["git", "diff", "--cached", "--name-only"],
                cwd=path, capture_output=True, text=True, timeout=10
            )
            files = [os.path.join(path, f.strip()) for f in result.stdout.strip().split("\n") if f.strip()]
        except (subprocess.TimeoutExpired, Exception):
            files = []
    else:
        files = []
        for root, dirs, filenames in os.walk(path):
            # Filter directories
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for fname in filenames:
                filepath = os.path.join(root, fname)
                if should_scan(filepath):
                    files.append(filepath)

    for filepath in files:
        if not should_scan(filepath):
            continue
        try:
            with open(filepath, "r", errors="ignore") as f:
                content = f.read()
            # Skip very large files
            if len(content) > 500000:
                continue
            all_findings.extend(scan_file_secrets(filepath, content))
            all_findings.extend(scan_file_vulns(filepath, content))
        except (IOError, OSError):
            continue

    # Sort by severity
    severity_order = {CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3, INFO: 4}
    all_findings.sort(key=lambda f: severity_order.get(f.get("severity", INFO), 5))

    return all_findings


def check_dependencies(path):
    # type: (str) -> List[Dict[str, Any]]
    """Check for known vulnerable dependencies."""
    findings = []

    # npm audit
    if os.path.exists(os.path.join(path, "package-lock.json")):
        try:
            result = subprocess.run(
                ["npm", "audit", "--json"],
                cwd=path, capture_output=True, text=True, timeout=30
            )
            if result.returncode != 0 and result.stdout:
                try:
                    audit = json.loads(result.stdout)
                    vulns = audit.get("vulnerabilities", {})
                    for pkg, info in vulns.items():
                        sev = info.get("severity", "moderate").upper()
                        if sev == "MODERATE":
                            sev = MEDIUM
                        findings.append({
                            "type": "dependency",
                            "name": "Vulnerable dependency: {}".format(pkg),
                            "severity": sev,
                            "file": "package-lock.json",
                            "description": info.get("title", ""),
                        })
                except json.JSONDecodeError:
                    pass
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # pip-audit (if available)
    if os.path.exists(os.path.join(path, "requirements.txt")):
        try:
            result = subprocess.run(
                ["pip-audit", "--format", "json", "-r", "requirements.txt"],
                cwd=path, capture_output=True, text=True, timeout=30
            )
            if result.stdout:
                try:
                    audit = json.loads(result.stdout)
                    for vuln in audit:
                        findings.append({
                            "type": "dependency",
                            "name": "Vulnerable: {} {}".format(
                                vuln.get("name", "?"), vuln.get("version", "")),
                            "severity": HIGH,
                            "file": "requirements.txt",
                            "description": vuln.get("id", ""),
                        })
                except json.JSONDecodeError:
                    pass
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return findings


def generate_report(findings, path, include_deps=True):
    # type: (List[Dict], str, bool) -> Dict[str, Any]
    """Generate security scan report."""
    by_severity = {}
    for f in findings:
        sev = f.get("severity", INFO)
        if sev not in by_severity:
            by_severity[sev] = []
        by_severity[sev].append(f)

    critical = len(by_severity.get(CRITICAL, []))
    high = len(by_severity.get(HIGH, []))
    medium = len(by_severity.get(MEDIUM, []))
    low = len(by_severity.get(LOW, []))
    info = len(by_severity.get(INFO, []))

    if critical > 0:
        verdict = "FAIL"
    elif high > 0:
        verdict = "WARNING"
    else:
        verdict = "PASS"

    return {
        "timestamp": datetime.now().isoformat(),
        "path": path,
        "verdict": verdict,
        "total_findings": len(findings),
        "by_severity": {
            "critical": critical,
            "high": high,
            "medium": medium,
            "low": low,
            "info": info,
        },
        "findings": findings,
    }


def print_report(report, severity_filter=None, verbose=False):
    # type: (Dict, Optional[str], bool) -> None
    """Print human-readable security report."""
    print("\n" + "=" * 60)
    print("SECURITY SCAN REPORT")
    print("=" * 60)
    print("Path:     {}".format(report["path"]))
    print("Time:     {}".format(report["timestamp"]))
    print("Verdict:  {}".format(report["verdict"]))
    print("-" * 60)

    sev = report["by_severity"]
    print("  CRITICAL: {}  HIGH: {}  MEDIUM: {}  LOW: {}  INFO: {}".format(
        sev["critical"], sev["high"], sev["medium"], sev["low"], sev["info"]))
    print("-" * 60)

    severity_order = [CRITICAL, HIGH, MEDIUM, LOW, INFO]
    if severity_filter:
        idx = severity_order.index(severity_filter.upper())
        severity_order = severity_order[:idx + 1]

    for finding in report["findings"]:
        if finding["severity"] not in severity_order:
            continue
        icon = {"CRITICAL": "!!", "HIGH": "! ", "MEDIUM": "- ", "LOW": ". ", "INFO": "  "}.get(
            finding["severity"], "  ")
        print("  [{}] {} ({})".format(icon, finding["name"], finding["severity"]))
        if finding.get("file"):
            loc = finding["file"]
            if finding.get("line"):
                loc += ":{}".format(finding["line"])
            print("       {}".format(loc))
        if verbose and finding.get("context"):
            print("       > {}".format(finding["context"]))
        if finding.get("description"):
            print("       Fix: {}".format(finding["description"]))

    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Mesh Security Scanner")
    parser.add_argument("--path", default=".", help="Path to scan")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--severity", choices=["critical", "high", "medium", "low", "info"],
                        help="Minimum severity to show")
    parser.add_argument("--pre-commit", action="store_true", help="Scan staged files only")
    parser.add_argument("--no-deps", action="store_true", help="Skip dependency audit")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show context lines")
    args = parser.parse_args()

    path = os.path.abspath(args.path)
    findings = scan_directory(path, staged_only=args.pre_commit)

    if not args.no_deps:
        findings.extend(check_dependencies(path))

    report = generate_report(findings, path)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report, severity_filter=args.severity, verbose=args.verbose)

    # Exit code: 1 if critical findings, 2 if high, 0 otherwise
    if report["by_severity"]["critical"] > 0:
        sys.exit(1)
    elif report["by_severity"]["high"] > 0:
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
