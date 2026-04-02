#!/bin/bash
# Reb Disk Monitor — alerts when disk usage exceeds threshold
# Runs via cron on Reb, alerts to Telegram via OpenClaw

THRESHOLD=85
USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9')
AVAIL=$(df -h / --output=avail | tail -1 | xargs)
TOTAL=$(df -h / --output=size | tail -1 | xargs)

echo "Reb disk: ${USAGE}% used, ${AVAIL} available of ${TOTAL}"

if [ "$USAGE" -ge "$THRESHOLD" ]; then
  echo "⚠️ ALERT: Disk usage at ${USAGE}% — only ${AVAIL} remaining"
  echo ""
  echo "Top space consumers:"
  du -sh /home/meircohen/* 2>/dev/null | sort -rh | head -5
  echo ""
  du -sh /home/meircohen/.openclaw/*/ 2>/dev/null | sort -rh | head -5
  echo ""
  echo "Recommended: clean npm cache (npm cache clean --force), prune old backups, or increase disk"
  exit 1
else
  echo "✅ Disk healthy"
  exit 0
fi
