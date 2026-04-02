#!/usr/bin/env bash
# route.sh — Intelligent task router with local adaptive system preference
#
# Usage:
#   bash scripts/route.sh "Review the iCare codebase for SQL injection vulnerabilities"
#   bash scripts/route.sh --json --explain "Deploy the new worker to Cloudflare"
#
# No API calls — keyword routing plus local stats from shared/agent-stats/*.jsonl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="/Users/meircohen/.openclaw/workspace"
ROUTING_TABLE="$SCRIPT_DIR/routing-table.json"
STATS_DIR="$WORKSPACE/shared/agent-stats"

JSON_OUTPUT=false
EXPLAIN_OUTPUT=false
TASK=""

load_agent_stats() {
  local agent="$1"
  local stats_file="$STATS_DIR/${agent}.jsonl"

  if [[ -z "$agent" || ! -f "$stats_file" ]]; then
    echo '[]'
    return
  fi

  jq -s '
    reduce .[] as $entry ({};
      .[$entry.system] = (
        .[$entry.system] // {system: $entry.system, total: 0, pass: 0, warn: 0, fail: 0}
        | .total += 1
        | if $entry.verdict == "PASS" then .pass += 1
          elif $entry.verdict == "WARN" then .warn += 1
          else .fail += 1
          end
      )
    )
    | [.[] | . + {
        passRate: (if .total > 0 then ((.pass * 100) / .total | floor) else 0 end),
        warnRate: (if .total > 0 then ((.warn * 100) / .total | floor) else 0 end),
        failRate: (if .total > 0 then ((.fail * 100) / .total | floor) else 0 end)
      }]
    | sort_by(-.passRate, -.total, .system)
  ' "$stats_file" 2>/dev/null || echo '[]'
}

build_stats_text() {
  local stats_json="$1"
  if [[ "$(echo "$stats_json" | jq 'length')" -eq 0 ]]; then
    echo "agent stats: none"
    return
  fi

  echo "agent stats:"
  echo "$stats_json" | jq -r '.[] | "  " + .system + ": pass=" + (.pass|tostring) + " warn=" + (.warn|tostring) + " fail=" + (.fail|tostring) + " total=" + (.total|tostring) + " pass_rate=" + (.passRate|tostring) + "%"'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUTPUT=true; shift ;;
    --explain) EXPLAIN_OUTPUT=true; shift ;;
    --) shift; TASK="$*"; break ;;
    -*) echo "ERROR: Unknown flag '$1'" >&2; exit 1 ;;
    *) TASK="$*"; break ;;
  esac
done

if [[ -z "$TASK" ]]; then
  echo "ERROR: Usage: route.sh [--json] [--explain] \"<task description>\"" >&2
  exit 1
fi

if [[ ! -f "$ROUTING_TABLE" ]]; then
  echo "ERROR: Routing table not found at $ROUTING_TABLE" >&2
  exit 1
fi

TASK_LOWER=$(echo "$TASK" | tr '[:upper:]' '[:lower:]')

best_domain=""
best_system=""
best_agent=""
best_reason=""
best_score=0
matched_keywords=""

route_count=$(jq '.routes | length' "$ROUTING_TABLE")

for ((i = 0; i < route_count; i++)); do
  domain=$(jq -r ".routes[$i].domain" "$ROUTING_TABLE")
  system=$(jq -r ".routes[$i].system" "$ROUTING_TABLE")
  agent=$(jq -r ".routes[$i].agent // empty" "$ROUTING_TABLE")
  reason=$(jq -r ".routes[$i].reason" "$ROUTING_TABLE")

  score=0
  current_matches=""
  while IFS= read -r keyword; do
    [[ -n "$keyword" ]] || continue
    kw_lower=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
    if echo "$TASK_LOWER" | grep -qF "$kw_lower"; then
      word_count=$(echo "$kw_lower" | wc -w | tr -d ' ')
      score=$((score + word_count))
      current_matches+="${current_matches:+, }$keyword"
    fi
  done < <(jq -r ".routes[$i].keywords[]" "$ROUTING_TABLE")

  if [[ $score -gt $best_score ]]; then
    best_score=$score
    best_domain="$domain"
    best_system="$system"
    best_agent="$agent"
    best_reason="$reason"
    matched_keywords="$current_matches"
  fi
done

static_system=""
static_agent=""
static_reason=""
static_domain=""
static_source="route"

if [[ $best_score -eq 0 ]]; then
  static_system=$(jq -r '.fallback.system' "$ROUTING_TABLE")
  static_agent=$(jq -r '.fallback.agent // empty' "$ROUTING_TABLE")
  static_reason=$(jq -r '.fallback.reason' "$ROUTING_TABLE")
  static_domain="general"
  static_source="fallback"
  confidence="low"
