#!/bin/bash
# System Cleanup & Organization Script
# Cleans caches, organizes files, removes duplicates

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 SYSTEM CLEANUP & ORGANIZATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DRY_RUN="${1:-true}"

if [ "$DRY_RUN" = "true" ]; then
    echo "⚠️  DRY RUN MODE - No files will be deleted"
    echo "   Run with 'false' to execute: $0 false"
    echo ""
fi

# Track space saved
SPACE_BEFORE=$(df -k / | tail -1 | awk '{print $3}')

## 1. SYSTEM CACHES
echo "📦 System Caches"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CACHE_DIRS=(
    "$HOME/Library/Caches"
    "$HOME/Library/Application Support/Google/Chrome/Default/Cache"
    "$HOME/Library/Application Support/Code/Cache"
    "$HOME/Library/Application Support/Code/CachedData"
    "/Library/Caches"
    "/System/Library/Caches"
)

for dir in "${CACHE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sh "$dir" 2>/dev/null | awk '{print $1}' || echo "0")
        echo "  $dir: $SIZE"
        
        if [ "$DRY_RUN" = "false" ]; then
            # Clean but preserve directory structure
            find "$dir" -type f -mtime +7 -delete 2>/dev/null || true
            echo "    → Cleaned files >7 days old"
        fi
    fi
done
echo ""

## 2. HOMEBREW CLEANUP
echo "🍺 Homebrew Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BREW_CACHE=$(du -sh ~/Library/Caches/Homebrew 2>/dev/null | awk '{print $1}' || echo "0")
echo "  Homebrew cache: $BREW_CACHE"

if [ "$DRY_RUN" = "false" ]; then
    brew cleanup -s 2>/dev/null || true
    brew autoremove 2>/dev/null || true
    echo "    → Cleaned old versions + dependencies"
fi
echo ""

## 3. NODE/NPM CLEANUP
echo "📦 Node/npm Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NPM_CACHE=$(du -sh ~/.npm 2>/dev/null | awk '{print $1}' || echo "0")
echo "  npm cache: $NPM_CACHE"

if [ "$DRY_RUN" = "false" ]; then
    npm cache clean --force 2>/dev/null || true
    echo "    → Cleaned npm cache"
fi
echo ""

## 4. DOCKER CLEANUP
echo "🐳 Docker Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v docker &> /dev/null; then
    echo "  Checking Docker space..."
    docker system df 2>/dev/null || echo "  Docker not running"
    
    if [ "$DRY_RUN" = "false" ]; then
        docker system prune -af --volumes 2>/dev/null || true
        echo "    → Pruned containers, images, volumes"
    fi
else
    echo "  Docker not installed"
fi
echo ""

## 5. TRASH CLEANUP
echo "🗑️  Trash Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TRASH_SIZE=$(du -sh ~/.Trash 2>/dev/null | awk '{print $1}' || echo "0")
echo "  Trash size: $TRASH_SIZE"

if [ "$DRY_RUN" = "false" ]; then
    rm -rf ~/.Trash/* 2>/dev/null || true
    echo "    → Emptied trash"
fi
echo ""

## 6. OLD LOG FILES
echo "📝 Log Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LOG_DIRS=(
    "$HOME/Library/Logs"
    "/var/log"
    "$HOME/.openclaw/workspace/.workers/logs"
)

for dir in "${LOG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        OLD_LOGS=$(find "$dir" -name "*.log" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
        echo "  $dir: $OLD_LOGS files >30 days"
        
        if [ "$DRY_RUN" = "false" ] && [ "$OLD_LOGS" -gt 0 ]; then
            find "$dir" -name "*.log" -mtime +30 -delete 2>/dev/null || true
            echo "    → Deleted old logs"
        fi
    fi
done
echo ""

## 7. DUPLICATE FILES
echo "🔍 Duplicate Files (scanning...)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCAN_DIRS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Documents"
)

for dir in "${SCAN_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  Scanning $dir..."
        DUPES=$(fdupes -r "$dir" 2>/dev/null | grep -c "^$" || echo "0")
        if [ "$DUPES" -gt 0 ]; then
            echo "    Found $DUPES duplicate sets"
            
            if [ "$DRY_RUN" = "false" ]; then
                # Delete duplicates, keep first
                fdupes -rdN "$dir" 2>/dev/null || true
                echo "    → Removed duplicates"
            fi
        else
            echo "    No duplicates found"
        fi
    fi
done
echo ""

## 8. TEMPORARY FILES
echo "🧹 Temporary Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TEMP_DIRS=(
    "/tmp"
    "$HOME/.openclaw/workspace/.workers"
    "$HOME/.openclaw/workspace/.memory-state/snapshots"
)

for dir in "${TEMP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        OLD_TEMP=$(find "$dir" -type f -mtime +7 2>/dev/null | wc -l | tr -d ' ')
        echo "  $dir: $OLD_TEMP files >7 days"
        
        if [ "$DRY_RUN" = "false" ] && [ "$OLD_TEMP" -gt 0 ]; then
            find "$dir" -type f -mtime +7 -delete 2>/dev/null || true
            echo "    → Deleted old temp files"
        fi
    fi
done
echo ""

## 9. ORGANIZE DOWNLOADS
echo "📁 Organize Downloads"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "$HOME/Downloads" ]; then
    echo "  Creating organization structure..."
    
    ORGANIZE_DIRS=(
        "$HOME/Downloads/Archives"
        "$HOME/Downloads/Documents"
        "$HOME/Downloads/Images"
        "$HOME/Downloads/Videos"
        "$HOME/Downloads/Code"
    )
    
    for dir in "${ORGANIZE_DIRS[@]}"; do
        mkdir -p "$dir"
    done
    
    if [ "$DRY_RUN" = "false" ]; then
        cd "$HOME/Downloads"
        
        # Move files by type
        mv *.zip *.tar.gz *.rar *.7z Archives/ 2>/dev/null || true
        mv *.pdf *.doc *.docx *.txt *.xlsx Documents/ 2>/dev/null || true
        mv *.jpg *.jpeg *.png *.gif *.webp Images/ 2>/dev/null || true
        mv *.mp4 *.mov *.avi *.mkv Videos/ 2>/dev/null || true
        mv *.js *.ts *.py *.sh *.json Code/ 2>/dev/null || true
        
        echo "    → Organized by file type"
    else
        echo "    → Would organize: archives, documents, images, videos, code"
    fi
fi
echo ""

## 10. SPACE SUMMARY
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SPACE_AFTER=$(df -k / | tail -1 | awk '{print $3}')
SPACE_FREED=$((SPACE_BEFORE - SPACE_AFTER))
SPACE_FREED_MB=$((SPACE_FREED / 1024))

df -h / | tail -1 | awk '{print "Disk usage: "$3" / "$2" ("$5" used)"}'
echo ""

if [ "$DRY_RUN" = "false" ]; then
    if [ "$SPACE_FREED_MB" -gt 0 ]; then
        echo "✅ Freed: ${SPACE_FREED_MB}MB"
    else
        echo "✅ Cleanup complete (minimal space freed)"
    fi
else
    echo "💡 Run with 'false' to execute cleanup:"
    echo "   bash $0 false"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
