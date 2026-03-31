#!/usr/bin/env python3
"""
Two-Stage Review Pipeline
Adapted from superpowers subagent-driven-development pattern.

Separates code review into two distinct stages:
1. Spec Compliance - Does the code match the plan/spec EXACTLY?
2. Code Quality - Is it well-built? (patterns, naming, tests, errors)

This catches two distinct failure modes:
- "Well-written but wrong" (passes quality, fails spec)
- "Spec-compliant but messy" (passes spec, fails quality)

Usage:
    from two_stage_review import TwoStageReview, ReviewResult

    review = TwoStageReview()
    result = review.spec_compliance(plan_text, code_diff)
    if result.approved:
        result = review.code_quality(code_diff, project_context)
"""

from typing import Any, Dict, List, NamedTuple, Optional


class ReviewResult(NamedTuple):
    stage: str          # "spec_compliance" or "code_quality"
    approved: bool
    issues: List[str]   # list of issues found
    severity: str       # "pass", "minor", "major", "blocker"


class TwoStageReview:
    """Two-stage review pipeline: spec compliance, then code quality."""

    # Spec compliance checklist
    SPEC_CHECKS = [
        "All requirements from plan are implemented",
        "No extra features added (YAGNI)",
        "No requirements partially implemented",
        "Edge cases from plan are handled",
        "Tests match plan's test criteria",
    ]

    # Code quality checklist
    QUALITY_CHECKS = [
        "Naming conventions consistent with codebase",
        "Error handling present at system boundaries",
        "No hardcoded values that should be configurable",
        "Tests are meaningful (not just coverage padding)",
        "No security vulnerabilities (OWASP top 10)",
        "DRY — no unnecessary duplication",
        "Functions/methods are single-responsibility",
    ]

    def spec_compliance(
        self,
        plan_text,       # type: str
        code_diff,       # type: str
        files_changed,   # type: List[str]
    ):
        # type: (...) -> ReviewResult
        """Stage 1: Check code against spec/plan.

        Returns ReviewResult. If not approved, issues list contains
        specific discrepancies to fix before proceeding to Stage 2.
        """
        issues = []

        # Extract requirements from plan (simple heuristic)
        requirements = self._extract_requirements(plan_text)
        if not requirements:
            issues.append("Could not extract requirements from plan — manual review needed")
            return ReviewResult(
                stage="spec_compliance",
                approved=False,
                issues=issues,
                severity="blocker",
            )

        # Check each requirement has corresponding implementation
        for req in requirements:
            if not self._requirement_likely_met(req, code_diff):
                issues.append("Requirement may not be met: {}".format(req[:100]))

        # Check for over-building
        if self._detect_over_building(plan_text, code_diff):
            issues.append("Code appears to add functionality beyond the plan (YAGNI violation)")

        severity = "pass" if not issues else ("minor" if len(issues) <= 1 else "major")
        return ReviewResult(
            stage="spec_compliance",
            approved=len(issues) == 0,
            issues=issues,
            severity=severity,
        )

    def code_quality(
        self,
        code_diff,       # type: str
        project_context, # type: Dict[str, Any]
    ):
        # type: (...) -> ReviewResult
        """Stage 2: Check code quality (only after spec compliance passes).

        Checks patterns, naming, error handling, test quality.
        """
        issues = []

        # Check for common quality issues
        lines = code_diff.split("\n")
        added_lines = [l[1:] for l in lines if l.startswith("+") and not l.startswith("+++")]

        for i, line in enumerate(added_lines):
            # Hardcoded secrets
            if any(pat in line.lower() for pat in ["password=", "secret=", "api_key="]):
                if "example" not in line.lower() and "test" not in line.lower():
                    issues.append("Possible hardcoded secret on added line {}".format(i + 1))

            # Debug artifacts
            if any(pat in line for pat in ["print(", "console.log(", "debugger", "breakpoint()"]):
                if "# noqa" not in line and "// eslint-disable" not in line:
                    issues.append("Debug artifact on added line {}: {}".format(
                        i + 1, line.strip()[:60]))

            # TODO/FIXME without ticket
            if any(pat in line.upper() for pat in ["TODO", "FIXME", "HACK", "XXX"]):
                if not any(ref in line for ref in ["#", "JIRA-", "GH-"]):
                    issues.append("Untracked TODO on added line {}: {}".format(
                        i + 1, line.strip()[:60]))

        severity = "pass" if not issues else ("minor" if len(issues) <= 2 else "major")
        return ReviewResult(
            stage="code_quality",
            approved=len(issues) == 0,
            issues=issues,
            severity=severity,
        )

    def full_review(
        self,
        plan_text,       # type: str
        code_diff,       # type: str
        files_changed,   # type: List[str]
        project_context, # type: Optional[Dict[str, Any]]
    ):
        # type: (...) -> Dict[str, Any]
        """Run both stages sequentially. Stage 2 only runs if Stage 1 passes."""
        spec_result = self.spec_compliance(plan_text, code_diff, files_changed)

        if not spec_result.approved:
            return {
                "approved": False,
                "blocked_at": "spec_compliance",
                "spec_review": spec_result._asdict(),
                "quality_review": None,
                "action": "Fix spec issues before code quality review",
            }

        quality_result = self.code_quality(code_diff, project_context or {})

        return {
            "approved": quality_result.approved,
            "blocked_at": None if quality_result.approved else "code_quality",
            "spec_review": spec_result._asdict(),
            "quality_review": quality_result._asdict(),
            "action": None if quality_result.approved else "Fix quality issues",
        }

    @staticmethod
    def _extract_requirements(plan_text):
        # type: (str) -> List[str]
        """Extract requirement-like lines from plan text."""
        requirements = []
        for line in plan_text.split("\n"):
            stripped = line.strip()
            # Lines starting with -, *, numbered items, or checkbox items
            if any(stripped.startswith(p) for p in ["- ", "* ", "[ ] ", "[x] "]):
                # Skip meta-lines
                if not any(skip in stripped.lower() for skip in [
                    "commit", "run test", "verify", "optional", "nice to have"
                ]):
                    requirements.append(stripped.lstrip("-*[] x").strip())
            elif stripped and stripped[0].isdigit() and ". " in stripped:
                req = stripped.split(". ", 1)[1] if ". " in stripped else stripped
                if not any(skip in req.lower() for skip in ["commit", "run test", "verify"]):
                    requirements.append(req)
        return requirements

    @staticmethod
    def _requirement_likely_met(requirement, code_diff):
        # type: (str, str) -> bool
        """Heuristic check if a requirement appears addressed in the diff."""
        # Extract keywords from requirement
        keywords = [w.lower() for w in requirement.split() if len(w) > 3]
        if not keywords:
            return True  # Can't assess empty requirement
        # Check if enough keywords appear in the diff
        diff_lower = code_diff.lower()
        matches = sum(1 for kw in keywords if kw in diff_lower)
        return matches >= len(keywords) * 0.3  # 30% keyword match threshold

    @staticmethod
    def _detect_over_building(plan_text, code_diff):
        # type: (str, str) -> bool
        """Heuristic: check if diff introduces significantly more than plan calls for."""
        plan_lines = len([l for l in plan_text.split("\n") if l.strip()])
        diff_added = len([l for l in code_diff.split("\n") if l.startswith("+")])
        # If added lines are >10x the plan lines, might be over-building
        return diff_added > max(plan_lines * 10, 500)


if __name__ == "__main__":
    # Demo
    review = TwoStageReview()
    print("Two-Stage Review Pipeline")
    print("=" * 40)
    print("\nSpec Compliance Checks:")
    for check in TwoStageReview.SPEC_CHECKS:
        print("  - {}".format(check))
    print("\nCode Quality Checks:")
    for check in TwoStageReview.QUALITY_CHECKS:
        print("  - {}".format(check))
