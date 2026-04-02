#!/bin/bash
# tool-audit.sh — Find installed tools NOT documented in TOOLS.md
# Run weekly or after any install session

TOOLS_MD="$HOME/.openclaw/workspace/TOOLS.md"
MISSING=()

# Known aliases — packages whose real name differs from the documented name
ALIASES="claude-code:claude codex-responses-api-proxy:codex claude-max-api-proxy:claude defuddle-cli:defuddle openai-whisper:whisper docling-tools:docling openhue-cli:openhue openhue:openhue"

is_known() {
  local pkg="$1"
  for alias in $ALIASES; do
    local from="${alias%%:*}" to="${alias##*:}"
    [[ "$pkg" == "$from" ]] && grep -qi "$to" "$TOOLS_MD" 2>/dev/null && return 0
  done
  return 1
}

echo "🔍 Tool Audit — $(date '+%Y-%m-%d %H:%M')"
echo "Comparing installed tools against TOOLS.md..."
echo ""

# Check global npm packages
for pkg in $(npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -I{} basename {}); do
  [[ "$pkg" == "npm" || "$pkg" == "corepack" || "$pkg" == "openclaw" ]] && continue
  if ! grep -qi "$pkg" "$TOOLS_MD" 2>/dev/null && ! is_known "$pkg"; then
    MISSING+=("npm-global: $pkg")
  fi
done

# Check pipx packages
for pkg in $(pipx list --short 2>/dev/null | awk '{print $1}'); do
  if ! grep -qi "$pkg" "$TOOLS_MD" 2>/dev/null && ! is_known "$pkg"; then
    MISSING+=("pipx: $pkg")
  fi
done

# Check ~/.local/bin
for bin in $(ls ~/.local/bin/ 2>/dev/null); do
  [[ "$bin" == "uv" || "$bin" == "uvx" ]] && continue
  if ! grep -qi "$bin" "$TOOLS_MD" 2>/dev/null && ! is_known "$bin"; then
    MISSING+=("~/.local/bin: $bin")
  fi
done

# Check custom homebrew CLIs (non-library)
for pkg in gh gogcli himalaya memo remindctl ripgrep spogo openhue-cli summarize tmux cloudflared vault rclone tesseract pandoc weasyprint freeze fdupes ffmpeg bun tailscale awscli imagemagick poppler; do
  if brew list "$pkg" &>/dev/null && ! grep -qi "$pkg" "$TOOLS_MD" 2>/dev/null && ! is_known "$pkg"; then
    MISSING+=("brew: $pkg")
  fi
done

# Check API scripts
for script in $(ls "$HOME/.openclaw/workspace/scripts/apis/"*.sh 2>/dev/null | xargs -I{} basename {} .sh); do
  [[ "$script" == "test-all" || "$script" == "test-simple" || "$script" == "demo-batch2" || "$script" == "verify-batch2" || "$script" == "examples" ]] && continue
  if ! grep -qi "$script" "$TOOLS_MD" 2>/dev/null; then
    MISSING+=("api-script: $script")
  fi
done

# Check skills
for skill_dir in $(ls -d "$HOME/.openclaw/skills/"*/ "$HOME/.nvm/versions/node/v22.22.0/lib/node_modules/openclaw/skills/"*/ 2>/dev/null); do
  skill=$(basename "$skill_dir")
  # Skills are in available_skills, not TOOLS.md — but custom ones with CLIs should be noted
done

# Report
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${#MISSING[@]} -eq 0 ]; then
  echo "✅ All installed tools are documented in TOOLS.md"
else
  echo "⚠️  ${#MISSING[@]} tools NOT in TOOLS.md:"
  echo ""
  for item in "${MISSING[@]}"; do
    echo "  ❌ $item"
  done
  echo ""
  echo "Action: Add these to TOOLS.md with usage notes and decision-tree entries."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Known aliases — don't flag these
# claude-code = claude, defuddle-cli = defuddle, openai-whisper = whisper
# docling-tools = docling, openhue-cli = openhue, codex-responses-api-proxy = codex
# claude-max-api-proxy = claude
