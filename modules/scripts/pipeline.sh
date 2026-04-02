#!/usr/bin/env bash
# pipeline.sh — Execute a chained pipeline of delegation tasks
# Usage: bash scripts/pipeline.sh <pipeline.json> [--var key=value ...]
#
# Reads a pipeline definition, executes steps sequentially (respecting dependencies),
# passes output between steps via temp files, and reports status.
#
# Compatible with macOS bash 3.2 (no associative arrays).

set -euo pipefail

WORKSPACE="/Users/meircohen/.openclaw/workspace"
DELEGATE="$WORKSPACE/scripts/delegate.sh"
TIMESTAMP=$(date +%s)

# --- Arg validation ---
if [ $# -lt 1 ]; then
  echo "ERROR: Usage: bash scripts/pipeline.sh <pipeline.json> [--var key=value ...]" >&2
  exit 1
fi

PIPELINE_FILE="$1"
shift

# Resolve relative paths
if [ "${PIPELINE_FILE:0:1}" != "/" ]; then
  if [ -f "$WORKSPACE/skills/delegation/pipelines/$PIPELINE_FILE" ]; then
    PIPELINE_FILE="$WORKSPACE/skills/delegation/pipelines/$PIPELINE_FILE"
  elif [ -f "$WORKSPACE/skills/delegation/pipelines/${PIPELINE_FILE}.json" ]; then
    PIPELINE_FILE="$WORKSPACE/skills/delegation/pipelines/${PIPELINE_FILE}.json"
  elif [ -f "$WORKSPACE/$PIPELINE_FILE" ]; then
    PIPELINE_FILE="$WORKSPACE/$PIPELINE_FILE"
  fi
fi

if [ ! -f "$PIPELINE_FILE" ]; then
  echo "ERROR: Pipeline file not found: $PIPELINE_FILE" >&2
  exit 1
fi

if ! jq . "$PIPELINE_FILE" > /dev/null 2>&1; then
  echo "ERROR: Pipeline file is not valid JSON" >&2
  exit 1
fi

PIPELINE_NAME=$(jq -r '.pipeline' "$PIPELINE_FILE")
PIPELINE_DESC=$(jq -r '.description // ""' "$PIPELINE_FILE")
PIPELINE_TIMEOUT=$(jq -r '.timeout // 1200' "$PIPELINE_FILE")
ON_FAILURE=$(jq -r '.on_failure // "stop"' "$PIPELINE_FILE")
STEP_COUNT=$(jq '.steps | length' "$PIPELINE_FILE")

# --- Parse --var arguments into a temp file (key=value lines) ---
VARS_FILE=$(mktemp /tmp/pipeline-vars.XXXXXX)
trap "rm -f $VARS_FILE" EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --var)
      shift
      echo "$1" >> "$VARS_FILE"
      ;;
    *)
      echo "WARNING: Unknown argument: $1" >&2
      ;;
  esac
  shift
done

# --- Set up output directory ---
OUTDIR="/tmp/pipeline-${PIPELINE_NAME}-${TIMESTAMP}"
mkdir -p "$OUTDIR"

# Step status stored as files: $OUTDIR/.status_<step_id> containing the status string
set_status() { echo "$2" > "$OUTDIR/.status_$1"; }
get_status() { cat "$OUTDIR/.status_$1" 2>/dev/null || echo "pending"; }

echo "═══════════════════════════════════════════════════"
echo "  Pipeline: ${PIPELINE_NAME}"
echo "  ${PIPELINE_DESC}"
echo "  Steps: ${STEP_COUNT} | Timeout: ${PIPELINE_TIMEOUT}s | On failure: ${ON_FAILURE}"
echo "  Output dir: ${OUTDIR}"
echo "═══════════════════════════════════════════════════"
echo ""

# --- Substitute variables in a string ---
substitute_vars() {
  local text="$1"
  
  # Substitute --var values
  while IFS='=' read -r key val; do
    [ -z "$key" ] && continue
    text=$(echo "$text" | sed "s|{{${key}}}|${val}|g")
  done < "$VARS_FILE"
  
  # Substitute step outputs: {{step_id.output}}
  for outfile in "$OUTDIR"/step_*.out; do
    [ -f "$outfile" ] || continue
    local basename=$(basename "$outfile" .out)
    local step_id="${basename#step_}"
    local output_content
    output_content=$(head -c 4000 "$outfile")
    # Escape for sed
    local escaped_content
    escaped_content=$(printf '%s' "$output_content" | sed 's/[&/\]/\\&/g' | tr '\n' ' ')
    text=$(echo "$text" | sed "s|{{${step_id}.output}}|${escaped_content}|g")
  done
  
  echo "$text"
}

# --- Check if step dependencies are met ---
deps_met() {
  local step_index=$1
  local deps
  deps=$(jq -r ".steps[$step_index].depends_on // empty" "$PIPELINE_FILE")
  
  [ -z "$deps" ] && return 0
  
  # Handle both string and array
  local dep_list
  if echo "$deps" | jq -e 'type == "array"' > /dev/null 2>&1; then
    dep_list=$(echo "$deps" | jq -r '.[]')
  else
    dep_list="$deps"
  fi
  
  for dep in $dep_list; do
    if [ "$(get_status "$dep")" != "done" ]; then
      return 1
    fi
  done
  return 0
}

