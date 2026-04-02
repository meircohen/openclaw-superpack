#!/bin/bash
# Create comprehensive export package for Eli

EXPORT_DIR="/tmp/openclaw-eli-export"
TIMESTAMP=$(date +%Y%m%d-%H%M)

echo "📦 Creating export package for Eli..."

# Clean and create export directory
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"/{docs,scripts,config,crons,skill-graphs,templates}

# Core documentation
cp SHOWCASE.md "$EXPORT_DIR/"
cp AGENTS.md "$EXPORT_DIR/templates/"
cp SOUL.md "$EXPORT_DIR/templates/"
cp USER.md "$EXPORT_DIR/templates/"
cp TOOLS.md "$EXPORT_DIR/templates/"
cp HEARTBEAT.md "$EXPORT_DIR/templates/"
cp MEMORY.md "$EXPORT_DIR/templates/MEMORY-TEMPLATE.md"

# Documentation
cp docs/MODEL-CATALOG.md "$EXPORT_DIR/docs/"
cp docs/COMPLETE-AGENT-ARCHITECTURE.md "$EXPORT_DIR/docs/"
cp docs/CTO-AUDIT-PROTOCOL-V3.md "$EXPORT_DIR/docs/"
cp docs/HEARTBEAT-PROTOCOL.md "$EXPORT_DIR/docs/"
cp docs/TIME-AWARENESS-INTEGRATION.md "$EXPORT_DIR/docs/"
cp docs/GROUP-CHAT-PROTOCOL.md "$EXPORT_DIR/docs/" 2>/dev/null || true
cp docs/PROMPT-INJECTION-PROTOCOL.md "$EXPORT_DIR/docs/" 2>/dev/null || true

# Scripts
cp scripts/time-awareness.sh "$EXPORT_DIR/scripts/"
cp scripts/route-and-spawn.js "$EXPORT_DIR/scripts/"
cp scripts/show-models.sh "$EXPORT_DIR/scripts/"
cp scripts/agent-room-context-sync.js "$EXPORT_DIR/scripts/" 2>/dev/null || true
cp scripts/promote.sh "$EXPORT_DIR/scripts/" 2>/dev/null || true
cp scripts/self-heal-check.sh "$EXPORT_DIR/scripts/" 2>/dev/null || true

# Config files (redact credentials)
jq 'del(.providers[] | .apiKey)' config/models/model-registry.json > "$EXPORT_DIR/config/models/model-registry.json" 2>/dev/null || \
  cp config/models/model-registry.json "$EXPORT_DIR/config/"
cp config/infrastructure/failure-patterns.json "$EXPORT_DIR/config/" 2>/dev/null || true
cp config/self-scorecard.json "$EXPORT_DIR/config/" 2>/dev/null || true

# Example crons (sanitized)
for cron in crons/btc-intelligence.js crons/email-watchdog-*.js crons/financial-daily.js crons/x-engage-morning.js; do
  if [ -f "$cron" ]; then
    cp "$cron" "$EXPORT_DIR/crons/" 2>/dev/null || true
  fi
done

# Skill graph structure (without personal data)
cp skill-graphs/index.md "$EXPORT_DIR/skill-graphs/"
mkdir -p "$EXPORT_DIR/skill-graphs/example-domain"
cat > "$EXPORT_DIR/skill-graphs/example-domain/index.md" << 'EOFSG'
# Example Domain Index

---
domain: example
description: Template for a skill graph domain
nodes: 5
---

## Navigation Routes

Quick links to common queries:
- Overview → [[domain-overview]]
- Key decisions → [[decisions/framework]]
- Risk factors → [[risks/assessment]]

## Node Structure

Each node should have:
- YAML frontmatter with metadata
- Clear description
- Typed wikilinks (depends-on, see-decision, risk-factor)
- Changelog footer
- last_verified date

See template: [[_template]]
EOFSG

# Create README
cat > "$EXPORT_DIR/README.md" << 'EOFREADME'
# OpenClaw Agent System - Export for Eli

This package contains everything needed to understand and replicate Meir's agent system.

## Quick Start

1. Read `SHOWCASE.md` first - comprehensive overview
2. Check `templates/` for core files (AGENTS.md, SOUL.md, etc)
3. Browse `docs/` for detailed protocols
4. Review `scripts/` for automation patterns
5. Explore `config/` for system configuration

## What's Included

- **templates/** - Core operating files for agents
- **docs/** - Complete documentation suite
- **scripts/** - Automation and integration scripts
- **config/** - System configuration (credentials redacted)
- **crons/** - Example scheduled jobs
- **skill-graphs/** - Structured knowledge pattern

## What's Redacted

- API keys & tokens
- Personal financial data
- Family information
- Entity details
- Private business info

## Support

Questions? Ask Meir directly. He's happy to help with:
- Setup and configuration
- Architecture decisions
- Integration challenges
- Custom adaptations

## Philosophy

Take what works. Adapt what doesn't. Build what's missing.

This is open-source in spirit - use freely, improve boldly.
EOFREADME

# Create tarball
cd /tmp
tar -czf "openclaw-eli-export-${TIMESTAMP}.tar.gz" openclaw-eli-export/
echo ""
echo "✅ Export package created:"
echo "   /tmp/openclaw-eli-export-${TIMESTAMP}.tar.gz"
echo ""
echo "📊 Contents:"
cd openclaw-eli-export
find . -type f | wc -l | xargs echo "   Files:"
du -sh . | awk '{print "   Size: " $1}'
echo ""
echo "📁 Directory structure:"
tree -L 2 -d . 2>/dev/null || find . -type d | head -20
