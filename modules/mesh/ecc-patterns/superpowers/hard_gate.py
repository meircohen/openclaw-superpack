#!/usr/bin/env python3
"""
Hard Gate Enforcement Patterns
Adapted from superpowers skill system.

Provides patterns for creating non-negotiable gates in agent workflows:
1. XML attention anchors (<HARD-GATE>, <EXTREMELY-IMPORTANT>)
2. DOT flowcharts as canonical process specs
3. Gate function templates

Usage:
    from hard_gate import HardGate, format_gate_prompt

    gate = HardGate("design_approval", "Design must be approved before implementation")
    prompt = gate.format_for_prompt()
"""

from typing import Dict, List, Optional


class HardGate:
    """A non-negotiable process gate for agent workflows."""

    def __init__(
        self,
        name,           # type: str
        description,    # type: str
        prerequisites,  # type: Optional[List[str]]
        check_fn_desc,  # type: Optional[str]
    ):
        # type: (...) -> None
        self.name = name
        self.description = description
        self.prerequisites = prerequisites or []
        self.check_fn_desc = check_fn_desc or "Verify gate conditions are met"

    def format_for_prompt(self):
        # type: () -> str
        """Format gate as prompt text with attention anchors."""
        lines = []
        lines.append("<HARD-GATE>")
        lines.append("GATE: {}".format(self.name))
        lines.append("")
        lines.append(self.description)
        lines.append("")
        if self.prerequisites:
            lines.append("Prerequisites (ALL must be true):")
            for pre in self.prerequisites:
                lines.append("  - {}".format(pre))
            lines.append("")
        lines.append("Check: {}".format(self.check_fn_desc))
        lines.append("")
        lines.append("This gate is NON-NEGOTIABLE. No shortcuts, no exceptions.")
        lines.append("</HARD-GATE>")
        return "\n".join(lines)

    def check(self, state):
        # type: (Dict[str, bool]) -> Dict[str, object]
        """Check if gate can be passed.

        Args:
            state: dict mapping prerequisite descriptions to bool (met/not met)

        Returns:
            dict with passed, blocked_by, message
        """
        blocked_by = []
        for pre in self.prerequisites:
            if not state.get(pre, False):
                blocked_by.append(pre)

        if blocked_by:
            return {
                "passed": False,
                "gate": self.name,
                "blocked_by": blocked_by,
                "message": "Gate '{}' blocked: {} prerequisite(s) not met".format(
                    self.name, len(blocked_by)),
            }

        return {
            "passed": True,
            "gate": self.name,
            "blocked_by": [],
            "message": "Gate '{}' passed".format(self.name),
        }


# Pre-built gates from superpowers workflow
DESIGN_APPROVAL_GATE = HardGate(
    name="design_approval",
    description="Do NOT invoke any implementation skill, write any code, scaffold "
                "any project, or take any implementation action until you have "
                "presented a design and the user has approved it.",
    prerequisites=[
        "Design document exists",
        "Design presented to user",
        "User has approved design",
    ],
    check_fn_desc="Check for design doc in docs/plans/ and user approval",
)

PLAN_EXISTS_GATE = HardGate(
    name="plan_exists",
    description="Do NOT begin implementation until a detailed plan exists with "
                "bite-sized tasks, each 2-5 minutes.",
    prerequisites=[
        "Plan document saved to docs/plans/",
        "Plan has numbered, bite-sized tasks",
        "Each task is a single action (2-5 min)",
    ],
    check_fn_desc="Check for plan file with task structure",
)

FRESH_VERIFICATION_GATE = HardGate(
    name="fresh_verification",
    description="Do NOT claim work is complete without running verification "
                "commands and citing their output. Evidence before assertions.",
    prerequisites=[
        "Verification command run in THIS message",
        "Full output captured and read",
        "Exit code checked",
        "Output confirms the claim",
    ],
    check_fn_desc="Check for fresh command output in current context",
)

ROOT_CAUSE_GATE = HardGate(
    name="root_cause_investigation",
    description="Do NOT propose fixes without completing root cause investigation. "
                "Symptom fixes are failure.",
    prerequisites=[
        "Error reproduced consistently",
        "Data flow traced to origin",
        "Root cause identified (not just symptoms)",
        "Hypothesis formed and stated",
    ],
    check_fn_desc="Check for documented root cause analysis",
)

SPEC_COMPLIANCE_GATE = HardGate(
    name="spec_compliance",
    description="Do NOT proceed to code quality review until spec compliance "
                "review passes. Two stages are mandatory.",
    prerequisites=[
        "All plan requirements implemented",
        "No extra features added (YAGNI)",
        "Tests match plan criteria",
    ],
    check_fn_desc="Compare code diff against plan requirements",
)

ALL_GATES = [
    DESIGN_APPROVAL_GATE,
    PLAN_EXISTS_GATE,
    FRESH_VERIFICATION_GATE,
    ROOT_CAUSE_GATE,
    SPEC_COMPLIANCE_GATE,
]


def format_workflow_gates():
    # type: () -> str
    """Format all gates as a workflow prompt section."""
    lines = ["# Workflow Gates (Non-Negotiable)", ""]
    for gate in ALL_GATES:
        lines.append(gate.format_for_prompt())
        lines.append("")
    return "\n".join(lines)


def format_dot_workflow():
    # type: () -> str
    """Generate DOT flowchart of the gated workflow.

    Superpowers found that DOT flowcharts are followed more reliably
    than prose descriptions. Include this in skill prompts.
    """
    return """digraph workflow {
    rankdir=LR;
    node [shape=box, style=rounded];

    brainstorm [label="1. Brainstorm\\nDesign"];
    plan [label="2. Write\\nPlan"];
    isolate [label="3. Create\\nWorktree"];
    execute [label="4. Execute\\n(TDD)"];
    verify [label="5. Verify\\n(Evidence)"];
    complete [label="6. Complete\\n(Merge/PR)"];

    brainstorm -> plan [label="design approved"];
    plan -> isolate [label="plan saved"];
    isolate -> execute [label="worktree ready"];
    execute -> verify [label="all tasks done"];
    verify -> complete [label="evidence confirms"];

    // Gates (red = blocking)
    edge [color=red, style=dashed];
    brainstorm -> brainstorm [label="no approval?\\nloop"];
    execute -> execute [label="review failed?\\nfix + re-review"];
    verify -> execute [label="tests fail?\\nback to execute"];
}"""


if __name__ == "__main__":
    print("Hard Gate Enforcement Patterns")
    print("=" * 60)
    for gate in ALL_GATES:
        print("\n{}".format(gate.format_for_prompt()))
    print("\n\nDOT Workflow:")
    print(format_dot_workflow())
