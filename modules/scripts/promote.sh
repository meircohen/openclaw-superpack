#!/usr/bin/env bash
set -euo pipefail

# promote.sh
# Promote tested changes from ~/.openclaw-dev/workspace to ~/.openclaw/workspace.

PROD_ROOT="${OPENCLAW_PROD_WORKSPACE:-$HOME/.openclaw/workspace}"
DEV_ROOT="${OPENCLAW_DEV_WORKSPACE:-$HOME/.openclaw-dev/workspace}"
PROMOTE_LOG="$PROD_ROOT/logs/promote-history.log"

# Colorized output (disabled automatically when stdout is not a TTY).
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  RED=''
  BLUE=''
  NC=''
fi

usage() {
  cat <<EOF
Usage:
  ./scripts/promote.sh <component>        Promote specific component from dev
  ./scripts/promote.sh --all              Promote everything from dev
  ./scripts/promote.sh --rollback         Rollback to latest pre-promote tag
  ./scripts/promote.sh --dry-run <comp>   Show what would change
  ./scripts/promote.sh -h|--help          Show this help
EOF
}

info() {
  printf "%b[info]%b %s\n" "$BLUE" "$NC" "$1"
}

warn() {
  printf "%b[warn]%b %s\n" "$YELLOW" "$NC" "$1"
}

error() {
  printf "%b[error]%b %s\n" "$RED" "$NC" "$1" >&2
  exit 1
}

success() {
  printf "%b[ok]%b %s\n" "$GREEN" "$NC" "$1"
}

append_log() {
  local message="$1"
  mkdir -p "$(dirname "$PROMOTE_LOG")"
  printf "%s | %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$message" >> "$PROMOTE_LOG"
}

require_prod_repo() {
  [[ -d "$PROD_ROOT" ]] || error "Production workspace not found: $PROD_ROOT"
  git -C "$PROD_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || error "Production workspace is not a git repository: $PROD_ROOT"
}

require_clean_prod() {
  # Promote only from a clean production tree so rollback points stay sane.
  if [[ -n "$(git -C "$PROD_ROOT" status --porcelain)" ]]; then
    error "Production has uncommitted changes. Commit/stash before promoting."
  fi
}

require_dev_workspace() {
  [[ -d "$DEV_ROOT" ]] || error "Dev workspace not found: $DEV_ROOT"
}

