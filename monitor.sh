#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Main Orchestrator Script (monitor.sh)
# Master Monitoring Engine: System -> Network -> Service -> Diagnosis & Recovery -> Report
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"
    REPORT_FILE="${SCRIPT_DIR}/reports/health_report.txt"
    SERVICE_NAME="nginx"
fi

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "$(dirname "$REPORT_FILE")" 2>/dev/null

log_message() {
    local severity="$1"
    local component="$2"
    local msg="$3"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${timestamp} | ${severity} | ${component} | ${msg}" >> "$LOG_FILE"
}

EXEC_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "=================================================================="
echo "          NETPULSE - SYSTEM MONITORING ENGINE                    "
echo "          Execution Time: ${EXEC_TIME}                        "
echo "=================================================================="

SYS_STATUS="PASS"
NET_STATUS="PASS"
SVC_STATUS="PASS"

# -------------------------------------------------------------
# 1. System Health Check
# -------------------------------------------------------------
echo ""
echo "--- [1/3] RUNNING SYSTEM HEALTH CHECK ---"
if bash "${SCRIPT_DIR}/system_check.sh"; then
    SYS_STATUS="PASS"
else
    SYS_STATUS="WARNING"
fi

# -------------------------------------------------------------
# 2. Network & Endpoint Check
# -------------------------------------------------------------
echo ""
echo "--- [2/3] RUNNING NETWORK & ENDPOINT CHECK ---"
if bash "${SCRIPT_DIR}/network_check.sh"; then
    NET_STATUS="PASS"
else
    NET_STATUS="FAIL"
fi

# -------------------------------------------------------------
# 3. Service Check
# -------------------------------------------------------------
echo ""
echo "--- [3/3] RUNNING SERVICE CHECK ---"
if bash "${SCRIPT_DIR}/service_check.sh"; then
    SVC_STATUS="PASS"
else
    SVC_STATUS="FAIL"
fi

# -------------------------------------------------------------
# 4. Diagnosis & Recovery Dispatcher
# -------------------------------------------------------------
if [[ "$SVC_STATUS" == "FAIL" || "$NET_STATUS" == "FAIL" ]]; then
    echo ""
    echo "------------------------------------------------------------------"
    echo "[ALERT] Incident detected in Network or Service level!"
    echo "[ALERT] Initiating Diagnosis & Recovery module..."
    echo "------------------------------------------------------------------"
    
    bash "${SCRIPT_DIR}/recovery.sh" "${SERVICE_NAME}" "Service or port check failed during routine monitor cycle"
    RECOVERY_EXIT_CODE=$?

    if [[ $RECOVERY_EXIT_CODE -eq 0 ]]; then
        OVERALL_HEALTH="RECOVERED"
    else
        OVERALL_HEALTH="DEGRADED / ERROR"
    fi
else
    OVERALL_HEALTH="HEALTHY"
fi

# -------------------------------------------------------------
# 5. Generate Health Report (reports/health_report.txt)
# -------------------------------------------------------------
cat <<EOF > "$REPORT_FILE"
==================================================================
                 NETPULSE SYSTEM HEALTH REPORT                    
==================================================================
Timestamp            : ${EXEC_TIME}
Overall System State : ${OVERALL_HEALTH}
------------------------------------------------------------------
System Resources     : ${SYS_STATUS}
Network & Endpoints  : ${NET_STATUS}
Monitored Service    : ${SVC_STATUS} (${SERVICE_NAME})
------------------------------------------------------------------
Configured Limits:
- CPU Limit          : ${CPU_LIMIT:-90}%
- Memory Limit       : ${MEMORY_LIMIT:-85}%
- Disk Limit         : ${DISK_LIMIT:-80}%
- Target Host/Port   : ${APP_HOST:-127.0.0.1}:${APP_PORT:-8080}
- Target Endpoint    : ${HTTP_ENDPOINT:-http://127.0.0.1:8080}
- Target Service     : ${SERVICE_NAME:-nginx}
------------------------------------------------------------------
Log File Location    : ${LOG_FILE}
==================================================================
EOF

echo ""
echo "=================================================================="
echo "          MONITORING CYCLE COMPLETE                              "
echo "          Health Report generated: ${REPORT_FILE}"
echo "=================================================================="

exit 0
