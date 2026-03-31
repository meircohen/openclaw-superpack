#!/usr/bin/env python3
"""
Rationalization Defense Tables
Adapted from superpowers using-superpowers + test-driven-development patterns.

Provides explicit tables of rationalizations that LLM agents commonly use
to skip processes, and counters for each. Designed to be injected into
skill prompts and system instructions.

Usage:
    from rationalization_defense import get_defense_table, check_rationalization

    # Get all defenses for a category
    table = get_defense_table("tdd")

    # Check if a statement is a known rationalization
    result = check_rationalization("This is too simple for TDD")
"""

from typing import Dict, List, NamedTuple, Optional


class Defense(NamedTuple):
    rationalization: str    # What the agent says
    counter: str            # Why it's wrong
    category: str           # Which process it tries to skip


# Skill Invocation Rationalizations
SKILL_DEFENSES = [
    Defense(
        "This is just a simple question",
        "Questions are tasks. Check for skills.",
        "skill_skip",
    ),
    Defense(
        "I need more context first",
        "Skill check comes BEFORE clarifying questions.",
        "skill_skip",
    ),
    Defense(
        "Let me explore the codebase first",
        "Skills tell you HOW to explore. Check skills first.",
        "skill_skip",
    ),
    Defense(
        "This doesn't need a formal skill",
        "If a skill exists for it, use it. Skills exist for a reason.",
        "skill_skip",
    ),
    Defense(
        "I know what that means",
        "Knowing the concept is not the same as using the skill.",
        "skill_skip",
    ),
    Defense(
        "The skill is overkill for this",
        "Simple things become complex. The skill handles that transition.",
        "skill_skip",
    ),
]

# TDD Rationalizations
TDD_DEFENSES = [
    Defense(
        "I'll write tests after to verify it works",
        "Tests written after code pass immediately. That proves nothing — "
        "you never saw it catch the bug.",
        "tdd_skip",
    ),
    Defense(
        "I'll skip TDD just this once",
        "This is a rationalization, not a judgment call. Process exists "
        "because 'just this once' compounds.",
        "tdd_skip",
    ),
    Defense(
        "This is too simple for TDD",
        "Simple code is where TDD is fastest. If it's simple, the test "
        "takes 30 seconds. No excuse.",
        "tdd_skip",
    ),
    Defense(
        "I'll use mocks to make it faster",
        "Mocks test mock behavior, not real behavior. Only mock at "
        "system boundaries (external APIs, DBs).",
        "tdd_skip",
    ),
    Defense(
        "I'll add test-only methods to make testing easier",
        "Test-only methods pollute production code. If you can't test "
        "it, the design needs refactoring.",
        "tdd_skip",
    ),
    Defense(
        "I already know the implementation, so test-first is wasteful",
        "If you know the implementation, writing the test first is trivial. "
        "RED confirms you're testing the right thing.",
        "tdd_skip",
    ),
    Defense(
        "I'll keep the code I wrote before the test as reference",
        "Delete means delete. Code written before tests biases the test. "
        "Start fresh from the test.",
        "tdd_skip",
    ),
]

# Verification Rationalizations
VERIFICATION_DEFENSES = [
    Defense(
        "This should work",
        "'Should' is not evidence. Run the command. Read the output. "
        "THEN claim it works.",
        "verification_skip",
    ),
    Defense(
        "I'm confident this is fixed",
        "Confidence is not evidence. Run the verification command and "
        "cite the output.",
        "verification_skip",
    ),
    Defense(
        "The tests passed earlier",
        "'Earlier' is not 'now'. Run them FRESH before claiming pass.",
        "verification_skip",
    ),
    Defense(
        "It looks correct from the diff",
        "Reading code is review, not verification. Verification requires "
        "EXECUTION — run the tests.",
        "verification_skip",
    ),
    Defense(
        "The agent said it passed",
        "Agent reports are claims, not evidence. Check the VCS, run "
        "the command yourself.",
        "verification_skip",
    ),
]

# Debugging Rationalizations
DEBUGGING_DEFENSES = [
    Defense(
        "I think I know what's wrong, let me just try a fix",
        "If 3+ quick fixes fail, you've wasted more time than "
        "investigation would have taken. Find root cause first.",
        "debugging_skip",
    ),
    Defense(
        "Let me try reverting and rewriting",
        "Rewriting without understanding the bug means you'll "
        "reintroduce it. Investigate first.",
        "debugging_skip",
    ),
    Defense(
        "The error message is clear enough",
        "Error messages describe symptoms, not causes. Trace the "
        "data flow to find the actual root cause.",
        "debugging_skip",
    ),
]

# Design Rationalizations
DESIGN_DEFENSES = [
    Defense(
        "This is too simple to need a design",
        "Simple projects are where unexamined assumptions cause the "
        "most wasted work. Design can be short, but it must exist.",
        "design_skip",
    ),
    Defense(
        "I already know exactly what to build",
        "You know what YOU think should be built. Design confirms "
        "the user agrees.",
        "design_skip",
    ),
    Defense(
        "Let me just start coding and iterate",
        "Iteration without design is thrashing. 5 minutes of design "
        "saves hours of rework.",
        "design_skip",
    ),
]

ALL_DEFENSES = (
    SKILL_DEFENSES
    + TDD_DEFENSES
    + VERIFICATION_DEFENSES
    + DEBUGGING_DEFENSES
    + DESIGN_DEFENSES
)

DEFENSE_CATEGORIES = {
    "skill": SKILL_DEFENSES,
    "tdd": TDD_DEFENSES,
    "verification": VERIFICATION_DEFENSES,
    "debugging": DEBUGGING_DEFENSES,
    "design": DESIGN_DEFENSES,
}


def get_defense_table(category):
    # type: (str) -> List[Defense]
    """Get all defenses for a category."""
    return DEFENSE_CATEGORIES.get(category, [])


def format_defense_table(category):
    # type: (str) -> str
    """Format a defense table as markdown for injection into prompts."""
    defenses = get_defense_table(category)
    if not defenses:
        return ""

    lines = ["| Rationalization | Why It's Wrong |", "|---|---|"]
    for d in defenses:
        lines.append("| \"{}\" | {} |".format(d.rationalization, d.counter))
    return "\n".join(lines)


def check_rationalization(statement):
    # type: (str) -> Optional[Defense]
    """Check if a statement matches a known rationalization pattern.

    Returns the matching Defense if found, None otherwise.
    Uses keyword overlap for fuzzy matching.
    """
    statement_lower = statement.lower()
    best_match = None
    best_score = 0.0

    for defense in ALL_DEFENSES:
        rat_words = set(defense.rationalization.lower().split())
        stmt_words = set(statement_lower.split())
        if not rat_words:
            continue
        overlap = len(rat_words & stmt_words) / len(rat_words)
        if overlap > best_score and overlap >= 0.4:
            best_score = overlap
            best_match = defense

    return best_match


if __name__ == "__main__":
    print("Rationalization Defense Tables")
    print("=" * 60)
    for cat_name, defenses in DEFENSE_CATEGORIES.items():
        print("\n## {} ({} defenses)".format(cat_name.upper(), len(defenses)))
        print(format_defense_table(cat_name))
    print("\nTotal defenses: {}".format(len(ALL_DEFENSES)))
