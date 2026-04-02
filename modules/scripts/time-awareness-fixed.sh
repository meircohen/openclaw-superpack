#!/bin/bash
# Time Awareness System v2 - jq-based parsing

get_meir_state() {
    echo '{"shabbos_start":"2026-03-07T18:06:00-05:00","shabbos_end":"2026-03-08T19:14:00-05:00","availability":"normal","quiet_hours":false}'
}

is_shabbos() {
    local state=$(get_meir_state)
    local now=$(date +%s)
    local start=$(echo "$state" | jq -r '.shabbos_start' | xargs -I{} date -jf "%Y-%m-%dT%H:%M:%S%z" "{}" +%s 2>/dev/null || echo 0)
    local end=$(echo "$state" | jq -r '.shabbos_end' | xargs -I{} date -jf "%Y-%m-%dT%H:%M:%S%z" "{}" +%s 2>/dev/null || echo 0)
    
    if [[ $now -ge $start && $now -lt $end ]]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

check_quiet_hours() {
    local hour=$(date +%H)
    if [[ $hour -ge 1 && $hour -lt 8 ]]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

should_notify() {
    local priority=${1:-normal}
    
    if [[ $(is_shabbos) == "true" ]]; then
        [[ "$priority" == "critical" ]] && echo "proceed" || echo "skip"
        return
    fi
    
    if [[ $(check_quiet_hours) == "true" ]]; then
        [[ "$priority" == "urgent" || "$priority" == "critical" ]] && echo "proceed" || echo "skip"
        return
    fi
    
    echo "proceed"
}

case "$1" in
    is-shabbos) is_shabbos ;;
    quiet-hours) check_quiet_hours ;;
    should-notify) should_notify "$2" ;;
    *) echo "Usage: $0 {is-shabbos|quiet-hours|should-notify [normal|urgent|critical]}" ;;
esac
