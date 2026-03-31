#!/usr/bin/env python3
"""
6-Phase Workflow State Machine
Adapted from superpowers linear pipeline pattern.

Models the superpowers workflow as a state machine:
  Brainstorm → Plan → Isolate → Execute → Verify → Complete

Each phase has entry gates, exit conditions, and cross-cutting concerns.

Usage:
    from workflow_phases import WorkflowStateMachine, Phase

    wf = WorkflowStateMachine("Add OAuth2 login")
    wf.current_phase  # Phase.BRAINSTORM
    wf.can_advance()  # False (no design approval yet)
    wf.record_gate("design_approved")
    wf.can_advance()  # True
    wf.advance()      # → Phase.PLAN
"""

import json
import os
import time
from typing import Any, Dict, List, Optional, Set


class Phase:
    """Workflow phases as string constants (Python 3.9 compatible)."""
    BRAINSTORM = "brainstorm"
    PLAN = "plan"
    ISOLATE = "isolate"
    EXECUTE = "execute"
    VERIFY = "verify"
    COMPLETE = "complete"
    DONE = "done"

    ORDER = [BRAINSTORM, PLAN, ISOLATE, EXECUTE, VERIFY, COMPLETE, DONE]


# Phase definitions with gates
PHASE_DEFS = {
    Phase.BRAINSTORM: {
        "description": "Explore user intent, propose approaches, get design approval",
        "skill": "brainstorming",
        "entry_gates": [],
        "exit_gates": ["design_doc_exists", "design_approved"],
        "next": Phase.PLAN,
    },
    Phase.PLAN: {
        "description": "Write bite-sized implementation plan (2-5 min tasks)",
        "skill": "writing-plans",
        "entry_gates": ["design_approved"],
        "exit_gates": ["plan_saved", "tasks_are_bite_sized"],
        "next": Phase.ISOLATE,
    },
    Phase.ISOLATE: {
        "description": "Create isolated git worktree, verify baseline tests",
        "skill": "using-git-worktrees",
        "entry_gates": ["plan_saved"],
        "exit_gates": ["worktree_created", "baseline_tests_pass"],
        "next": Phase.EXECUTE,
    },
    Phase.EXECUTE: {
        "description": "Execute plan via subagent-driven or batch execution",
        "skill": "subagent-driven-development",
        "entry_gates": ["worktree_created", "baseline_tests_pass"],
        "exit_gates": ["all_tasks_complete", "all_reviews_pass"],
        "next": Phase.VERIFY,
    },
    Phase.VERIFY: {
        "description": "Run fresh verification, cite evidence before claiming",
        "skill": "verification-before-completion",
        "entry_gates": ["all_tasks_complete"],
        "exit_gates": ["fresh_verification_run", "evidence_confirms_pass"],
        "next": Phase.COMPLETE,
    },
    Phase.COMPLETE: {
        "description": "Present merge/PR/keep/discard options, execute choice",
        "skill": "finishing-a-development-branch",
        "entry_gates": ["evidence_confirms_pass"],
        "exit_gates": ["completion_choice_made", "cleanup_done"],
        "next": Phase.DONE,
    },
}

# Cross-cutting disciplines (active during any phase)
CROSS_CUTTING = {
    "tdd": {
        "description": "RED-GREEN-REFACTOR cycle",
        "skill": "test-driven-development",
        "active_during": [Phase.EXECUTE],
        "iron_law": "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST",
    },
    "debugging": {
        "description": "4-phase root cause investigation",
        "skill": "systematic-debugging",
        "active_during": [Phase.EXECUTE, Phase.VERIFY],
        "iron_law": "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST",
    },
    "code_review": {
        "description": "Two-stage review (spec compliance → code quality)",
        "skill": "requesting-code-review",
        "active_during": [Phase.EXECUTE],
        "iron_law": "NO TASK COMPLETION WITHOUT TWO-STAGE REVIEW",
    },
}


