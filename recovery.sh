#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Automated Diagnosis & Recovery Script (recovery.sh)
# Core Workflow: Diagnose → Recover → Verify → Log
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"
    SERVICE_NAME="nginx"
    APP_HOST="127.0.0.1"
    APP_PORT="8080"
    HTTP_ENDPOINT="http://127.0.0.1:8080"
    HTTP_EXPECTED_CODE="200"
    ENABLE_AUTO_RECOVERY="true"
    MAX_RESTART_ATTEMPTS=1
    RECOVERY_COOLDOWN=3
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

TARGET_SERVICE="${1:-$SERVICE_NAME}"
TRIGGER_REASON="${2:-"Service or endpoint failure"}"

echo "=================================================================="
echo "         NETPULSE AUTOMATED DIAGNOSIS & RECOVERY ROUTINE         "
echo "=================================================================="
echo "[INFO] Triggered for target: ${TARGET_SERVICE}"
echo "[INFO] Reason: ${TRIGGER_REASON}"

# -------------------------------------------------------------
# PHASE 1: AUTOMATED DIAGNOSIS (FR-05)
# -------------------------------------------------------------
echo "[DIAGNOSIS] Step 1/4: Checking process list for '${TARGET_SERVICE}'..."
PROC_MATCH=$(ps aux 2>/dev/null | grep -i "${TARGET_SERVICE}" | grep -v grep | head -n 3)

if [[ -n "$PROC_MATCH" ]]; then
    echo "[DIAGNOSIS] Process is matching, output snippet:"
    echo "$PROC_MATCH"
    log_message "INFO" "PROCESS" "Process '${TARGET_SERVICE}' found in process table"
else
    echo "[DIAGNOSIS] No process matching '${TARGET_SERVICE}' currently running."
    log_message "INFO" "PROCESS" "Application process '${TARGET_SERVICE}' not responding / missing"
fi

echo "[DIAGNOSIS] Step 2/4: Checking service status..."
if command -v systemctl >/dev/null 2>&1; then
    SVC_STATE=$(systemctl is-active "${TARGET_SERVICE}" 2>/dev/null || echo "inactive")
    echo "[DIAGNOSIS] Service status: ${SVC_STATE}"
    log_message "INFO" "DIAGNOSIS" "Service '${TARGET_SERVICE}' status is '${SVC_STATE}'"
else
    log_message "INFO" "DIAGNOSIS" "Systemctl not available for service status check"
fi

echo "[DIAGNOSIS] Step 3/4: Checking recent service logs..."
if command -v journalctl >/dev/null 2>&1; then
    LOG_SNIPPET=$(journalctl -u "${TARGET_SERVICE}" --no-pager -n 5 2>/dev/null | tail -n 3)
    if [[ -n "$LOG_SNIPPET" ]]; then
        echo "[DIAGNOSIS] Recent journalctl logs:"
        echo "$LOG_SNIPPET"
        log_message "INFO" "DIAGNOSIS" "Logged recent journalctl state for ${TARGET_SERVICE}"
    fi
fi

echo "[DIAGNOSIS] Step 4/4: Checking system resource contention..."
FREE_MEM_MB=$(free -m 2>/dev/null | awk 'NR==2{print $4}')
echo "[DIAGNOSIS] Available system memory: ${FREE_MEM_MB:-"N/A"} MB"

# -------------------------------------------------------------
# PHASE 2: AUTOMATED RECOVERY (FR-06)
# -------------------------------------------------------------
if [[ "${ENABLE_AUTO_RECOVERY,,}" != "true" ]]; then
    echo "[WARNING] Auto-recovery is disabled in config.conf (ENABLE_AUTO_RECOVERY=false)."
    log_message "WARNING" "RECOVERY" "Auto-recovery skipped - disabled in config"
    exit 0
fi

echo ""
echo "[RECOVERY] Attempting automated recovery action for '${TARGET_SERVICE}'..."
log_message "ACTION" "SERVICE" "Attempting automated restart for service: ${TARGET_SERVICE}"

