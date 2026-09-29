#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Log Analysis Script (log_analyzer.sh)
# Parses and analyzes incident logs, generating summaries and filtered reports.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"
fi

show_help() {
    echo "NetPulse Log Analyzer Utility"
    echo "Usage: ./log_analyzer.sh [options]"
    echo ""
    echo "Options:"
    echo "  -s, --summary     Display overall incident summary (default)"
    echo "  -e, --errors      Display only ERROR level log entries"
    echo "  -w, --warnings    Display only WARNING level log entries"
    echo "  -a, --actions     Display ACTION and RECOVERY log entries"
    echo "  -n <number>       Display the last <number> log entries"
    echo "  -f <file>         Specify custom log file path"
    echo "  -h, --help        Show this help message"
}

FILTER_MODE="summary"
TAIL_COUNT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--summary)
            FILTER_MODE="summary"
            shift
            ;;
        -e|--errors)
            FILTER_MODE="errors"
            shift
            ;;
        -w|--warnings)
            FILTER_MODE="warnings"
            shift
            ;;
        -a|--actions)
            FILTER_MODE="actions"
            shift
            ;;
        -n)
            TAIL_COUNT="$2"
            shift 2
            ;;
        -f)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ ! -f "$LOG_FILE" ]]; then
    echo "[ERROR] Log file missing or unreachable at: ${LOG_FILE}"
    echo "===== INCIDENT SUMMARY ====="
    echo ""
    echo "Total incidents : 0"
    echo "Errors          : 0"
    echo "Warnings        : 0"
    echo "Recovered       : 0"
    echo "Unresolved      : 0"
    exit 1
fi

case "$FILTER_MODE" in
    "errors")
        echo "===== ERROR INCIDENTS ====="
        grep -i " ERROR " "$LOG_FILE"
        exit 0
        ;;
    "warnings")
        echo "===== WARNING INCIDENTS ====="
        grep -i " WARNING " "$LOG_FILE"
        exit 0
        ;;
    "actions")
        echo "===== RECOVERY & ACTION LOGS ====="
        grep -E -i " ACTION | SUCCESS | RECOVERY " "$LOG_FILE"
        exit 0
        ;;
    "summary"|*)
        if [[ -n "$TAIL_COUNT" ]]; then
            echo "===== LAST ${TAIL_COUNT} INCIDENT LOGS ====="
            tail -n "$TAIL_COUNT" "$LOG_FILE"
            echo ""
        fi

        TOTAL_INCIDENTS=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
        ERRORS_COUNT=$(grep -c " ERROR " "$LOG_FILE" 2>/dev/null || echo 0)
        WARNINGS_COUNT=$(grep -c " WARNING " "$LOG_FILE" 2>/dev/null || echo 0)
        RECOVERED_COUNT=$(grep -c " SUCCESS " "$LOG_FILE" 2>/dev/null || echo 0)
        
        # Unresolved errors = Errors minus Successful recoveries (min 0)
        UNRESOLVED_COUNT=$(( ERRORS_COUNT - RECOVERED_COUNT ))
        if (( UNRESOLVED_COUNT < 0 )); then
            UNRESOLVED_COUNT=0
        fi

        echo "===== INCIDENT SUMMARY ====="
        echo ""
        printf "%-16s: %d\n" "Total incidents" "$TOTAL_INCIDENTS"
        printf "%-16s: %d\n" "Errors" "$ERRORS_COUNT"
        printf "%-16s: %d\n" "Warnings" "$WARNINGS_COUNT"
        printf "%-16s: %d\n" "Recovered" "$RECOVERED_COUNT"
        printf "%-16s: %d\n" "Unresolved" "$UNRESOLVED_COUNT"
        echo ""
        ;;
esac

exit 0
