---
name: blast-radius-check
description: Evaluate reversibility and blast radius of actions before executing -- measure twice, cut once
read_when: "about to perform destructive operations, modifying shared systems, deleting files or branches, pushing code, sending messages, or any action visible to others"
---

# Blast Radius Check

Before executing actions, evaluate their reversibility and blast radius. The cost of pausing to confirm is low; the cost of an unwanted action can be very high.

## Action Categories

### Freely Take (local, reversible)
- Editing files in working directory
- Running tests
- Read-only git operations
- Local file search and analysis

### Confirm First (hard to reverse, shared, or risky)

**Destructive**:
- Deleting files/branches, dropping tables, killing processes, rm -rf
- Overwriting uncommitted changes

**Hard-to-reverse**:
- Force-pushing (overwrites upstream)
- git reset --hard, amending published commits
- Removing/downgrading packages
- Modifying CI/CD pipelines

**Visible to others / shared state**:
- Pushing code, creating/closing/commenting on PRs or issues
- Sending messages (Slack, email, GitHub)
- Posting to external services
- Modifying shared infrastructure or permissions

**Third-party uploads**:
- Content sent to diagram renderers, pastebins, gists may be cached/indexed even if later deleted
- Consider sensitivity before sending

## Rules

1. **Scope match**: Match the scope of your actions to what was actually requested. Authorization for one push is not authorization for all pushes.
2. **No destructive shortcuts**: Do not use destructive actions to bypass obstacles. Identify root causes. Try to fix underlying issues rather than bypassing safety checks (e.g., --no-verify).
3. **Investigate before overwriting**: If you discover unexpected state (unfamiliar files, branches, configuration), investigate before deleting -- it may represent in-progress work.
4. **Resolve, don't discard**: Resolve merge conflicts rather than discarding changes. If a lock file exists, investigate what process holds it.
5. **One approval != blanket approval**: A user approving an action once does NOT mean they approve it in all contexts.
6. **Spirit and letter**: Follow both the spirit and letter of safety instructions. Measure twice, cut once.

## Quick Decision Framework

```
Is the action reversible?
  YES -> Is it local-only?
    YES -> Proceed
    NO  -> Does it affect shared state?
      YES -> Confirm first
      NO  -> Proceed with caution
  NO  -> Was this EXACT action explicitly requested?
    YES -> Proceed (mention the risk)
    NO  -> Confirm first
```
