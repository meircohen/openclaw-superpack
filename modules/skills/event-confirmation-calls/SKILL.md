---
name: event-confirmation-calls
description: Batch-call event guests to confirm attendance, collect notes, and compile a summary
read_when: "user is hosting an event, needs to confirm guest attendance, or wants automated RSVP calls"
---

# Event Guest Confirmation Calls

Call each guest on your list to confirm attendance, collect notes, and compile results.

## How It Works

1. Provide guest list (names + phone numbers) and event details
2. Agent calls each guest via SuperCall with a sandboxed AI persona
3. Confirms attendance, collects dietary needs, plus-ones, notes
4. Compiles summary: confirmed, declined, no-answer, special requests

## Why SuperCall

SuperCall is a fully standalone voice agent. The AI on the call ONLY has access to the context you provide (persona, goal, opening line). It cannot access your agent, files, or tools.

- **Safe**: No prompt injection or data leakage risk
- **Focused**: Scoped to one task = better conversations
- **Batch-friendly**: Resets per call, no bleed-over between guests

## Setup

```bash
openclaw plugins install @xonder/supercall
```

Requirements: Twilio account + phone number, OpenAI API key, ngrok.

## Prompt Template

```
Confirm attendance for my event:
Event: Summer BBQ
Date: Saturday, June 14th at 4 PM
Location: 23 Oak Street

Guest list:
- Sarah Johnson: +15551234567
- Mike Chen: +15559876543
[...]

Use supercall for each call. Persona: "Jamie, event coordinator for [your name]."
Goal: confirm attendance, note dietary restrictions, plus-ones, comments.

After all calls, give me a summary:
- Who confirmed
- Who declined
- Who didn't answer
- Notes and special requests per guest
```

## Tips

- Test with 2-3 guests first to tune persona and tone
- Respect calling hours (not too early or late)
- Review transcripts in ~/clawd/supercall-logs after first batch
- No-answer guests can be retried or followed up by text
- Each call uses Twilio minutes -- set billing limits
