# Skill: Email Draft

You are drafting an email on behalf of the user. The email must sound like a human wrote it -- not an AI assistant.

## Inputs
Brief includes: `to`, `cc`, `subject`, `context`, `tone`, `account`, `action`, `reply_to_message_id`, `attachments`.

## Steps

### 1. Load style guides
Read these first:
- `style/EMAIL_STYLE.md` -- user's email voice
- `style/EMAIL_TEMPLATES.md` -- templates for common email types
- `config/user.json` -- signature, email accounts

### 2. Get thread context (if replying)
If `reply_to_message_id` is set:
```bash
gog gmail read {reply_to_message_id} --account {account}
```
Read the full thread. Understand what was said, what's being asked, what the relationship is.

### 3. Research recipient (if needed)
If `context` mentions a person you don't know:
```bash
# Check email history
gog gmail messages search "from:{to}" --max 5 --account {account}
# Check memory
rg "{to}" memory/ --max-count 3
```

### 4. Draft the email
Based on `tone`:
- **professional**: Clear, direct, no fluff. 3-5 sentences typical.
- **casual**: Conversational. Like texting but with punctuation.
- **follow-up**: Brief. "Circling back on..." -- but make it specific.
- **warm-intro**: Connect two people. Why they should talk. What each brings.
- **cold-outreach**: Hook in first line. Value prop in second. Ask in third. That's it.

**Draft rules:**
- First-person always ("I", "we", "my team")
- No "I hope this email finds you well"
- No "per our conversation"
- No "don't hesitate to reach out"
- Subject line: specific > clever. "Re: Cloudflare tunnel config" not "Quick question"
- Sign off with user's actual signature from user.json

### 5. Run humanizer
**This is mandatory. No exceptions.**

Check for:
- AI vocabulary (leverage, delve, landscape, robust, seamless, elevate)
- Em dash overuse (max 1 per email)
- Rule of three patterns
- Promotional language
- "Additionally" / "Furthermore" / "Moreover"
- Overly complex sentences that could be simpler

Rewrite any flagged sections.

### 6. Verify names, dates, facts
- Is the recipient's name spelled correctly?
- Are any dates mentioned accurate?
- If referencing a meeting, does it match the calendar?
- If referencing a prior email, does the context match?

**Stop and flag if anything doesn't check out.** Wrong names are worse than no email.

### 7. Create the draft
```bash
gog gmail draft create --to "{to}" --subject "{subject}" --body "{body}" --account {account}
```

If `action: send-after-approval`, note in your response that this is queued for the user's review.

**Never send without explicit approval.** Draft is always the safe default.

### 8. Verify draft exists
```bash
gog gmail drafts list --max 3 --account {account}
```
Confirm the draft shows up.

## Common Pitfalls
- **Wrong account.** Always use the account from the brief.
- **Stale context.** If replying to a thread, read the WHOLE thread, not just the last message.
- **Over-writing.** Most emails should be 3-8 sentences. If it's longer, you're probably over-explaining.
- **Forgetting humanizer.** This is the #1 failure mode. AI-sounding emails damage credibility.

## Success = All of these are true:
- [ ] Email sounds like the user wrote it (passes humanizer check)
- [ ] All names/dates/facts verified
- [ ] Draft created in correct Gmail account
- [ ] Draft verified as existing
- [ ] No banned phrases
- [ ] Appropriate length for the tone/context