elif [[ $best_score -ge 3 ]]; then
  static_system="$best_system"
  static_agent="$best_agent"
  static_reason="$best_reason"
  static_domain="$best_domain"
  confidence="high"
else
  static_system="$best_system"
  static_agent="$best_agent"
  static_reason="$best_reason"
  static_domain="$best_domain"
  confidence="medium"
fi

final_system="$static_system"
final_agent="$static_agent"
final_reason="$static_reason"
adaptive_applied=false
adaptive_reason="No adaptive override."
agent_stats_json='[]'

if [[ -n "$static_agent" ]]; then
  agent_stats_json=$(load_agent_stats "$static_agent")
  stats_count=$(echo "$agent_stats_json" | jq 'length')

  if [[ $stats_count -eq 0 ]]; then
    adaptive_reason="No history for ${static_agent}; using routing-table default."
  else
    current_stats=$(echo "$agent_stats_json" | jq -c --arg system "$static_system" 'map(select(.system == $system))[0]')
    best_stats=$(echo "$agent_stats_json" | jq -c '.[0]')

    if [[ "$current_stats" == "null" ]]; then
      adaptive_reason="No history for ${static_agent} on ${static_system}; using routing-table default."
    else
      current_pass_rate=$(echo "$current_stats" | jq -r '.passRate')
      best_pass_rate=$(echo "$best_stats" | jq -r '.passRate')
      best_stats_system=$(echo "$best_stats" | jq -r '.system')

      if [[ "$best_stats_system" != "$static_system" && $best_pass_rate -gt 80 && $current_pass_rate -lt 60 ]]; then
        final_system="$best_stats_system"
        adaptive_applied=true
        adaptive_reason="Adaptive override: ${static_agent} has ${best_pass_rate}% pass rate on ${best_stats_system} and ${current_pass_rate}% on ${static_system}."
        final_reason="${static_reason} Adapted to ${best_stats_system} based on local agent stats."
      else
        adaptive_reason="Agent stats did not trigger an override for ${static_agent}."
      fi
    fi
  fi
fi

if $JSON_OUTPUT; then
  if $EXPLAIN_OUTPUT; then
    jq -n \
      --arg system "$final_system" \
      --arg agent "${final_agent:-null}" \
      --arg reason "$final_reason" \
      --arg domain "$static_domain" \
      --arg confidence "$confidence" \
      --arg static_system "$static_system" \
      --arg static_agent "${static_agent:-null}" \
      --arg static_source "$static_source" \
      --arg matched_keywords "$matched_keywords" \
      --arg adaptive_reason "$adaptive_reason" \
      --argjson adaptive_applied "$(if $adaptive_applied; then echo true; else echo false; fi)" \
      --argjson score "$best_score" \
      --argjson agent_stats "$agent_stats_json" \
      '{
        system: $system,
        agent: (if $agent == "null" or $agent == "" then null else $agent end),
        reason: $reason,
        domain: $domain,
        confidence: $confidence,
        score: $score,
        explain: {
          static: {
            source: $static_source,
            system: $static_system,
            agent: (if $static_agent == "null" or $static_agent == "" then null else $static_agent end),
            matchedKeywords: (if $matched_keywords == "" then [] else ($matched_keywords | split(", ")) end)
          },
          adaptive: {
            applied: $adaptive_applied,
            reason: $adaptive_reason
          },
          agentStats: $agent_stats
        }
      }'
  else
    jq -n \
      --arg system "$final_system" \
      --arg agent "${final_agent:-null}" \
      --arg reason "$final_reason" \
      --arg domain "$static_domain" \
      --arg confidence "$confidence" \
      --argjson score "$best_score" \
      '{system: $system, agent: (if $agent == "null" or $agent == "" then null else $agent end), reason: $reason, domain: $domain, confidence: $confidence, score: $score}'
  fi
else
  echo "system=$final_system agent=${final_agent:-none} domain=$static_domain confidence=$confidence"
  echo "reason: $final_reason"
  if $EXPLAIN_OUTPUT; then
    echo "explain:"
    echo "  static source: $static_source"
    echo "  static route: system=$static_system agent=${static_agent:-none} score=$best_score"
    if [[ -n "$matched_keywords" ]]; then
      echo "  matched keywords: $matched_keywords"
    else
      echo "  matched keywords: none"
    fi
    echo "  adaptive: $adaptive_reason"
    build_stats_text "$agent_stats_json"
  fi
fi
