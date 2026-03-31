#!/usr/bin/env python3
"""
Config Protection Hook
Adapted from ECC config-protection.js

Blocks modifications to linter/formatter config files.
Agents frequently modify these to make checks pass instead of fixing
the actual code. This hook steers the agent back to fixing the source.
"""

import os
from pathlib import Path
from typing import Dict, List, Optional, Set

# Default protected file basenames
DEFAULT_PROTECTED_FILES: Set[str] = {
    # ESLint
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    ".eslintrc.yml",
    ".eslintrc.yaml",
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    "eslint.config.cts",
    # Prettier
    ".prettierrc",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    # Biome
    "biome.json",
    "biome.jsonc",
    # Ruff (Python)
    ".ruff.toml",
    "ruff.toml",
    # pyproject.toml intentionally NOT included - contains project metadata
    # alongside linter config; blocking all edits would prevent legitimate
    # dependency changes.
    # Shell / Style / Markdown
    ".shellcheckrc",
    ".stylelintrc",
    ".stylelintrc.json",
    ".stylelintrc.yml",
    ".markdownlint.json",
    ".markdownlint.yaml",
    ".markdownlintrc",
}


def check_config_protection(
    file_path: str,
    protected_files: Optional[Set[str]] = None,
) -> Optional[str]:
    """
    Check whether a file path points to a protected config file.

    Args:
        file_path: The path of the file being modified.
        protected_files: Optional custom set of protected basenames.
            Defaults to DEFAULT_PROTECTED_FILES.

    Returns:
        A warning/block message if the file is protected, or None if allowed.
    """
    if not file_path:
        return None

    if protected_files is None:
        protected_files = DEFAULT_PROTECTED_FILES

    basename = os.path.basename(file_path)

    if basename in protected_files:
        return (
            "BLOCKED: Modifying {} is not allowed. "
            "Fix the source code to satisfy linter/formatter rules instead of "
            "weakening the config. If this is a legitimate config change, "
            "disable the config-protection hook temporarily."
        ).format(basename)

    return None


def check_config_protection_from_input(
    tool_input: Dict,
    protected_files: Optional[Set[str]] = None,
) -> Optional[str]:
    """
    Check config protection from a tool input dict (as provided by hook system).

    Extracts file_path from tool_input.file_path or tool_input.file.
    """
    file_path = tool_input.get("file_path", tool_input.get("file", ""))
    return check_config_protection(file_path, protected_files)


def add_protected_file(basename: str) -> Set[str]:
    """Add a file basename to the default protected set. Returns the updated set."""
    DEFAULT_PROTECTED_FILES.add(basename)
    return DEFAULT_PROTECTED_FILES


def remove_protected_file(basename: str) -> Set[str]:
    """Remove a file basename from the default protected set. Returns the updated set."""
    DEFAULT_PROTECTED_FILES.discard(basename)
    return DEFAULT_PROTECTED_FILES


def list_protected_files() -> List[str]:
    """Return sorted list of currently protected file basenames."""
    return sorted(DEFAULT_PROTECTED_FILES)


if __name__ == "__main__":
    import json
    import sys

    raw = sys.stdin.read(1024 * 1024)
    try:
        data = json.loads(raw) if raw.strip() else {}
        tool_input = data.get("tool_input", {})
        result = check_config_protection_from_input(tool_input)
        if result:
            sys.stderr.write(result + "\n")
            sys.exit(2)
    except Exception:
        pass
    sys.stdout.write(raw)
