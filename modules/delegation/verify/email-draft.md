# Verification: Email Draft

Run these checks BEFORE reporting completion.

## Checks

### 1. Draft exists in Gmail
```bash
gog gmail drafts list --max 3 --account {account}
```
- [ ] Draft appears in the list
- [ ] Subject line matches what you drafted
- [ ] Correct account was used

### 2. Humanizer passed
Re-read the draft one more time. Check for:
- [ ] No AI vocabulary (leverage, delve, landscape, robust, seamless, elevate)
- [ ] Max 1 em dash in entire email
- [ ] No "Additionally" / "Furthermore" / "Moreover"
- [ ] No rule-of-three patterns ("X, Y, and Z" used for rhetorical effect)
- [ ] No promotional language
- [ ] Reads like a human wrote it at their desk, not an AI generated it

### 3. Factual accuracy
- [ ] Recipient name spelled correctly
- [ ] Email address is correct
- [ ] Any dates mentioned are verified against calendar
- [ ] Any referenced meetings/conversations actually happened
- [ ] Any commitments in the email are things the user actually intends to do

### 4. Tone check
- [ ] Matches requested tone (professional/casual/follow-up/warm-intro/cold-outreach)
- [ ] Appropriate length (3-8 sentences typical, shorter for follow-ups)
- [ ] Signature matches user.json

### 5. Safety
- [ ] No sensitive information exposed
- [ ] No confidential details about other people/companies
- [ ] If `action: draft` -- confirmed it's saved as draft, NOT sent
- [ ] If replying -- thread context is accurate

## If Any Check Fails
Report which check failed. For humanizer failures, include the flagged phrases and suggested rewrites. Never send a draft that fails humanizer.