validate_component_path() {
  local component="$1"
  [[ -n "$component" ]] || error "Component path is required."
  [[ "$component" != /* ]] || error "Component must be a relative path."
  [[ "$component" != *".."* ]] || error "Component path cannot contain '..'."
}

collect_changes() {
  local mode="$1"
  local component="$2"

  if [[ "$mode" == "all" ]]; then
    mapfile -t RSYNC_CHANGES < <(
      rsync -ain --delete --exclude='.git/' \
        --itemize-changes --out-format='%i|%n%L' \
        "$DEV_ROOT/" "$PROD_ROOT/" | sed '/^$/d'
    )
  else
    mapfile -t RSYNC_CHANGES < <(
      cd "$DEV_ROOT" && \
        rsync -ain --delete --exclude='.git/' \
          --itemize-changes --out-format='%i|%n%L' \
          --relative "$component" "$PROD_ROOT/" | sed '/^$/d'
    )
  fi

  CHANGED_PATHS=()
  local line
  for line in "${RSYNC_CHANGES[@]}"; do
    [[ "$line" == *"|"* ]] || continue
    CHANGED_PATHS+=("${line#*|}")
  done
}

print_change_summary() {
  local line
  info "Change summary (${#CHANGED_PATHS[@]} item(s)):"
  for line in "${RSYNC_CHANGES[@]}"; do
    [[ "$line" == *"|"* ]] || continue
    local flags="${line%%|*}"
    local path="${line#*|}"
    printf "  %s %s\n" "$flags" "$path"
  done
}

apply_sync() {
  local mode="$1"
  local component="$2"

  # Use rsync to copy only changed files and remove stale files in scope.
  if [[ "$mode" == "all" ]]; then
    rsync -a --delete --exclude='.git/' "$DEV_ROOT/" "$PROD_ROOT/"
  else
    (
      cd "$DEV_ROOT"
      rsync -a --delete --exclude='.git/' --relative "$component" "$PROD_ROOT/"
    )
  fi
}

should_restart_gateway() {
  local path
  for path in "${CHANGED_PATHS[@]}"; do
    local normalized="${path#./}"
    if [[ "$normalized" == config/* ]] || [[ "$normalized" == */config/* ]]; then
      return 0
    fi
  done
  return 1
}

run_rollback() {
  require_prod_repo
  require_clean_prod

  local last_tag
  last_tag="$(git -C "$PROD_ROOT" tag -l 'pre-promote/*' --sort=-creatordate | head -n 1)"
  [[ -n "$last_tag" ]] || error "No pre-promote tags found for rollback."

  local before_commit
  before_commit="$(git -C "$PROD_ROOT" rev-parse --short HEAD)"

  # Roll back to the last known-good pre-promote tag.
  git -C "$PROD_ROOT" reset --hard "$last_tag" >/dev/null

  local after_commit
  after_commit="$(git -C "$PROD_ROOT" rev-parse --short HEAD)"

  if command -v openclaw >/dev/null 2>&1; then
    if openclaw gateway restart >/dev/null 2>&1; then
      success "Gateway restarted after rollback."
    else
      warn "Rollback completed, but gateway restart failed."
    fi
  else
    warn "openclaw CLI not found; skipped gateway restart."
  fi

  append_log "action=rollback tag=${last_tag} from=${before_commit} to=${after_commit}"
  success "Rollback complete: ${before_commit} -> ${after_commit} (tag: ${last_tag})"
}

ACTION="promote"
MODE="component"
DRY_RUN=0
COMPONENT=""

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --rollback)
      ACTION="rollback"
      shift
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      [[ $# -gt 0 ]] || error "--dry-run requires a component path."
      COMPONENT="$1"
      shift
      ;;
    --*)
      error "Unknown option: $1"
      ;;
    *)
      if [[ -n "$COMPONENT" ]]; then
        error "Only one component path is allowed."
      fi
      COMPONENT="$1"
      shift
      ;;
  esac
done

if [[ "$ACTION" == "rollback" ]]; then
  [[ "$DRY_RUN" -eq 0 ]] || error "--dry-run cannot be combined with --rollback."
  [[ "$MODE" == "component" ]] || error "--rollback cannot be combined with --all."
  [[ -z "$COMPONENT" ]] || error "--rollback cannot be combined with a component path."
  run_rollback
  exit 0
fi

require_prod_repo
require_clean_prod
require_dev_workspace

if [[ "$MODE" == "all" ]]; then
  [[ -z "$COMPONENT" ]] || error "Do not pass a component path with --all."
  [[ "$DRY_RUN" -eq 0 ]] || error "--dry-run must be used as: --dry-run <component>."
  COMPONENT="."
  COMPONENT_LABEL="all"
else
  validate_component_path "$COMPONENT"
  COMPONENT_LABEL="${COMPONENT%/}"
  [[ -e "$DEV_ROOT/$COMPONENT_LABEL" ]] || error "Component not found in dev: $COMPONENT_LABEL"
  if [[ -d "$DEV_ROOT/$COMPONENT_LABEL" ]]; then
    COMPONENT="${COMPONENT_LABEL}/"
  else
    COMPONENT="$COMPONENT_LABEL"
  fi
fi

collect_changes "$MODE" "$COMPONENT"

if [[ "${#CHANGED_PATHS[@]}" -eq 0 ]]; then
  warn "Nothing to promote for: $COMPONENT_LABEL"
  append_log "action=$( [[ "$DRY_RUN" -eq 1 ]] && printf "dry-run" || printf "promote" ) component=${COMPONENT_LABEL} result=nothing-to-promote"
  exit 2
fi

print_change_summary

if [[ "$DRY_RUN" -eq 1 ]]; then
  success "Dry run complete. No files changed."
  append_log "action=dry-run component=${COMPONENT_LABEL} changed=${#CHANGED_PATHS[@]}"
  exit 0
fi

BACKUP_TAG="pre-promote/$(date +"%Y-%m-%d-%H%M%S")"
git -C "$PROD_ROOT" tag "$BACKUP_TAG"
success "Created backup tag: $BACKUP_TAG"

apply_sync "$MODE" "$COMPONENT"

git -C "$PROD_ROOT" add -A
if git -C "$PROD_ROOT" diff --cached --quiet; then
  warn "No git-tracked changes after sync."
  append_log "action=promote component=${COMPONENT_LABEL} tag=${BACKUP_TAG} result=nothing-tracked"
  exit 2
fi

git -C "$PROD_ROOT" commit -m "promote: ${COMPONENT_LABEL} from dev" >/dev/null
NEW_COMMIT="$(git -C "$PROD_ROOT" rev-parse --short HEAD)"
success "Created promote commit: $NEW_COMMIT"

GATEWAY_RESTARTED="no"
if should_restart_gateway; then
  info "Config changes detected. Restarting gateway..."
  if command -v openclaw >/dev/null 2>&1; then
    if openclaw gateway restart >/dev/null 2>&1; then
      GATEWAY_RESTARTED="yes"
      success "Gateway restarted."
    else
      warn "Promote succeeded, but gateway restart failed."
    fi
  else
    warn "openclaw CLI not found; skipped gateway restart."
  fi
fi

append_log "action=promote component=${COMPONENT_LABEL} tag=${BACKUP_TAG} commit=${NEW_COMMIT} changed=${#CHANGED_PATHS[@]} gateway_restart=${GATEWAY_RESTARTED}"
success "Promote complete for ${COMPONENT_LABEL}."

