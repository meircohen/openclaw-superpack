#!/bin/bash

# Weekly Rating Report Generator
# Shows agent performance for the past 7 days

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RATINGS_FILE="$SCRIPT_DIR/ratings.jsonl"

if [ ! -f "$RATINGS_FILE" ]; then
    echo "No ratings file found. Use rate.sh to log ratings first."
    exit 1
fi

# Get date 7 days ago
WEEK_AGO=$(date -d '7 days ago' -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -v-7d -u +"%Y-%m-%dT%H:%M:%S")
CURRENT_WEEK=$(date -u +"%B %d")

echo "=== Agent Ratings — Week of $CURRENT_WEEK ==="

# Filter ratings from last 7 days and analyze with Python
python3 << EOF
import json
import sys
import os
from datetime import datetime, timedelta
from collections import defaultdict

script_dir = os.path.dirname(os.path.abspath('$0'))
ratings_file = os.path.join(script_dir, 'ratings.jsonl')
week_ago = datetime.now() - timedelta(days=7)

agent_stats = defaultdict(lambda: {'total': 0, 'good': 0, 'bad': 0, 'partial': 0})
total_ratings = 0

try:
    with open(ratings_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
                
            rating = json.loads(line)
            rating_time = datetime.fromisoformat(rating['timestamp'].replace('Z', '+00:00').replace('+00:00', ''))
            
            if rating_time >= week_ago:
                agent = rating['agent']
                rating_value = rating['rating']
                
                agent_stats[agent]['total'] += 1
                agent_stats[agent][rating_value] += 1
                total_ratings += 1

    if total_ratings == 0:
        print("No ratings found in the past 7 days.")
        sys.exit(0)

    # Calculate satisfaction rates and sort
    agent_performance = []
    for agent, stats in agent_stats.items():
        satisfaction_rate = (stats['good'] + 0.5 * stats['partial']) / stats['total']
        agent_performance.append((agent, satisfaction_rate, stats))

    agent_performance.sort(key=lambda x: x[1], reverse=True)

    # Top performers (>= 75% satisfaction)
    top_performers = [x for x in agent_performance if x[1] >= 0.75]
    if top_performers:
        print("\nTop Performers:")
        for agent, rate, stats in top_performers:
            rate_pct = int(rate * 100)
            print(f"  {agent}: {rate_pct}% ({stats['good']}/{stats['total']} good)")

    # Underperformers (< 50% satisfaction)
    underperformers = [x for x in agent_performance if x[1] < 0.5]
    if underperformers:
        print("\nUnderperformers:")
        for agent, rate, stats in underperformers:
            rate_pct = int(rate * 100)
            warning = " ⚠️ Review needed" if rate < 0.3 else ""
            print(f"  {agent}: {rate_pct}% ({stats['good']}/{stats['total']} good){warning}")

    # Overall stats
    total_good = sum(stats['good'] for _, _, stats in agent_performance)
    total_partial = sum(stats['partial'] for _, _, stats in agent_performance)
    overall_satisfaction = (total_good + 0.5 * total_partial) / total_ratings if total_ratings > 0 else 0

    print(f"\nTotal ratings this week: {total_ratings}")
    print(f"Average satisfaction: {int(overall_satisfaction * 100)}%")

except FileNotFoundError:
    print("No ratings file found.")
except Exception as e:
    print(f"Error reading ratings: {e}")

EOF