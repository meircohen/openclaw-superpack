---
name: habit-coach
description: Proactive daily habit check-ins with streak tracking, adaptive nudges, and weekly reports
read_when: "user wants habit tracking, accountability coaching, streak tracking, or behavior change support"
---

# Habit Tracker & Accountability Coach

Proactive check-ins that adapt based on your streaks and misses. Not a passive app -- an active partner.

## Setup

Define habits and check-in schedule:

```
Track these daily habits:
1. Morning workout (check in at 7:30 AM)
2. Read 30 minutes (check in at 8:00 PM)
3. No social media before noon (check in at 12:30 PM)
4. Drink 8 glasses of water (check in at 6:00 PM)

Send Telegram messages at each check-in time asking if I completed the habit.
Track streaks in ~/habits/log.json.
```

## Adaptive Tone Rules

```
On confirmation: Short encouraging message + current streak.
  "Day 12 of morning workouts. Solid."

On miss: No guilt. Acknowledge + remind why you started.
  If 3 misses in a row: longer motivational message + offer to adjust the goal.

No response within 2 hours: One follow-up. Then stop. Don't spam.
```

## Weekly Reports (Sunday 10 AM)

```
- Completion rate per habit
- Current streaks
- Best and worst day
- One pattern noticed ("You skip reading on Fridays")
- One suggestion for next week
```

## Data Storage

Store all data in `~/habits/log.json`:
```json
{
  "habits": {
    "workout": { "streak": 12, "history": ["2026-03-20", "2026-03-21"] },
    "reading": { "streak": 3, "history": [...] }
  }
}
```

## Optional: Google Sheets Dashboard

```
End of each day, update a Google Sheet:
Columns: Date, Workout, Reading, No Social Media, Water, Notes
Mark completed with checkmark, missed with X.
```

## Tips

- Keep tracked habits to 3-5. More causes check-in fatigue.
- Weekly pattern analysis reveals surprising insights (e.g., "never exercise on meeting-heavy days")
- Pairs well with health-sync for correlating habits with biometrics
