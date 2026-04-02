#!/bin/bash
export PATH=/usr/local/bin:$PATH
cd ~/.openclaw/workspace

# Fleet monitoring every 5 minutes
node scripts/fleet-monitor.js auto

# Knowledge extraction daily
if [ "$(date +%H:%M)" = "09:00" ]; then
  node scripts/knowledge-extractor.js extract
fi

# Health report every hour
if [ "$(date +%M)" = "00" ]; then
  node scripts/fleet-monitor.js health > agent-room/fleet-health-$(date +%Y%m%d-%H%M).json
fi
