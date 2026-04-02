#!/bin/bash
# update-manager.sh — Controlled update system for OpenClaw + skills
# Safer alternative to blind auto-updates

set -euo pipefail

WORKSPACE="${HOME}/.openclaw/workspace"
SKILLS_DIR="${HOME}/.openclaw/skills"
BACKUP_DIR="${HOME}/.openclaw/backups"
STATE_FILE="${WORKSPACE}/state/updates-state.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }

# Initialize state file if doesn't exist
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        echo '{"last_check": null, "pending_updates": [], "last_backup": null, "update_history": []}' > "$STATE_FILE"
    fi
}

# Check for OpenClaw core updates
check_openclaw_updates() {
    log_info "Checking for OpenClaw core updates..."
    
    local current_version=$(openclaw --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    local latest_version=$(npm view openclaw version 2>/dev/null || echo "unknown")
    
    if [[ "$current_version" != "$latest_version" && "$latest_version" != "unknown" ]]; then
        echo "openclaw:$current_version→$latest_version"
    fi
}

# Check for skill updates
check_skill_updates() {
    log_info "Checking for skill updates..."
    
    local updates=()
    
    # Check each installed skill
    for skill_dir in "$SKILLS_DIR"/*; do
        if [[ ! -d "$skill_dir" ]]; then continue; fi
        
        local skill_name=$(basename "$skill_dir")
        local version_file="$skill_dir/VERSION"
        local package_file="$skill_dir/package.json"
        
        # Skip if no version tracking
        if [[ ! -f "$version_file" && ! -f "$package_file" ]]; then
            continue
        fi
        
        # Get current version
        local current_version=""
        if [[ -f "$version_file" ]]; then
            current_version=$(cat "$version_file")
        elif [[ -f "$package_file" ]]; then
            current_version=$(jq -r '.version // "unknown"' "$package_file")
        fi
        
        # Check if skill has git remote (custom skills won't)
        if [[ -d "$skill_dir/.git" ]]; then
            cd "$skill_dir"
            git fetch --quiet 2>/dev/null || continue
            
            local behind=$(git rev-list HEAD..@{u} --count 2>/dev/null || echo "0")
            if [[ "$behind" -gt 0 ]]; then
                local remote_version=$(git describe --tags --abbrev=0 @{u} 2>/dev/null || echo "latest")
                updates+=("$skill_name:$current_version→$remote_version ($behind commits)")
            fi
        fi
    done
    
    # Check global npm packages
    local npm_outdated=$(npm outdated -g 2>/dev/null | grep -E '(defuddle|scrapling|notebooklm|gitnexus)' || true)
    if [[ -n "$npm_outdated" ]]; then
        while IFS= read -r line; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local current=$(echo "$line" | awk '{print $2}')
            local wanted=$(echo "$line" | awk '{print $3}')
            updates+=("npm:$pkg:$current→$wanted")
        done <<< "$npm_outdated"
    fi
    
    printf '%s\n' "${updates[@]}"
}

# Backup current state
backup_current_state() {
    log_info "Creating backup..."
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${BACKUP_DIR}/${timestamp}"
    
    mkdir -p "$backup_path"
    
    # Backup OpenClaw config
    if [[ -f "${HOME}/.openclaw/openclaw.json" ]]; then
        cp "${HOME}/.openclaw/openclaw.json" "$backup_path/"
    fi
    
    # Backup skills (excluding node_modules)
    rsync -a --exclude 'node_modules' "$SKILLS_DIR/" "$backup_path/skills/"
    
    # Backup workspace critical files
    cp "$WORKSPACE"/{AGENTS.md,SOUL.md,TOOLS.md,MEMORY.md} "$backup_path/" 2>/dev/null || true
    
    # Update state
    jq --arg backup "$backup_path" '.last_backup = $backup' "$STATE_FILE" > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
    
    log_success "Backup created: $backup_path"
    echo "$backup_path"
}

# Check for local patches that would be overwritten
check_local_patches() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"
    
    if [[ ! -d "$skill_dir/.git" ]]; then
        return 0
    fi
    
    cd "$skill_dir"
    local uncommitted=$(git status --porcelain 2>/dev/null | wc -l)
    
    if [[ "$uncommitted" -gt 0 ]]; then
        log_warning "Skill '$skill_name' has local modifications:"
        git status --short
        return 1
    fi
    
    return 0
}

# Apply skill update
update_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"
    
    if [[ ! -d "$skill_dir" ]]; then
        log_error "Skill not found: $skill_name"
        return 1
    fi
    
    log_info "Updating skill: $skill_name"
    
    # Check for local patches
    if ! check_local_patches "$skill_name"; then
        read -p "Overwrite local changes? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Skipping $skill_name"
            return 1
        fi
    fi
    
    # Pull updates if git repo
    if [[ -d "$skill_dir/.git" ]]; then
        cd "$skill_dir"
        local before=$(git rev-parse HEAD)
        git pull --rebase 2>&1 | tee /tmp/update-$skill_name.log
        local after=$(git rev-parse HEAD)
        
        if [[ "$before" != "$after" ]]; then
            log_success "Updated $skill_name"
            
            # Run post-update hooks if they exist
            if [[ -f "$skill_dir/scripts/post-update.sh" ]]; then
                log_info "Running post-update hooks..."
                bash "$skill_dir/scripts/post-update.sh"
            fi
            
            # Log to update history
            local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            jq --arg skill "$skill_name" --arg time "$timestamp" --arg before "$before" --arg after "$after" \
               '.update_history += [{"skill": $skill, "timestamp": $time, "from": $before, "to": $after}]' \
               "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            
            return 0
        else
            log_info "$skill_name already up to date"
            return 0
        fi
    else
        log_warning "$skill_name is not a git repo, cannot update"
        return 1
    fi
}

# Update OpenClaw core
update_openclaw() {
    log_info "Updating OpenClaw core..."
    
    local current_version=$(openclaw --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    npm update -g openclaw 2>&1 | tee /tmp/update-openclaw.log
    
    local new_version=$(openclaw --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [[ "$current_version" != "$new_version" ]]; then
        log_success "OpenClaw updated: $current_version → $new_version"
        
        # Log to history
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq --arg time "$timestamp" --arg from "$current_version" --arg to "$new_version" \
           '.update_history += [{"skill": "openclaw", "timestamp": $time, "from": $from, "to": $to}]' \
           "$STATE_FILE" > "${STATE_FILE}.tmp"
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        
        # Check if gateway restart needed
        log_warning "OpenClaw core updated. Consider restarting gateway:"
        echo "  openclaw gateway restart"
    else
        log_info "OpenClaw already at latest version: $current_version"
    fi
}

# Update npm global packages
update_npm_package() {
    local pkg="$1"
    log_info "Updating npm package: $pkg"
    npm update -g "$pkg" 2>&1 | tee /tmp/update-npm-$pkg.log
    log_success "Updated $pkg"
}

# Health check post-update
health_check() {
    log_info "Running health checks..."
    
    local issues=0
    
    # Check OpenClaw status
    if ! openclaw status >/dev/null 2>&1; then
        log_error "OpenClaw status check failed"
        ((issues++))
    fi
    
    # Check gateway health
    if ! pgrep -f "openclaw gateway" >/dev/null 2>&1; then
        log_warning "Gateway not running"
        ((issues++))
    fi
    
    # Check skills can load
    if ! openclaw skills >/dev/null 2>&1; then
        log_error "Skills list failed to load"
        ((issues++))
    fi
    
    # Check critical scripts
    for script in heartbeat-memory-check.sh time-awareness.sh; do
        if [[ ! -x "$WORKSPACE/scripts/$script" ]]; then
            log_error "Critical script not executable: $script"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log_success "All health checks passed"
        return 0
    else
        log_error "Health check failed with $issues issues"
        return 1
    fi
}

# Rollback to previous backup
rollback() {
    local backup_path=$(jq -r '.last_backup // empty' "$STATE_FILE")
    
    if [[ -z "$backup_path" || ! -d "$backup_path" ]]; then
        log_error "No backup found to rollback to"
        return 1
    fi
    
    log_warning "Rolling back to: $backup_path"
    read -p "This will overwrite current state. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rollback cancelled"
        return 1
    fi
    
    # Restore config
    if [[ -f "$backup_path/openclaw.json" ]]; then
        cp "$backup_path/openclaw.json" "${HOME}/.openclaw/"
    fi
    
    # Restore skills
    rsync -a --delete "$backup_path/skills/" "$SKILLS_DIR/"
    
    # Restore workspace files
    cp "$backup_path"/{AGENTS.md,SOUL.md,TOOLS.md,MEMORY.md} "$WORKSPACE/" 2>/dev/null || true
    
    log_success "Rollback complete. Restart gateway:"
    echo "  openclaw gateway restart"
}

# Generate update report
generate_report() {
    log_info "Generating update report..."
    
    local openclaw_updates=$(check_openclaw_updates)
    local skill_updates=$(check_skill_updates)
    
    local count=0
    
    if [[ -n "$openclaw_updates" ]]; then
        ((count++))
    fi
    
    if [[ -n "$skill_updates" ]]; then
        count=$((count + $(echo "$skill_updates" | wc -l)))
    fi
    
    if [[ $count -eq 0 ]]; then
        echo "✓ All systems up to date"
        return 0
    fi
    
    echo "📦 $count updates available:"
    echo ""
    
    if [[ -n "$openclaw_updates" ]]; then
        echo "Core:"
        echo "  • $openclaw_updates"
        echo ""
    fi
    
    if [[ -n "$skill_updates" ]]; then
        echo "Skills:"
        while IFS= read -r update; do
            echo "  • $update"
        done <<< "$skill_updates"
        echo ""
    fi
    
    echo "To apply: update-manager.sh apply --all"
    echo "Or selective: update-manager.sh apply --skill <name>"
}

# Main command dispatcher
main() {
    init_state
    
    local cmd="${1:-check}"
    shift || true
    
    case "$cmd" in
        check)
            generate_report
            ;;
        
        backup)
            backup_current_state
            ;;
        
        apply)
            local target="${1:---all}"
            shift || true
            
            # Create backup first
            local backup_path=$(backup_current_state)
            
            if [[ "$target" == "--all" ]]; then
                log_info "Applying all updates..."
                
                # Update OpenClaw core
                local openclaw_updates=$(check_openclaw_updates)
                if [[ -n "$openclaw_updates" ]]; then
                    update_openclaw
                fi
                
                # Update skills
                local skill_updates=$(check_skill_updates)
                if [[ -n "$skill_updates" ]]; then
                    while IFS= read -r update; do
                        local skill=$(echo "$update" | cut -d: -f1)
                        if [[ "$skill" == "npm" ]]; then
                            local pkg=$(echo "$update" | cut -d: -f2)
                            update_npm_package "$pkg"
                        else
                            update_skill "$skill"
                        fi
                    done <<< "$skill_updates"
                fi
                
                # Health check
                if health_check; then
                    log_success "All updates applied successfully"
                else
                    log_error "Health check failed. Consider rollback:"
                    echo "  update-manager.sh rollback"
                    return 1
                fi
                
            elif [[ "$target" == "--skill" ]]; then
                local skill_name="$1"
                if [[ -z "$skill_name" ]]; then
                    log_error "Skill name required: --skill <name>"
                    return 1
                fi
                
                update_skill "$skill_name"
                
                if health_check; then
                    log_success "Skill updated successfully"
                else
                    log_error "Health check failed after update"
                    return 1
                fi
                
            elif [[ "$target" == "--openclaw" ]]; then
                update_openclaw
                
                if health_check; then
                    log_success "OpenClaw updated successfully"
                else
                    log_error "Health check failed after update"
                    return 1
                fi
                
            else
                log_error "Unknown target: $target"
                echo "Usage: apply [--all|--skill <name>|--openclaw]"
                return 1
            fi
            ;;
        
        rollback)
            rollback
            ;;
        
        test)
            health_check
            ;;
        
        history)
            log_info "Update history:"
            jq -r '.update_history[] | "\(.timestamp) | \(.skill): \(.from) → \(.to)"' "$STATE_FILE"
            ;;
        
        *)
            echo "Usage: update-manager.sh {check|backup|apply|rollback|test|history}"
            echo ""
            echo "Commands:"
            echo "  check           List available updates"
            echo "  backup          Create backup of current state"
            echo "  apply --all     Apply all updates"
            echo "  apply --skill <name>  Apply specific skill update"
            echo "  apply --openclaw      Update OpenClaw core only"
            echo "  rollback        Revert to last backup"
            echo "  test            Run health checks"
            echo "  history         Show update history"
            exit 1
            ;;
    esac
}

main "$@"
