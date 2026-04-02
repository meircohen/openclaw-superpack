---
name: household-assistant
description: Family calendar aggregation, ambient message monitoring, pantry tracking, and household coordination
read_when: "user wants family calendar coordination, household inventory, pantry tracking, grocery lists, or ambient appointment detection"
---

# Household Assistant

Aggregate family calendars, monitor messages for appointments, track household inventory.

## Calendar Aggregation (Morning Briefing)

```
At 8:00 AM, compile all family calendars:
1. Google Work Calendar (read-only)
2. Shared Family Calendar
3. Partner's calendar
4. School calendar PDFs in ~/Documents/school-calendars/ (OCR)
5. Recent email calendar attachments

Deliver to family Telegram/Slack:
- Today's events (color-coded by source)
- 3-day lookahead for conflicts
- New events since yesterday
- Weather for outdoor events
```

## Ambient Message Monitoring

The key differentiator -- agent watches passively and acts on actionable messages.

```
Every 15 minutes, check iMessages for:
- "Your appointment is confirmed for..."
- "Can we meet on [date] at [time]?"
- "Practice moved to Saturday at 3pm"

When detected:
- Create calendar event
- Add 30-min driving buffer before AND after
- Confirm in family channel: "Created: Dentist Tue 2pm. Drive time 1:30-2:00, 3:00-3:30."
- Add partner invite if relevant

Also detect commitments:
- "I'll send that by Friday" -> create reminder
- "Let's do dinner next week" -> create calendar hold
```

## Household Inventory

Maintain `~/household/inventory.json`:

```json
{
  "items": [
    {"name": "milk", "qty": 1, "location": "fridge", "low_threshold": 1}
  ]
}
```

Update methods:
- Photo of fridge/pantry -> vision model extracts items
- Text: "We're out of eggs" / "Bought 2 gallons of milk"
- Photo of grocery receipt -> update inventory

Queries via Telegram:
- "Do we have butter?" -> location + quantity
- "What's running low?" -> items below threshold
- "Generate grocery list" -> low-stock + recipe ingredients

## Tips

- Start read-only before enabling write actions (creating events)
- Mac Mini is ideal (iMessage + Apple Calendar + always-on)
- Shared family channel builds trust and catches errors
- Photo input (school PDFs, freezer contents) is faster than typing
