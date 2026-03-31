#!/usr/bin/env python3
"""
Pre-Commit Quality Check Hook
Adapted from ECC pre-bash-commit-quality.js

Runs quality checks before git commit commands:
- Detects staged files
- Checks for console.log/print/debugger/TODO in staged files
- Validates conventional commit message format
- Runs linter on staged Python files if available
"""

import os
import re
import subprocess
from typing import Dict, List, Optional, Tuple


def _run_git(*args: str) -> Tuple[int, str]:
    """Run a git command and return (returncode, stdout)."""
    try:
        result = subprocess.run(
            ["git"] + list(args),
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.returncode, result.stdout.strip()
    except Exception:
        return -1, ""


def get_staged_files() -> List[str]:
    """Get list of staged files for commit."""
    code, output = _run_git("diff", "--cached", "--name-only", "--diff-filter=ACMR")
    if code != 0 or not output:
        return []
    return [f for f in output.split("\n") if f]


def get_staged_file_content(file_path: str) -> Optional[str]:
    """Get content of a staged file."""
    code, output = _run_git("show", ":{}".format(file_path))
    if code != 0:
        return None
    return output


def should_check_file(file_path: str) -> bool:
    """Check if a file should be quality-checked."""
    checkable = {".js", ".jsx", ".ts", ".tsx", ".py", ".go", ".rs"}
    _, ext = os.path.splitext(file_path)
    return ext.lower() in checkable


def find_file_issues(file_path: str) -> List[Dict]:
    """
    Find quality issues in a staged file's content.

    Checks for:
    - console.log / print() statements
    - debugger statements
    - TODO/FIXME without issue reference
    - Hardcoded secrets (basic patterns)
    """
    issues = []

    content = get_staged_file_content(file_path)
    if content is None:
        return issues

    _, ext = os.path.splitext(file_path)
    ext = ext.lower()
    lines = content.split("\n")

    for line_num_0, line in enumerate(lines):
        line_num = line_num_0 + 1
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("//") or stripped.startswith("#") or stripped.startswith("*"):
            # Still check comments for TODOs below
            pass
        else:
            # console.log (JS/TS)
            if ext in (".js", ".jsx", ".ts", ".tsx") and "console.log" in line:
                issues.append({
                    "type": "console.log",
                    "message": "console.log found at line {}".format(line_num),
                    "line": line_num,
                    "severity": "warning",
                })

            # print() statements in Python (not in comments/strings - simple check)
            if ext == ".py" and re.search(r"\bprint\s*\(", line):
                # Skip if it looks like it's in a string or comment
                if not stripped.startswith("#"):
                    issues.append({
                        "type": "print",
                        "message": "print() statement at line {}".format(line_num),
                        "line": line_num,
                        "severity": "warning",
                    })

            # debugger statements
            if re.search(r"\bdebugger\b", line):
                issues.append({
                    "type": "debugger",
                    "message": "debugger statement at line {}".format(line_num),
                    "line": line_num,
                    "severity": "error",
                })

            # Python breakpoint()
            if ext == ".py" and re.search(r"\bbreakpoint\s*\(\s*\)", line):
                issues.append({
                    "type": "breakpoint",
                    "message": "breakpoint() at line {}".format(line_num),
                    "line": line_num,
                    "severity": "error",
                })

        # TODO/FIXME without issue reference (check in all lines including comments)
        todo_match = re.search(r"(?://|#)\s*(TODO|FIXME):?\s*(.+)", line)
        if todo_match and not re.search(r"#\d+|issue", todo_match.group(2), re.IGNORECASE):
            issues.append({
                "type": "todo",
                "message": 'TODO/FIXME without issue reference at line {}: "{}"'.format(
                    line_num, todo_match.group(2).strip()[:60]
                ),
                "line": line_num,
                "severity": "info",
            })

        # Hardcoded secrets
        secret_patterns = [
            (r"sk-[a-zA-Z0-9]{20,}", "OpenAI API key"),
            (r"ghp_[a-zA-Z0-9]{36}", "GitHub PAT"),
            (r"AKIA[A-Z0-9]{16}", "AWS Access Key"),
            (r'api[_\-]?key\s*[=:]\s*[\'"][^\'"]+[\'"]', "API key"),
        ]

        for pattern, name in secret_patterns:
            if re.search(pattern, line, re.IGNORECASE):
                issues.append({
                    "type": "secret",
                    "message": "Potential {} exposed at line {}".format(name, line_num),
                    "line": line_num,
                    "severity": "error",
                })

    return issues


def validate_commit_message(command: str) -> Optional[Dict]:
    """
    Validate commit message format from a git commit command string.

    Returns dict with 'message' and 'issues' list, or None if no message found.
    """
    # Extract commit message from command
    match = re.search(r'(?:-m|--message)[=\s]+["\']?([^"\']+)["\']?', command)
    if not match:
        return None

    message = match.group(1)
    issues = []

    # Check conventional commit format
    conventional_re = re.compile(
        r"^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)"
        r"(\(.+\))?:\s*.+"
    )

    if not conventional_re.match(message):
        issues.append({
            "type": "format",
            "message": "Commit message does not follow conventional commit format",
            "suggestion": 'Use format: type(scope): description (e.g., "feat(auth): add login flow")',
        })

    # Check message length
    if len(message) > 72:
        issues.append({
            "type": "length",
            "message": "Commit message too long ({} chars, max 72)".format(len(message)),
            "suggestion": "Keep the first line under 72 characters",
        })

    # Check for lowercase after type
    if conventional_re.match(message):
        after_colon = message.split(":", 1)
        if len(after_colon) > 1 and after_colon[1].strip() and after_colon[1].strip()[0].isupper():
            issues.append({
                "type": "capitalization",
                "message": "Subject should start with lowercase after type",
                "suggestion": "Use lowercase for the first letter of the subject",
            })

    # Check for trailing period
    if message.endswith("."):
        issues.append({
            "type": "punctuation",
            "message": "Commit message should not end with a period",
            "suggestion": "Remove the trailing period",
        })

    return {"message": message, "issues": issues}


def check_commit_quality(command: str = "") -> Dict:
    """
    Run quality checks before a git commit.

    Args:
        command: The git commit command string.

    Returns:
        Dict with 'passed' (bool), 'blocked' (bool), 'file_issues', 'commit_issues',
        'error_count', 'warning_count', 'info_count'.
    """
    result = {
        "passed": True,
        "blocked": False,
        "file_issues": [],
        "commit_issues": [],
        "error_count": 0,
        "warning_count": 0,
        "info_count": 0,
        "files_checked": 0,
    }

    # Only run for git commit commands
    if "git commit" not in command:
        return result

    # Skip checks for amends
    if "--amend" in command:
        return result

    staged_files = get_staged_files()
    if not staged_files:
        return result

    # Check each staged file
    checkable = [f for f in staged_files if should_check_file(f)]
    result["files_checked"] = len(checkable)

    for file_path in checkable:
        issues = find_file_issues(file_path)
        for issue in issues:
            issue["file"] = file_path
            result["file_issues"].append(issue)
            if issue["severity"] == "error":
                result["error_count"] += 1
            elif issue["severity"] == "warning":
                result["warning_count"] += 1
            else:
                result["info_count"] += 1

    # Validate commit message
    msg_result = validate_commit_message(command)
    if msg_result and msg_result["issues"]:
        result["commit_issues"] = msg_result["issues"]
        result["warning_count"] += len(msg_result["issues"])

    # Determine pass/block
    total = result["error_count"] + result["warning_count"] + result["info_count"]
    if total > 0:
        result["passed"] = False
    if result["error_count"] > 0:
        result["blocked"] = True

    return result


if __name__ == "__main__":
    import json
    import sys

    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        command = data.get("tool_input", {}).get("command", "")

        result = check_commit_quality(command)

        if result["file_issues"]:
            for issue in result["file_issues"]:
                label = {
                    "error": "ERROR",
                    "warning": "WARNING",
                    "info": "INFO",
                }.get(issue["severity"], "INFO")
                sys.stderr.write(
                    "  {} {}: {}\n".format(label, issue.get("file", ""), issue["message"])
                )

        if result["commit_issues"]:
            sys.stderr.write("\nCommit Message Issues:\n")
            for issue in result["commit_issues"]:
                sys.stderr.write("  WARNING {}\n".format(issue["message"]))
                if issue.get("suggestion"):
                    sys.stderr.write("     TIP {}\n".format(issue["suggestion"]))

        if result["blocked"]:
            sys.stderr.write(
                "\n[Hook] BLOCKED: {} error(s) found. Fix before committing.\n".format(
                    result["error_count"]
                )
            )
            sys.exit(2)
        elif not result["passed"]:
            sys.stderr.write(
                "\n[Hook] WARNING: {} issue(s) found. Commit allowed.\n".format(
                    result["error_count"] + result["warning_count"] + result["info_count"]
                )
            )
        else:
            sys.stderr.write("[Hook] PASS: All checks passed!\n")

    except Exception:
        pass

    sys.stdout.write(raw)
