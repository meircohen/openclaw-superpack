#!/bin/bash
# X Daily Growth Engine
# Runs 3x daily: morning (9am), midday (2pm), evening (7pm)
# Compatible with bash 3.2 (macOS default)

set -euo pipefail

TIME_SLOT="${1:-morning}"  # morning, midday, evening
WORKSPACE="$HOME/.openclaw/workspace"

source "$HOME/.openclaw/.x-env"

# Use working twitter-cli path
TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"

# Content lookup function (bash 3.2 compatible)
get_content() {
    local key="$1"
    case "$key" in
        infra_1)
            echo "Our monitoring system caught a memory leak at 4:13am. PostgreSQL was consuming 94% RAM.

Kill the process or let it OOM? We chose kill. Lost 2 minutes of data but saved 6 hours of recovery.

Lesson: Fast decisions beat perfect ones when systems are melting."
            ;;
        infra_2)
            echo "Bitcoin mining power costs: \$0.047/kWh in North Carolina.

One S19 XP pulls 3,010W. That's \$3.38/day in electricity at current rates.

Margin compression is real when Bitcoin drops 15%. Mining isn't passive income - it's infrastructure arbitrage."
            ;;
        infra_3)
            echo "ZettaPOW monitoring dashboard shows: 3 miners offline, 2 running hot (>75°C), 1 hashrate degraded.

We catch issues within 5 minutes. Before monitoring? We'd find out when the monthly payout dropped.

Operational visibility = profit protection."
            ;;
        ai_1)
            echo "AI agents write code. Humans architect systems.

The skill isn't prompting - it's knowing WHAT to build and WHEN to stop.

Models generate infinite options. Someone has to say \"3 dependencies max\" or \"this abstraction adds zero value.\""
            ;;
        ai_2)
            echo "Built AgentCo: autonomous agents that ship products.

Reality check: 40% of agent attempts fail. The ones that work? Usually the simplest approach.

AI doesn't replace judgment. It amplifies bad decisions 10x faster than humans."
            ;;
        ai_3)
            echo "Couldn't code for 20 years. Now I build faster than my old dev teams.

Not because AI is magic. Because I can iterate on working code instead of explaining requirements in Jira tickets for 3 weeks."
            ;;
        finance_1)
            echo "Credit analysis comes down to 3 ratios:
- Debt/EBITDA
- Interest coverage  
- Free cash flow to debt service

Banks love 40-metric models. Markets care about 3. The ones that answer: can you pay tomorrow?"
            ;;
        finance_2)
            echo "Bitcoin miners are power arbitrageurs disguised as tech companies.

Your edge isn't hardware - everyone has S19s. It's:
1. Power cost <\$0.05/kWh
2. Uptime >98%
3. Fast reaction to hashrate changes

Operational excellence beats equipment."
            ;;
        finance_3)
            echo "VC pattern I keep seeing: founders optimize for raising Series A instead of revenue.

18-month runway becomes 14 months of building + 4 months of fundraising.

Then they're shocked when momentum dies. Capital isn't strategy."
            ;;
        israel_1)
            echo "Israel's AI advantage: every founder spent 3-5 years in Unit 8200 or similar intelligence units.

They learned to solve impossible problems with limited resources. Under pressure. With lives at stake.

That training doesn't exist in CS degrees."
            ;;
        israel_2)
            echo "Unit 8200 → startup pipeline produces founders who:
- Ship under constraints
- Understand security from first principles  
- Think operationally, not theoretically

The talent density per capita is unmatched outside Silicon Valley."
            ;;
        israel_3)
            echo "Iran war shows AI warfare reality: signals intelligence beat satellite imagery.

Encrypted comms + pattern recognition = tracking naval movements 48 hours before physical contact.

The strategic edge is information speed, not weapons."
            ;;
        tech_1)
            echo "Everyone: \"AI will replace developers\"

Reality: AI replaced the translation layer between business logic and code.

Developers who can architect systems are MORE valuable now. The ones who just type what someone tells them? Yeah, those are gone."
            ;;
        tech_2)
            echo "Correlation monitoring: 60-day rolling mean, 2-sigma threshold, 72-hour persistence filter.

Single-day breaks are noise. The ones that matter persist.

Time dimension > threshold tuning. Saved us from chasing mean reversion ghosts."
            ;;
        tech_3)
            echo "Deepfake detection isn't about visual quality - it's metadata.

Real battlefield footage degrades across platforms (rips, compression, re-uploads).
AI outputs are pristine.

Check file properties before pixels."
            ;;
    esac
}

# Select content based on time slot
case "$TIME_SLOT" in
    morning)
        # Mix of Israeli tech, business insights, or tech takes
        CATEGORIES=("israel" "finance" "tech")
        ;;
    midday)
        # Infrastructure war stories or AI insights (technical audience active)
        CATEGORIES=("infra" "ai")
        ;;
    evening)
        # Engagement-heavy: contrarian takes, finance, or war stories
        CATEGORIES=("tech" "finance" "infra")
        ;;
esac

# Random category + content selection (bash 3.2 compatible)
CATEGORY="${CATEGORIES[$RANDOM % ${#CATEGORIES[@]}]}"
CONTENT_NUM=$((1 + RANDOM % 3))  # 3 items per category
CONTENT_KEY="${CATEGORY}_${CONTENT_NUM}"

TWEET_TEXT="$(get_content "$CONTENT_KEY")"

# Post tweet
echo "📤 Posting $TIME_SLOT content ($CATEGORY)..."
"$TWITTER_CLI" post "$TWEET_TEXT"

# Log to engagement log
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"action\":\"scheduled_post\",\"time_slot\":\"$TIME_SLOT\",\"category\":\"$CATEGORY\",\"content\":\"${TWEET_TEXT:0:100}...\"}" >> "$WORKSPACE/artifacts/x-engagement-log.jsonl"

echo "✅ Posted $TIME_SLOT tweet ($CATEGORY)"
