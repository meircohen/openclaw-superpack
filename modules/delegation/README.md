# Delegation Module

A structured system for delegating tasks to AI sub-agents with quality verification. Each task type has a template (schema), skill (instructions), and verification checklist.

## Structure

```
delegation/
  pipelines/     # Multi-step workflows that chain task types together
  skills/        # Execution instructions for each task type
  templates/     # JSON schemas defining valid briefs for each task type
  verify/        # Post-completion verification checklists
  voice/         # Voice/tone guides for content generation tasks
```

## Task Types

| Type | Description | Agent |
|------|-------------|-------|
| `code-task` | Coding tasks (bug fixes, features) with TDD | auto (Codex/Claude Code) |
| `email-draft` | Email drafting with humanizer | sonnet-4 |
| `ops-debug` | Operational debugging and incident response | sonnet-4 |
| `research-brief` | Research with structured output | sonnet-4 |
| `tweet-engagement` | Reply to tweets in user's voice | haiku-4.5 |
| `tweet-original` | Compose original tweets/threads | sonnet-4 |

## How It Works

1. **Brief**: Create a JSON brief matching a template schema (e.g., `templates/code-task.json`)
2. **Dispatch**: The orchestrator reads the skill file (`skills/code-task.md`) and dispatches to the appropriate agent
3. **Execute**: The sub-agent follows the skill instructions step by step
4. **Verify**: The verification checklist (`verify/code-task.md`) is run before reporting completion

## Pipelines

Pipelines chain multiple task types into multi-step workflows:

- **morning-briefing** -- Daily digest: email + calendar + news, synthesized
- **bug-to-pr** -- Reproduce bug, write failing test, fix, open PR
- **email-to-todoist** -- Scan emails for action items, create tasks, draft replies
- **meeting-prep-full** -- Calendar scan, attendee research, talking points
- **trending-to-tweets** -- Research trends, draft hot takes, post (with review gate)

Pipelines support:
- `depends_on` -- Sequential step ordering
- `parallel_with` -- Parallel execution of independent steps
- `review_gate` -- Pause for human approval before continuing
- `on_failure` -- "stop" or "continue" behavior

## Voice Guides

Voice files define tone, vocabulary, and style for content tasks:

- `voice/default.md` -- General professional voice
- `voice/tech.md` -- Technical/AI audience voice

Customize these with your personal writing style, war stories, and domain expertise.

## Setup

1. Replace `{{USER_EMAIL}}` in templates and pipelines with your actual email address
2. Customize voice guides in `voice/` with your personal style
3. Update `config/user.json` with your signature and account details
4. Add your own pipelines by combining existing task types

## Anti-Patterns

Each template includes `_anti_patterns` -- common mistakes to avoid. These are enforced by the verification checklists.

Key principles:
- **Test before claiming done.** Verification is not optional.
- **Never send without approval.** Draft is the safe default for emails and tweets.
- **No scope creep.** Stay within the brief's defined scope.
- **Auto-fix never touches user config.** Alert instead of fixing.