# --- Execute a single step ---
execute_step() {
  local step_index=$1
  local step_id step_type step_brief review_gate
  
  step_id=$(jq -r ".steps[$step_index].id" "$PIPELINE_FILE")
  step_type=$(jq -r ".steps[$step_index].type" "$PIPELINE_FILE")
  step_brief=$(jq -c ".steps[$step_index].brief" "$PIPELINE_FILE")
  review_gate=$(jq -r ".steps[$step_index].review_gate // false" "$PIPELINE_FILE")
  
  # Substitute variables in the brief
  step_brief=$(substitute_vars "$step_brief")
  
  local step_num=$((step_index + 1))
  echo "──────────────────────────────────────────────────"
  echo "  Step ${step_num}/${STEP_COUNT}: [${step_id}] (${step_type})"
  echo "──────────────────────────────────────────────────"
  
  local prompt_file="$OUTDIR/step_${step_id}.prompt"
  local output_file="$OUTDIR/step_${step_id}.out"
  
  if ! bash "$DELEGATE" "$step_type" "$step_brief" > "$prompt_file" 2>"$OUTDIR/step_${step_id}.err"; then
    echo "  ✗ FAILED: delegate.sh returned error"
    cat "$OUTDIR/step_${step_id}.err" >&2
    set_status "$step_id" "failed"
    return 1
  fi
  
  local prompt_size
  prompt_size=$(wc -c < "$prompt_file" | tr -d ' ')
  echo "  ✓ Prompt generated (${prompt_size} bytes)"
  echo "  → Prompt: $prompt_file"
  echo "  → Output: $output_file"
  
  # Write placeholder output (Oz replaces this with actual sub-agent output)
  local agent_hint
  agent_hint=$(jq -r '._agent // "sonnet-4"' "$WORKSPACE/skills/delegation/templates/${step_type}.json" 2>/dev/null || echo "sonnet-4")
  
  cat > "$output_file" <<EOF
# Step Output: ${step_id}
# Type: ${step_type}
# Status: PENDING — spawn prompt ready
# Agent: ${agent_hint}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#
# To execute: spawn a sub-agent with the contents of ${prompt_file}
# After completion: replace this file with actual output
EOF
  
  if [ "$review_gate" = "true" ]; then
    echo "  ⏸  REVIEW GATE — pausing for review before continuing."
    echo "     Review: $output_file"
    set_status "$step_id" "review"
    return 2
  fi
  
  set_status "$step_id" "done"
  echo "  ✓ Step ready"
  echo ""
  return 0
}

# --- Main execution loop ---
FAILED=0
COMPLETED=0
START_TIME=$(date +%s)

i=0
while [ $i -lt "$STEP_COUNT" ]; do
  step_id=$(jq -r ".steps[$i].id" "$PIPELINE_FILE")
  
  # Check timeout
  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [ $ELAPSED -ge "$PIPELINE_TIMEOUT" ]; then
    echo "  ✗ TIMEOUT: Pipeline exceeded ${PIPELINE_TIMEOUT}s"
    set_status "$step_id" "timeout"
    break
  fi
  
  # Check dependencies
  if ! deps_met $i; then
    dep_name=$(jq -r ".steps[$i].depends_on" "$PIPELINE_FILE")
    echo "  ⊘ Step [${step_id}]: Skipped (dependency '${dep_name}' not met)"
    set_status "$step_id" "skipped"
    i=$((i + 1))
    continue
  fi
  
  # Execute step
  set +e
  execute_step $i
  result=$?
  set -e
  
  if [ $result -eq 1 ]; then
    FAILED=$((FAILED + 1))
    if [ "$ON_FAILURE" = "stop" ]; then
      echo ""
      echo "  ✗ Pipeline stopped on failure (on_failure=stop)"
      break
    fi
  elif [ $result -eq 2 ]; then
    echo ""
    echo "  ⏸  Pipeline paused at review gate"
    break
  else
    COMPLETED=$((COMPLETED + 1))
  fi
  
  i=$((i + 1))
done

# --- Final summary ---
ELAPSED=$(( $(date +%s) - START_TIME ))

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Pipeline Complete: ${PIPELINE_NAME}"
echo "  Completed: ${COMPLETED}/${STEP_COUNT} | Failed: ${FAILED} | Time: ${ELAPSED}s"
echo "  Output: ${OUTDIR}/"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Step Status:"
i=0
while [ $i -lt "$STEP_COUNT" ]; do
  sid=$(jq -r ".steps[$i].id" "$PIPELINE_FILE")
  stype=$(jq -r ".steps[$i].type" "$PIPELINE_FILE")
  status=$(get_status "$sid")
  case "$status" in
    done)    icon="✓" ;;
    failed)  icon="✗" ;;
    skipped) icon="⊘" ;;
    review)  icon="⏸" ;;
    timeout) icon="⏱" ;;
    *)       icon="·" ;;
  esac
  echo "  ${icon} [${sid}] ${stype} → ${status}"
  i=$((i + 1))
done

echo ""
echo "Prompt files (ready for sub-agent spawn):"
ls -1 "$OUTDIR"/step_*.prompt 2>/dev/null | while read f; do
  echo "  $f"
done

if [ $FAILED -gt 0 ] && [ "$ON_FAILURE" = "stop" ]; then
  exit 1
fi
exit 0
