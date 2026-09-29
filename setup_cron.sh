#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Cron Scheduling Utility (setup_cron.sh)
# Manages Linux Cron job installation for automated monitoring execution.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="${SCRIPT_DIR}/monitor.sh"
CRON_COMMENT="# NetPulse Incident Response Engine"

# Default interval in minutes
INTERVAL_MIN=5

show_usage() {
    echo "NetPulse Cron Automation Installer"
    echo "Usage: ./setup_cron.sh [options]"
    echo ""
    echo "Options:"
    echo "  -i, --install [min]   Install NetPulse cron job (default interval: 5 min)"
    echo "  -r, --remove          Remove NetPulse cron job"
    echo "  -s, --status          Check if NetPulse cron job is active"
    echo "  -h, --help            Show this help text"
}

check_crontab() {
    if ! command -v crontab >/dev/null 2>&1; then
        echo "[ERROR] 'crontab' command not found on this system!"
        exit 1
    fi
}

status_cron() {
    check_crontab
    if crontab -l 2>/dev/null | grep -q "monitor.sh"; then
        echo "[STATUS] NetPulse Cron Job is currently ACTIVE:"
        crontab -l | grep "monitor.sh"
    else
        echo "[STATUS] NetPulse Cron Job is NOT installed."
    fi
}

install_cron() {
    check_crontab
    local interval="${1:-$INTERVAL_MIN}"
    local cron_schedule="*/${interval} * * * *"
    local cron_cmd="${cron_schedule} bash \"${MONITOR_SCRIPT}\" > /dev/null 2>&1 ${CRON_COMMENT}"

    # Ensure executable permission on monitor.sh
    chmod +x "${MONITOR_SCRIPT}" 2>/dev/null

    # Remove old entry if existing
    (crontab -l 2>/dev/null | grep -v "monitor.sh" ; echo "$cron_cmd") | crontab -

    echo "[SUCCESS] NetPulse Cron Job installed successfully!"
    echo "Schedule: Every ${interval} minutes (${cron_schedule})"
    echo "Command : bash ${MONITOR_SCRIPT}"
}

remove_cron() {
    check_crontab
    (crontab -l 2>/dev/null | grep -v "monitor.sh") | crontab -
    echo "[SUCCESS] NetPulse Cron Job removed from system."
}

case "$1" in
    -i|--install)
        install_cron "$2"
        ;;
    -r|--remove)
        remove_cron
        ;;
    -s|--status)
        status_cron
        ;;
    -h|--help)
        show_usage
        ;;
    *)
        if [[ $# -eq 0 ]]; then
            install_cron "$INTERVAL_MIN"
        else
            show_usage
        fi
        ;;
esac

exit 0
