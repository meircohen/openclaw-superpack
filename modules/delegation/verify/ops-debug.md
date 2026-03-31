# Verification: Ops Debug

Run these checks BEFORE reporting "fixed".

## Checks

### 1. Root cause identified
- [ ] You can explain in one sentence WHY it broke (not just what was broken)
- [ ] Root cause is specific (not "config issue" -- which config, which value, why)

### 2. Fix applied
- [ ] Change was made within the defined `scope` (if set)
- [ ] No user config was modified without approval
- [ ] Config backup exists (file.bak.timestamp) before any changes

### 3. Fix verified with actual state
Wait 2 seconds after the fix, then:
```bash
sleep 2
# Then check the SPECIFIC thing that was broken:
```
- [ ] The original symptom is gone (test the exact failure described in `what`)
- [ ] Related functionality still works (didn't break something adjacent)
- [ ] Process is running if it should be (`ps aux | grep ...`)
- [ ] Service responds if it should (`curl -s http://localhost:...`)
- [ ] Errors stopped in logs (`witness query --errors --last 2m`)

### 4. No collateral damage
- [ ] Other services/crons still working
- [ ] No config files were overwritten or corrupted
- [ ] Gateway config intact: `cat ~/.openclaw/openclaw.json | jq '.' > /dev/null && echo OK`

### 5. Documented
- [ ] Incident note written (symptom, root cause, fix, prevention)
- [ ] If systemic: noted for anti-patterns or AGENTS.md update

### 6. Rollback path exists
- [ ] You can describe how to undo the fix if it causes problems
- [ ] Config backup is accessible
- [ ] If `rollback_plan` was in the brief, it's been validated

## If Any Check Fails
Report what you found. Especially:
- If root cause is uncertain, say so -- "fixed the symptom but root cause unclear"
- If verification shows partial fix, report what's working and what isn't
- If collateral damage detected, STOP and report immediately