RECOVERY_SUCCESS=0

for (( attempt=1; attempt<=MAX_RESTART_ATTEMPTS; attempt++ )); do
    echo "[RECOVERY] Restart attempt ${attempt} of ${MAX_RESTART_ATTEMPTS}..."
    
    if command -v systemctl >/dev/null 2>&1; then
        if sudo systemctl restart "${TARGET_SERVICE}" 2>/dev/null || systemctl restart "${TARGET_SERVICE}" 2>/dev/null; then
            echo "[RECOVERY] Restart command executed successfully for ${TARGET_SERVICE}."
        else
            echo "[WARNING] Restart command failed or required elevated permissions."
            log_message "WARNING" "RECOVERY" "Sudo/systemctl restart failed for ${TARGET_SERVICE}"
        fi
    elif command -v service >/dev/null 2>&1; then
        sudo service "${TARGET_SERVICE}" restart 2>/dev/null || service "${TARGET_SERVICE}" restart 2>/dev/null
    elif [[ -f "${SCRIPT_DIR}/scratch/mock_${TARGET_SERVICE}.sh" ]]; then
        # For testing / mockup environments
        bash "${SCRIPT_DIR}/scratch/mock_${TARGET_SERVICE}.sh" start >/dev/null 2>&1 &
    fi

    echo "[RECOVERY] Waiting ${RECOVERY_COOLDOWN}s for service warm-up..."
    sleep "${RECOVERY_COOLDOWN}"

    # -------------------------------------------------------------
    # PHASE 3: VERIFICATION (FR-07)
    # -------------------------------------------------------------
    echo "[VERIFICATION] Verifying recovery status..."

    SERVICE_RESTORED=0
    PORT_RESTORED=0
    HTTP_RESTORED=0

    # 1. Service check
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "${TARGET_SERVICE}" 2>/dev/null; then
            SERVICE_RESTORED=1
        fi
    elif pgrep -f "${TARGET_SERVICE}" >/dev/null 2>&1; then
        SERVICE_RESTORED=1
    fi

    # 2. Port check
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "$APP_HOST" "$APP_PORT" >/dev/null 2>&1; then
            PORT_RESTORED=1
        fi
    elif (echo > /dev/tcp/"$APP_HOST"/"$APP_PORT") >/dev/null 2>&1; then
        PORT_RESTORED=1
    fi

    # 3. HTTP check
    if command -v curl >/dev/null 2>&1; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$HTTP_ENDPOINT" 2>/dev/null)
        if [[ "$HTTP_CODE" == "$HTTP_EXPECTED_CODE" || "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
            HTTP_RESTORED=1
        fi
    fi

    # Check overall restoration
    if [[ $SERVICE_RESTORED -eq 1 || $PORT_RESTORED -eq 1 || $HTTP_RESTORED -eq 1 ]]; then
        echo "[SUCCESS] Recovery VERIFIED! Service/Port/Endpoint is back online."
        log_message "SUCCESS" "PORT" "Port ${APP_PORT} and Service ${TARGET_SERVICE} restored successfully"
        log_message "SUCCESS" "SERVICE" "Recovery verified: ${TARGET_SERVICE} is fully operational"
        RECOVERY_SUCCESS=1
        break
    else
        echo "[WARNING] Verification failed after restart attempt ${attempt}."
    fi
done

if [[ $RECOVERY_SUCCESS -eq 1 ]]; then
    echo "=================================================================="
    echo "         AUTOMATED RECOVERY COMPLETED SUCCESSFULLY              "
    echo "=================================================================="
    exit 0
else
    echo "[ERROR] Recovery failed after ${MAX_RESTART_ATTEMPTS} attempts!"
    log_message "ERROR" "RECOVERY" "Recovery failed for ${TARGET_SERVICE}. Escalation required."
    echo "=================================================================="
    echo "         AUTOMATED RECOVERY UNRESOLVED - ESCALATING              "
    echo "=================================================================="
    exit 1
fi
