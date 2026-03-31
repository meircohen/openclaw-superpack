#!/usr/bin/env python3
"""
Evidence-First Verification Gate
Adapted from superpowers verification-before-completion pattern.

Enforces the rule: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

Provides a gate function that requires:
1. A verification command to have been run
2. Its output to have been captured
3. The output to confirm the claim

Usage:
    from evidence_gate import EvidenceGate, VerificationRecord

    gate = EvidenceGate()
    gate.record_verification("pytest", exit_code=0, output="34 passed")
    result = gate.can_claim_complete()
"""

import time
from typing import Dict, List, NamedTuple, Optional


class VerificationRecord(NamedTuple):
    command: str        # What was run
    exit_code: int      # 0 = pass
    output: str         # Captured stdout/stderr
    timestamp: float    # When it was run
    passed: bool        # Did it pass?


class EvidenceGate:
    """Evidence-first verification gate.

    Tracks verification commands and their results.
    Claims of completion are only allowed when fresh evidence exists.
    """

    # Maximum age (seconds) for verification evidence to be considered "fresh"
    MAX_EVIDENCE_AGE_S = 300  # 5 minutes

    # Red flags: phrases that indicate claims without evidence
    RED_FLAG_PHRASES = [
        "should work",
        "should pass",
        "should be fixed",
        "looks correct",
        "seems right",
        "probably works",
        "i'm confident",
        "i believe this",
        "this will work",
        "that should do it",
    ]

    def __init__(self):
        # type: () -> None
        self._records = []  # type: List[VerificationRecord]

    def record_verification(
        self,
        command,    # type: str
        exit_code,  # type: int
        output,     # type: str
    ):
        # type: (...) -> VerificationRecord
        """Record a verification command execution."""
        record = VerificationRecord(
            command=command,
            exit_code=exit_code,
            output=output[:5000],  # Cap output size
            timestamp=time.time(),
            passed=exit_code == 0,
        )
        self._records.append(record)
        return record

    def get_fresh_evidence(self):
        # type: () -> List[VerificationRecord]
        """Get verification records that are still fresh."""
        cutoff = time.time() - self.MAX_EVIDENCE_AGE_S
        return [r for r in self._records if r.timestamp >= cutoff]

    def can_claim_complete(self):
        # type: () -> Dict[str, object]
        """Check if there's sufficient fresh evidence to claim completion.

        Returns dict with:
            allowed: bool
            reason: str
            evidence: list of fresh records
        """
        fresh = self.get_fresh_evidence()

        if not fresh:
            return {
                "allowed": False,
                "reason": "No fresh verification evidence. Run verification commands first.",
                "evidence": [],
            }

        # Check if any fresh evidence failed
        failures = [r for r in fresh if not r.passed]
        if failures:
            return {
                "allowed": False,
                "reason": "Fresh evidence shows failures: {}".format(
                    ", ".join("{} (exit {})".format(r.command, r.exit_code) for r in failures)
                ),
                "evidence": [r._asdict() for r in fresh],
            }

        return {
            "allowed": True,
            "reason": "Fresh passing evidence: {}".format(
                ", ".join("{} (pass)".format(r.command) for r in fresh)
            ),
            "evidence": [r._asdict() for r in fresh],
        }

    @staticmethod
    def check_claim_for_red_flags(claim_text):
        # type: (str) -> List[str]
        """Check a completion claim for red-flag phrases that suggest
        the claim is being made without evidence.

        Returns list of red flag phrases found.
        """
        claim_lower = claim_text.lower()
        return [phrase for phrase in EvidenceGate.RED_FLAG_PHRASES if phrase in claim_lower]

    def format_evidence_summary(self):
        # type: () -> str
        """Format fresh evidence as a human-readable summary."""
        fresh = self.get_fresh_evidence()
        if not fresh:
            return "No fresh verification evidence."

        lines = ["Verification Evidence:"]
        for r in fresh:
            icon = "PASS" if r.passed else "FAIL"
            age = int(time.time() - r.timestamp)
            lines.append("  [{}] {} ({}s ago, exit {})".format(
                icon, r.command, age, r.exit_code))
            # Show last few lines of output
            output_lines = r.output.strip().split("\n")
            for ol in output_lines[-3:]:
                lines.append("    {}".format(ol[:100]))
        return "\n".join(lines)


def integrate_with_verify_pipeline(verify_report):
    # type: (Dict) -> EvidenceGate
    """Create an EvidenceGate from a verify.py pipeline report.

    Usage:
        from verify import verify
        from evidence_gate import integrate_with_verify_pipeline

        report = verify(path, mode="full")
        gate = integrate_with_verify_pipeline(report)
        result = gate.can_claim_complete()
    """
    gate = EvidenceGate()
    for stage in verify_report.get("stages", []):
        if stage.get("status") in ("PASS", "FAIL"):
            gate.record_verification(
                command=stage.get("command", stage.get("stage", "unknown")),
                exit_code=stage.get("exit_code", 0 if stage["status"] == "PASS" else 1),
                output=stage.get("stdout", "") + stage.get("stderr", ""),
            )
    return gate


if __name__ == "__main__":
    # Demo
    gate = EvidenceGate()

    print("Evidence-First Verification Gate")
    print("=" * 40)

    # Before any verification
    result = gate.can_claim_complete()
    print("\nBefore verification:")
    print("  Can claim complete? {}".format(result["allowed"]))
    print("  Reason: {}".format(result["reason"]))

    # After verification
    gate.record_verification("pytest", exit_code=0, output="34 passed, 0 failed")
    result = gate.can_claim_complete()
    print("\nAfter pytest passes:")
    print("  Can claim complete? {}".format(result["allowed"]))
    print("  Reason: {}".format(result["reason"]))

    # Red flag check
    flags = EvidenceGate.check_claim_for_red_flags("This should work now")
    print("\nRed flags in 'This should work now':")
    print("  {}".format(flags))
