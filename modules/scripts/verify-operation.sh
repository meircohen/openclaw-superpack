#!/usr/bin/env bash
# verify-operation.sh - Automatic verification for common operation types
# Usage: verify-operation.sh <type> <args...>

set -euo pipefail

TYPE="${1:-}"
shift || true

verify_background_process() {
    local pid="$1"
    local session_name="${2:-unknown}"
    
    echo "🔍 Verifying background process: pid=$pid, session=$session_name"
    
    # Wait for initialization
    sleep 2
    
    # Check if process exists
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "✅ VERIFIED: Process $pid is running"
        
        # Check if it's actually doing work (recent activity)
        local start_time
        start_time=$(ps -o lstart= -p "$pid" | xargs)
        echo "📊 Started: $start_time"
        
        return 0
    else
        echo "❌ FAILED: Process $pid not found"
        echo "🔍 Checking logs for error..."
        
        # Try to find error in recent logs
        if [ -d "/Users/meircohen/.openclaw/workspace/logs" ]; then
            find /Users/meircohen/.openclaw/workspace/logs -type f -mmin -2 -exec tail -20 {} \; 2>/dev/null | grep -i "error" | head -5 || true
        fi
        
        return 1
    fi
}

verify_file_operation() {
    local operation="$1"  # create, move, delete
    local path="$2"
    local expected_count="${3:-1}"
    
    echo "🔍 Verifying file operation: $operation on $path"
    
    case "$operation" in
        create)
            if [ -e "$path" ]; then
                echo "✅ VERIFIED: File exists at $path"
                ls -lh "$path"
                return 0
            else
                echo "❌ FAILED: File not found at $path"
                return 1
            fi
            ;;
        
        move)
            if [ -e "$path" ]; then
                local count
                count=$(find "$path" -type f 2>/dev/null | wc -l | xargs)
                echo "✅ VERIFIED: Destination $path exists with $count files"
                
                if [ "$count" -ge "$expected_count" ]; then
                    echo "📊 Expected $expected_count files, found $count"
                    
                    # Spot-check: show 3 random files
                    echo "🔍 Spot-check (3 random files):"
                    find "$path" -type f 2>/dev/null | sort -R | head -3 | while read -r file; do
                        echo "  - $(basename "$file")"
                    done
                    return 0
                else
                    echo "⚠️  WARNING: Found $count files, expected at least $expected_count"
                    return 1
                fi
            else
                echo "❌ FAILED: Destination $path not found"
                return 1
            fi
            ;;
        
        delete)
            if [ ! -e "$path" ]; then
                echo "✅ VERIFIED: File deleted at $path"
                return 0
            else
                echo "❌ FAILED: File still exists at $path"
                return 1
            fi
            ;;
        
        *)
            echo "❌ Unknown operation: $operation"
            return 1
            ;;
    esac
}

verify_api_call() {
    local api_name="$1"
    local response_file="$2"
    
    echo "🔍 Verifying API call: $api_name"
    
    if [ ! -f "$response_file" ]; then
        echo "❌ FAILED: Response file not found: $response_file"
        return 1
    fi
    
    # Check for common error indicators
    if grep -qi "error" "$response_file"; then
        echo "❌ FAILED: API returned error"
        grep -i "error" "$response_file" | head -5
        return 1
    fi
    
    if grep -qi "failed" "$response_file"; then
        echo "❌ FAILED: API call failed"
        grep -i "failed" "$response_file" | head -5
        return 1
    fi
    
    # Check for success indicators
    if grep -qi "success\|ok\|completed" "$response_file"; then
        echo "✅ VERIFIED: API call succeeded"
        return 0
    fi
    
    echo "⚠️  UNCLEAR: No clear success/error indicator found"
    echo "📄 Response preview:"
    head -10 "$response_file"
    return 2  # Unclear status
}

verify_database_operation() {
    local db_path="$1"
    local table="$2"
    local expected_count="${3:-1}"
    
    echo "🔍 Verifying database operation: $table in $db_path"
    
    if [ ! -f "$db_path" ]; then
        echo "❌ FAILED: Database not found: $db_path"
        return 1
    fi
    
    local count
    count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
    
    if [ "$count" -ge "$expected_count" ]; then
        echo "✅ VERIFIED: Table $table has $count rows (expected $expected_count)"
        return 0
    else
        echo "❌ FAILED: Table $table has $count rows (expected $expected_count)"
        return 1
    fi
}

# Main dispatcher
case "$TYPE" in
    background|process|exec)
        verify_background_process "$@"
        ;;
    
    file|create|move|delete)
        verify_file_operation "$@"
        ;;
    
    api|http|curl)
        verify_api_call "$@"
        ;;
    
    database|db|sqlite)
        verify_database_operation "$@"
        ;;
    
    *)
        echo "Usage: verify-operation.sh <type> <args...>"
        echo ""
        echo "Types:"
        echo "  background <pid> [session-name]"
        echo "  file <operation> <path> [expected-count]"
        echo "  api <name> <response-file>"
        echo "  database <db-path> <table> [expected-count]"
        exit 1
        ;;
esac
