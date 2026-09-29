#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Service Monitoring Script (service_check.sh)
# Checks: Configured System Service Status (e.g. nginx, mysql, docker)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"
    SERVICE_NAME="nginx"
fi

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log_message() {
    local severity="$1"
    local component="$2"
    local msg="$3"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${timestamp} | ${severity} | ${component} | ${msg}" >> "$LOG_FILE"
}

echo "=== SERVICE MONITORING CHECK ==="
echo "[INFO] Monitoring service: ${SERVICE_NAME}"

SERVICE_STATUS="unknown"
SERVICE_EXISTS=0

# -------------------------------------------------------------
# Check using systemctl, service, or pgrep
# -------------------------------------------------------------
if command -v systemctl >/dev/null 2>&1; then
    # Verify if service unit exists
    if systemctl list-unit-files "${SERVICE_NAME}*" 2>/dev/null | grep -q "${SERVICE_NAME}"; then
        SERVICE_EXISTS=1
    elif systemctl status "${SERVICE_NAME}" >/dev/null 2>&1; then
        SERVICE_EXISTS=1
    fi

    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        SERVICE_STATUS="active"
    else
        if [[ $SERVICE_EXISTS -eq 1 ]]; then
            SERVICE_STATUS="inactive"
        else
            SERVICE_STATUS="not_found"
        fi
    fi
elif command -v service >/dev/null 2>&1; then
    if service "${SERVICE_NAME}" status >/dev/null 2>&1; then
        SERVICE_STATUS="active"
    else
        SERVICE_STATUS="inactive"
    fi
else
    # Fallback to process search
    if pgrep -f "${SERVICE_NAME}" >/dev/null 2>&1; then
        SERVICE_STATUS="active"
    else
        SERVICE_STATUS="inactive"
    fi
fi

# -------------------------------------------------------------
# Evaluate Status and Log Incident
# -------------------------------------------------------------
case "$SERVICE_STATUS" in
    "active")
        echo "[SUCCESS] Service '${SERVICE_NAME}' is running."
        log_message "INFO" "SERVICE" "Service ${SERVICE_NAME} is active and running"
        exit 0
        ;;
    "not_found")
        echo "[ERROR] Service '${SERVICE_NAME}' not found on system!"
        log_message "ERROR" "SERVICE" "${SERVICE_NAME} service not found"
        exit 2
        ;;
    "inactive"|*)
        echo "[ERROR] Service '${SERVICE_NAME}' is STOPPED or INACTIVE!"
        log_message "ERROR" "SERVICE" "Service ${SERVICE_NAME} is stopped"
        exit 1
        ;;
esac
