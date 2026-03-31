#!/usr/bin/env python3
"""
Session Evaluator Hook (Continuous Learning)
Adapted from ECC evaluate-session.js

Runs at session end to extract reusable patterns from sessions.
Only evaluates sessions with a minimum number of interactions.
Saves discovered patterns to a learnings directory.
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

LEARNINGS_DIR = Path.home() / ".openclaw" / "workspace" / "mesh" / "learnings"
MIN_SESSION_LENGTH = 10


def _count_user_messages(transcript_path: str) -> int:
    """Count user messages in a JSONL transcript file."""
    count = 0
    try:
        with open(transcript_path) as f:
            for line in f:
                if re.search(r'"type"\s*:\s*"user"', line):
                    count += 1
    except OSError:
        pass
    return count


def _extract_patterns(transcript_path: str) -> List[Dict[str, Any]]:
    """
    Extract reusable patterns from a session transcript.

    Patterns include:
    - Repeated tool sequences (workflows)
    - Error-recovery patterns (what failed and how it was fixed)
    - Frequently accessed files
    """
    patterns = []
    tool_sequence = []
    files_accessed = {}
    errors_and_fixes = []

    try:
        with open(transcript_path) as f:
            prev_error = None
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Track tool usage sequences
                tool_name = entry.get("tool_name", entry.get("name", ""))
                if tool_name:
                    tool_sequence.append(tool_name)

                    # Track file access frequency
                    file_path = (
                        entry.get("tool_input", {}).get("file_path", "")
                        or entry.get("input", {}).get("file_path", "")
                    )
                    if file_path:
                        files_accessed[file_path] = files_accessed.get(file_path, 0) + 1

                # Track error/recovery patterns
                if entry.get("type") == "tool_result":
                    is_error = entry.get("is_error", False)
                    if is_error:
                        prev_error = entry.get("content", "")[:200]
                    elif prev_error and tool_name:
                        errors_and_fixes.append({
                            "error": prev_error,
                            "recovery_tool": tool_name,
                        })
                        prev_error = None

                # Extract from assistant content blocks
                if entry.get("type") == "assistant":
                    content = entry.get("message", {}).get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get("type") == "tool_use":
                                tool_name = block.get("name", "")
                                if tool_name:
                                    tool_sequence.append(tool_name)
                                    fp = block.get("input", {}).get("file_path", "")
                                    if fp:
                                        files_accessed[fp] = files_accessed.get(fp, 0) + 1

    except OSError:
        pass

    # Extract workflow patterns (repeated subsequences of 3+ tools)
    if len(tool_sequence) >= 6:
        # Simple pattern: find most common consecutive triples
        triples = {}
        for i in range(len(tool_sequence) - 2):
            key = " -> ".join(tool_sequence[i:i + 3])
            triples[key] = triples.get(key, 0) + 1

        for seq, count in sorted(triples.items(), key=lambda x: -x[1])[:5]:
            if count >= 2:
                patterns.append({
                    "type": "workflow",
                    "sequence": seq,
                    "frequency": count,
                })

    # Most frequently accessed files
    for file_path, count in sorted(files_accessed.items(), key=lambda x: -x[1])[:10]:
        if count >= 3:
            patterns.append({
                "type": "hot_file",
                "file": file_path,
                "access_count": count,
            })

    # Error recovery patterns
    for ef in errors_and_fixes[:5]:
        patterns.append({
            "type": "error_recovery",
            "error_snippet": ef["error"],
            "recovery_tool": ef["recovery_tool"],
        })

    return patterns


def evaluate_session(
    transcript_path: Optional[str] = None,
    min_session_length: int = MIN_SESSION_LENGTH,
    learnings_dir: Optional[Path] = None,
) -> Dict[str, Any]:
    """
    Evaluate a session for extractable patterns.

    Args:
        transcript_path: Path to the JSONL transcript file.
        min_session_length: Minimum user messages to evaluate (default: 10).
        learnings_dir: Directory to save learned patterns.

    Returns:
        Dict with 'evaluated' (bool), 'message_count', 'patterns_found',
        and 'learnings_file' if patterns were saved.
    """
    if learnings_dir is None:
        learnings_dir = LEARNINGS_DIR

    learnings_dir.mkdir(parents=True, exist_ok=True)

    if not transcript_path or not os.path.exists(transcript_path):
        return {
            "evaluated": False,
            "reason": "no transcript available",
            "message_count": 0,
            "patterns_found": 0,
        }

    message_count = _count_user_messages(transcript_path)

    if message_count < min_session_length:
        return {
            "evaluated": False,
            "reason": "session too short ({} messages, need {})".format(
                message_count, min_session_length
            ),
            "message_count": message_count,
            "patterns_found": 0,
        }

    patterns = _extract_patterns(transcript_path)

    result = {
        "evaluated": True,
        "message_count": message_count,
        "patterns_found": len(patterns),
    }

    if patterns:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        learnings_file = learnings_dir / "patterns-{}.json".format(timestamp)

        learning_data = {
            "timestamp": datetime.now().isoformat(),
            "transcript": transcript_path,
            "message_count": message_count,
            "patterns": patterns,
        }

        try:
            with open(learnings_file, "w") as f:
                json.dump(learning_data, f, indent=2)
            result["learnings_file"] = str(learnings_file)
        except OSError:
            pass

    return result


if __name__ == "__main__":
    import sys

    raw = sys.stdin.read(1024 * 1024)
    transcript_path = None

    try:
        data = json.loads(raw) if raw.strip() else {}
        transcript_path = data.get("transcript_path")
    except json.JSONDecodeError:
        transcript_path = os.environ.get("CLAUDE_TRANSCRIPT_PATH")

    result = evaluate_session(transcript_path=transcript_path)

    if result["evaluated"]:
        sys.stderr.write(
            "[ContinuousLearning] Session has {} messages - "
            "found {} extractable patterns\n".format(
                result["message_count"], result["patterns_found"]
            )
        )
    else:
        sys.stderr.write(
            "[ContinuousLearning] {}\n".format(result.get("reason", "skipped"))
        )
