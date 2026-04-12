#!/usr/bin/env bash
set -euo pipefail

# [SOVEREIGN] Gateway watchdog (minimum viable self-healing)
# - Check gateway health
# - Restart on failure
# - After 3 consecutive failures, alert Meir (via system event to last channel)

# LaunchAgents/cron often run with a minimal PATH.
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

STATE_DIR="$HOME/.openclaw/workspace/shared/.watchdog"
STATE_FILE="$STATE_DIR/gateway.json"
mkdir -p "$STATE_DIR"

# Find a usable node binary even when PATH is minimal.
NODE_BIN=""
{
  shopt -s nullglob
  for c in "$(command -v node 2>/dev/null || true)" /usr/local/bin/node /opt/homebrew/bin/node "$HOME/.nvm/versions/node"/*/bin/node; do
    if [[ -n "${c:-}" && -x "$c" ]]; then
      NODE_BIN="$c"
      break
    fi
  done
} || true

if [[ -z "$NODE_BIN" ]]; then
  echo "[WATCHDOG] ERROR: node binary not found (needed to read/write $STATE_FILE)" >&2
  exit 2
fi

now_epoch=$(date +%s)

# Billing proxy watchdog (local)
# - 401 = healthy (auth required)
# - 000 = dead / not responding
proxy_code=$(curl -s -m 5 -o /dev/null -w "%{http_code}" http://127.0.0.1:18801/v1/models || true)
if [[ "$proxy_code" == "000" ]]; then
  echo "[SELF-HEAL] billing-proxy unresponsive (000). Restarting LaunchAgent com.openclaw.billing-proxy"
  launchctl bootout "gui/501" "$HOME/Library/LaunchAgents/com.openclaw.billing-proxy.plist" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/501" "$HOME/Library/LaunchAgents/com.openclaw.billing-proxy.plist" >/dev/null 2>&1 || true
  sleep 2
  proxy_code=$(curl -s -m 5 -o /dev/null -w "%{http_code}" http://127.0.0.1:18801/v1/models || true)
  echo "[SELF-HEAL] billing-proxy restart complete (status=${proxy_code})"
fi

failures=0
last_alert_epoch=0
if [[ -f "$STATE_FILE" ]]; then
  failures=$($NODE_BIN -e 'try{const s=require("fs").readFileSync(process.env.STATE_FILE,"utf8");const j=JSON.parse(s);process.stdout.write(String(j.failures||0));}catch(e){process.stdout.write("0");}' STATE_FILE="$STATE_FILE")
  last_alert_epoch=$($NODE_BIN -e 'try{const s=require("fs").readFileSync(process.env.STATE_FILE,"utf8");const j=JSON.parse(s);process.stdout.write(String(j.last_alert_epoch||0));}catch(e){process.stdout.write("0");}' STATE_FILE="$STATE_FILE")
fi

health_ok() {
  openclaw gateway health --json >/dev/null 2>&1
}

save_state() {
  $NODE_BIN -e 'const fs=require("fs");const path=process.env.STATE_FILE;const failures=Number(process.env.FAILURES||0);const last=Number(process.env.LAST||0);fs.writeFileSync(path, JSON.stringify({failures, last_alert_epoch:last, updated_at:new Date().toISOString()}, null, 2)+"\n");'
}

# 1) Check health
if health_ok; then
  failures=0
  LAST="$last_alert_epoch" FAILURES="$failures" STATE_FILE="$STATE_FILE" save_state
  exit 0
fi

# 2) Try restart once
openclaw gateway restart >/dev/null 2>&1 || true
sleep 2
if health_ok; then
  failures=0
  LAST="$last_alert_epoch" FAILURES="$failures" STATE_FILE="$STATE_FILE" save_state
  exit 0
fi

# 3) Record failure + alert on threshold
failures=$((failures+1))

# Alert cooldown: 1 hour
cooldown=3600
should_alert=0
if [[ "$failures" -ge 3 ]]; then
  if [[ $((now_epoch - last_alert_epoch)) -ge $cooldown ]]; then
    should_alert=1
  fi
fi

if [[ "$should_alert" -eq 1 ]]; then
  last_alert_epoch="$now_epoch"
  openclaw system event --mode now --text "[SOVEREIGN][WATCHDOG] Gateway unhealthy after restart attempts (consecutive failures: ${failures}). Ran: openclaw gateway restart. Please check logs/service status." >/dev/null 2>&1 || true
fi

LAST="$last_alert_epoch" FAILURES="$failures" STATE_FILE="$STATE_FILE" save_state
exit 0
