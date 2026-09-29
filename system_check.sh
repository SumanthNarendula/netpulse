#!/usr/bin/env bash
# ==============================================================================
# NetPulse - System Health Monitor Script (system_check.sh)
# Checks: CPU, Memory, Disk, Uptime, and Core System Processes
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"
    CPU_LIMIT=90
    MEMORY_LIMIT=85
    DISK_LIMIT=80
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "${SCRIPT_DIR}/reports" 2>/dev/null

log_message() {
    local severity="$1"
    local component="$2"
    local msg="$3"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${timestamp} | ${severity} | ${component} | ${msg}" >> "$LOG_FILE"
}

STATUS_OK=0
STATUS_WARNING=0
STATUS_ERROR=0

echo "=== SYSTEM HEALTH CHECK ==="

# -------------------------------------------------------------
# 1. Uptime Check
# -------------------------------------------------------------
if command -v uptime >/dev/null 2>&1; then
    UPTIME_INFO=$(uptime -p 2>/dev/null || uptime)
    echo "[INFO] Uptime: ${UPTIME_INFO}"
    log_message "INFO" "UPTIME" "System uptime: ${UPTIME_INFO}"
else
    echo "[WARNING] 'uptime' command not available"
    log_message "WARNING" "UPTIME" "Command 'uptime' unavailable"
fi

# -------------------------------------------------------------
# 2. CPU Usage Check
# -------------------------------------------------------------
CPU_USAGE=0
if command -v top >/dev/null 2>&1; then
    # Calculate CPU usage from top or /proc/stat
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1 2>/dev/null)
        if [[ -n "$CPU_IDLE" && "$CPU_IDLE" =~ ^[0-9]+$ ]]; then
            CPU_USAGE=$((100 - CPU_IDLE))
        else
            # Alternative fallback using ps
            CPU_USAGE=$(ps -eo %cpu | awk '{s+=$1} END {print int(s)}')
        fi
    else
        CPU_USAGE=$(ps -eo %cpu | awk '{s+=$1} END {print int(s)}')
    fi
else
    CPU_USAGE=0
fi

echo "[INFO] CPU Usage: ${CPU_USAGE}% (Threshold: ${CPU_LIMIT}%)"
if (( CPU_USAGE >= CPU_LIMIT )); then
    echo "[WARNING] High CPU Usage detected: ${CPU_USAGE}% >= ${CPU_LIMIT}%"
    log_message "WARNING" "CPU" "High CPU usage detected: ${CPU_USAGE}% (Limit: ${CPU_LIMIT}%)"
    STATUS_WARNING=$((STATUS_WARNING + 1))
else
    log_message "INFO" "CPU" "CPU usage normal: ${CPU_USAGE}%"
    STATUS_OK=$((STATUS_OK + 1))
fi

# -------------------------------------------------------------
# 3. Memory Usage Check
# -------------------------------------------------------------
MEM_USAGE=0
if command -v free >/dev/null 2>&1; then
    MEM_DATA=$(free -m | awk 'NR==2{printf "%s %s", $2, $3}')
    TOTAL_MEM=$(echo "$MEM_DATA" | awk '{print $1}')
    USED_MEM=$(echo "$MEM_DATA" | awk '{print $2}')
    if [[ -n "$TOTAL_MEM" && "$TOTAL_MEM" -gt 0 ]]; then
        MEM_USAGE=$(( USED_MEM * 100 / TOTAL_MEM ))
    fi
elif [[ -f /proc/meminfo ]]; then
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    FREE_MEM=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    if [[ -n "$TOTAL_MEM" && "$TOTAL_MEM" -gt 0 ]]; then
        USED_MEM=$(( TOTAL_MEM - FREE_MEM ))
        MEM_USAGE=$(( USED_MEM * 100 / TOTAL_MEM ))
    fi
fi

echo "[INFO] Memory Usage: ${MEM_USAGE}% (Threshold: ${MEMORY_LIMIT}%)"
if (( MEM_USAGE >= MEMORY_LIMIT )); then
    echo "[WARNING] High Memory Usage detected: ${MEM_USAGE}% >= ${MEMORY_LIMIT}%"
    log_message "WARNING" "MEMORY" "High memory usage detected: ${MEM_USAGE}% (Limit: ${MEMORY_LIMIT}%)"
    STATUS_WARNING=$((STATUS_WARNING + 1))
else
    log_message "INFO" "MEMORY" "Memory usage normal: ${MEM_USAGE}%"
    STATUS_OK=$((STATUS_OK + 1))
fi

# -------------------------------------------------------------
# 4. Disk Usage Check
# -------------------------------------------------------------
DISK_USAGE=0
if command -v df >/dev/null 2>&1; then
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ -z "$DISK_USAGE" || ! "$DISK_USAGE" =~ ^[0-9]+$ ]]; then
        DISK_USAGE=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')
    fi
fi

echo "[INFO] Disk Usage: ${DISK_USAGE}% (Threshold: ${DISK_LIMIT}%)"
if (( DISK_USAGE >= DISK_LIMIT )); then
    echo "[WARNING] High Disk Usage detected: ${DISK_USAGE}% >= ${DISK_LIMIT}%"
    log_message "WARNING" "DISK" "High disk usage detected: ${DISK_USAGE}% (Limit: ${DISK_LIMIT}%)"
    STATUS_WARNING=$((STATUS_WARNING + 1))
else
    log_message "INFO" "DISK" "Disk usage normal: ${DISK_USAGE}%"
    STATUS_OK=$((STATUS_OK + 1))
fi

# -------------------------------------------------------------
# 5. Process Count Check
# -------------------------------------------------------------
if command -v ps >/dev/null 2>&1; then
    PROC_COUNT=$(ps aux | wc -l)
    echo "[INFO] Total Running Processes: ${PROC_COUNT}"
    log_message "INFO" "PROCESS" "Total active processes: ${PROC_COUNT}"
fi

echo "=== SYSTEM HEALTH CHECK COMPLETED ==="

if (( STATUS_WARNING > 0 )); then
    exit 1
fi
exit 0