class WorkflowStateMachine:
    """State machine for the 6-phase workflow."""

    def __init__(self, task_description, initial_phase=Phase.BRAINSTORM):
        # type: (str, str) -> None
        self.task = task_description
        self.current_phase = initial_phase
        self.gates_met = set()  # type: Set[str]
        self.history = []  # type: List[Dict[str, Any]]
        self.started_at = time.time()
        self._record("workflow_started", {"task": task_description, "phase": initial_phase})

    def record_gate(self, gate_name):
        # type: (str) -> None
        """Record that a gate condition has been met."""
        self.gates_met.add(gate_name)
        self._record("gate_met", {"gate": gate_name, "phase": self.current_phase})

    def can_advance(self):
        # type: () -> Dict[str, Any]
        """Check if current phase's exit gates are all met."""
        if self.current_phase == Phase.DONE:
            return {"can_advance": False, "reason": "Workflow complete"}

        phase_def = PHASE_DEFS.get(self.current_phase)
        if not phase_def:
            return {"can_advance": False, "reason": "Unknown phase"}

        missing = [g for g in phase_def["exit_gates"] if g not in self.gates_met]
        if missing:
            return {
                "can_advance": False,
                "reason": "Exit gates not met",
                "missing_gates": missing,
                "phase": self.current_phase,
            }

        return {
            "can_advance": True,
            "next_phase": phase_def["next"],
            "phase": self.current_phase,
        }

    def advance(self):
        # type: () -> Dict[str, Any]
        """Advance to the next phase if gates are met."""
        check = self.can_advance()
        if not check["can_advance"]:
            return {"advanced": False, "reason": check.get("reason", "Cannot advance")}

        old_phase = self.current_phase
        self.current_phase = PHASE_DEFS[old_phase]["next"]
        self._record("phase_advanced", {"from": old_phase, "to": self.current_phase})

        return {
            "advanced": True,
            "from": old_phase,
            "to": self.current_phase,
            "skill": PHASE_DEFS.get(self.current_phase, {}).get("skill", "none"),
        }

    def get_status(self):
        # type: () -> Dict[str, Any]
        """Get current workflow status."""
        phase_def = PHASE_DEFS.get(self.current_phase, {})
        exit_gates = phase_def.get("exit_gates", [])
        met = [g for g in exit_gates if g in self.gates_met]
        missing = [g for g in exit_gates if g not in self.gates_met]

        return {
            "task": self.task,
            "current_phase": self.current_phase,
            "phase_description": phase_def.get("description", ""),
            "skill": phase_def.get("skill", ""),
            "gates_met": met,
            "gates_remaining": missing,
            "progress": Phase.ORDER.index(self.current_phase) / (len(Phase.ORDER) - 1),
            "elapsed_s": round(time.time() - self.started_at, 1),
        }

    def get_active_disciplines(self):
        # type: () -> List[Dict[str, str]]
        """Get cross-cutting disciplines active for current phase."""
        active = []
        for name, disc in CROSS_CUTTING.items():
            if self.current_phase in disc["active_during"]:
                active.append({
                    "name": name,
                    "description": disc["description"],
                    "skill": disc["skill"],
                    "iron_law": disc["iron_law"],
                })
        return active

    def _record(self, event, data):
        # type: (str, Dict) -> None
        self.history.append({
            "event": event,
            "data": data,
            "timestamp": time.time(),
        })

    def save_state(self, filepath):
        # type: (str) -> None
        """Save workflow state to JSON file."""
        state = {
            "task": self.task,
            "current_phase": self.current_phase,
            "gates_met": sorted(self.gates_met),
            "history": self.history,
            "started_at": self.started_at,
        }
        with open(filepath, "w") as f:
            json.dump(state, f, indent=2)

    @classmethod
    def load_state(cls, filepath):
        # type: (str) -> WorkflowStateMachine
        """Load workflow state from JSON file."""
        with open(filepath) as f:
            state = json.load(f)
        wf = cls(state["task"], initial_phase=state["current_phase"])
        wf.gates_met = set(state.get("gates_met", []))
        wf.history = state.get("history", [])
        wf.started_at = state.get("started_at", time.time())
        return wf


if __name__ == "__main__":
    # Demo walkthrough
    wf = WorkflowStateMachine("Add OAuth2 login")

    print("6-Phase Workflow State Machine")
    print("=" * 50)
    print("\nPhase order:")
    for i, phase in enumerate(Phase.ORDER[:-1], 1):
        pdef = PHASE_DEFS.get(phase, {})
        print("  {}. {} — {}".format(i, phase.upper(), pdef.get("description", "")))

    print("\nCross-cutting disciplines:")
    for name, disc in CROSS_CUTTING.items():
        print("  {} — {}".format(name, disc["iron_law"]))

    print("\nDemo walkthrough:")
    status = wf.get_status()
    print("  Phase: {} (progress: {:.0%})".format(status["current_phase"], status["progress"]))
    print("  Gates remaining: {}".format(status["gates_remaining"]))

    # Meet gates
    wf.record_gate("design_doc_exists")
    wf.record_gate("design_approved")
    result = wf.advance()
    print("  Advanced: {} → {}".format(result["from"], result["to"]))
