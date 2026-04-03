---
name: phone-call-agent
description: Agent-initiated phone calls as a notification channel -- morning briefings, price alerts, urgent emails
read_when: "user wants phone call notifications, voice alerts, agent-to-phone calls, or urgent call-based alerts"
---

# Phone Call Agent

Give your agent the ability to call your phone when something matters enough.

## How It Works

The agent evaluates whether something is phone-call-worthy, then dials your real number via clawr.ing. Two-way conversation -- you can ask follow-up questions.

## Setup

Install by pasting the setup prompt from the clawr.ing dashboard into chat. No CLI install needed. The prompt includes the API key and skill docs.

- [clawr.ing dashboard](https://clawr.ing)
- [ClawHub](https://clawhub.ai/marcospgp/clawring)

## Use Cases

### Morning Briefing Call
```
Every weekday at 7:30 AM, call me with:
- Weather forecast
- Today's calendar
- Urgent overnight emails
- Top 3 news headlines for my interests

Keep it under 2 minutes. Answer questions if I ask.
If I don't pick up, don't retry.
```

### Price Alert
```
Monitor NVDA stock. If it drops >5% in a day,
call me immediately with what happened + relevant news.
```

### Urgent Email Filter
```
During business hours, check inbox every 15 minutes.
Email from my boss or marked urgent: call me with summary.
Everything else: chat message only.
```

## Key Rules

- **Don't overuse it.** A phone call means "this actually matters." 10 calls/day = ignored.
- **Set clear thresholds** for call-worthy vs chat-worthy
- **Pair with heartbeat/cron** for the trigger; clawr.ing is the delivery channel
- **Use a fast model** for phone conversations (Haiku-class) to minimize latency
- clawr.ing supports 100+ countries with real PSTN calls
- No recordings stored; audio encrypted in transit and discarded
