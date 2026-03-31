# Skill: Ops Debug

You are diagnosing and fixing an operational issue. The #1 rule: understand the problem BEFORE touching anything.

## Inputs
Brief includes: `what`, `logs`, `expected`, `urgency`, `scope`, `rollback_plan`.

## Steps

### 1. Understand the symptoms
Read `what` and `expected` carefully. What's actually broken vs what should be happening?

Don't jump to conclusions. "Gateway is down" could be:
- Gateway process crashed
- Gateway is running but not responding
- Gateway is responding but returning errors
- Network issue
- Config issue
- Dependency issue

### 2. Check system state
Start with the broadest view, narrow down:

```bash
# Agent crash history
witness query --errors --last 24h

# Process health
ps aux | grep -E "(openclaw|gateway|node)" | grep -v grep

# Recent logs
witness tail --last 50

# Cron failures
witness crons --failures
```

If `logs` path is specified, read those logs:
```bash
tail -100 {logs}
```

If `logs: witness`, use witness queries exclusively.

### 3. Narrow the scope
Based on what you find, focus on the specific subsystem:

**Gateway issues:**
```bash
openclaw gateway status
# Check config
cat ~/.openclaw/openclaw.json | jq '.gateway'
```

**Cron issues:**
```bash
witness crons --all
# Check specific cron
crontab -l | grep "relevant_pattern"
```

**Tool/API issues:**
```bash
which {tool}
{tool} --version
# Quick smoke test
{tool} --help
```

**Network issues:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:PORT
```

### 4. Identify root cause
Before fixing, write down:
1. What's broken (specific)
2. Why it broke (root cause, not symptom)
3. What the fix is
4. What could go wrong with the fix

If you can't identify root cause after 10 minutes, **stop and report what you know.** Don't flail.

### 5. Fix it
If `scope` is defined, stay within it. Don't fix "bonus" issues you discover.

**Before any config change:**
- Back up the current config: `cp file file.bak.$(date +%s)`
- Note what you're changing and why

**After any config change:**
- Verify with a real test call
- Check that the fix didn't break something else

### 6. Verify the fix
This is not optional. You cannot report "fixed" without:

```bash
# Wait 2 seconds for processes to stabilize
sleep 2

# Check actual state (specific to what was broken)
# Examples:
openclaw gateway status          # gateway was down
curl -s http://localhost:PORT    # service wasn't responding
witness query --errors --last 5m # errors should stop
ps aux | grep process_name       # process should be running
```

### 7. Document
Write a brief incident note:
```
## Incident: {what}
- **Time:** {timestamp}
- **Symptom:** {what was observed}
- **Root cause:** {why it happened}
- **Fix:** {what was changed}
- **Verified:** {how we confirmed it's fixed}
- **Prevention:** {what to do so it doesn't happen again}
```

If the fix reveals a systemic issue, note it for AGENTS.md or anti-patterns.

## Common Pitfalls
- **Don't restart everything as step 1.** Understand first, then fix. Restarting hides the root cause.
- **Config overwrites on restart.** Verify config is intact after any restart.
- **Auto-fix NEVER touches user config.** If the fix requires changing openclaw.json or similar, report what needs changing and let the user approve.
- **Scope creep.** You found 3 other issues while debugging. Log them, don't fix them.
- **"It works on my end."** Test from the perspective of the thing that was broken, not your own.

## Urgency Handling
- **now**: Skip documentation until after the fix. Verify immediately. Document after.
- **can-wait**: Full protocol. Document as you go. Take time to understand root cause.

## Success = All of these are true:
- [ ] Root cause identified (not just symptoms treated)
- [ ] Fix applied within scope
- [ ] Fix verified with actual state check
- [ ] Config backed up before changes
- [ ] Incident documented
- [ ] No user config modified without approval
