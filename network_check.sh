#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Network Monitoring Script (network_check.sh)
# Checks: Ping, DNS Resolution, Gateway, TCP Port, HTTP/HTTPS Endpoint
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"
    PING_HOST="8.8.8.8"
    DNS_TEST_HOST="google.com"
    APP_HOST="127.0.0.1"
    APP_PORT="8080"
    HTTP_ENDPOINT="http://127.0.0.1:8080"
    HTTP_EXPECTED_CODE="200"
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

FAILURES=0

echo "=== NETWORK MONITORING CHECK ==="

# -------------------------------------------------------------
# 1. Ping Check (Internet / Network Connectivity)
# -------------------------------------------------------------
echo "[INFO] Testing ping connectivity to ${PING_HOST}..."
if command -v ping >/dev/null 2>&1; then
    if ping -c 2 -W 2 "$PING_HOST" >/dev/null 2>&1; then
        echo "[SUCCESS] Ping check to ${PING_HOST} passed."
        log_message "INFO" "PING" "Network ping to ${PING_HOST} successful"
    else
        echo "[ERROR] Ping check to ${PING_HOST} failed!"
        log_message "ERROR" "PING" "Network ping to ${PING_HOST} failed - host unreachable"
        FAILURES=$((FAILURES + 1))
    fi
else
    # Fallback if ping is not available
    echo "[WARNING] 'ping' command not installed"
    log_message "WARNING" "PING" "Command 'ping' unavailable"
fi

# -------------------------------------------------------------
# 2. DNS Resolution Check
# -------------------------------------------------------------
echo "[INFO] Testing DNS resolution for ${DNS_TEST_HOST}..."
DNS_SUCCESS=0
if command -v nslookup >/dev/null 2>&1; then
    if nslookup "$DNS_TEST_HOST" >/dev/null 2>&1; then
        DNS_SUCCESS=1
    fi
elif command -v host >/dev/null 2>&1; then
    if host "$DNS_TEST_HOST" >/dev/null 2>&1; then
        DNS_SUCCESS=1
    fi
elif command -v getent >/dev/null 2>&1; then
    if getent hosts "$DNS_TEST_HOST" >/dev/null 2>&1; then
        DNS_SUCCESS=1
    fi
fi

if [[ $DNS_SUCCESS -eq 1 ]]; then
    echo "[SUCCESS] DNS resolution for ${DNS_TEST_HOST} passed."
    log_message "INFO" "DNS" "DNS resolution for ${DNS_TEST_HOST} successful"
else
    echo "[ERROR] DNS resolution for ${DNS_TEST_HOST} failed!"
    log_message "ERROR" "DNS" "DNS resolution failed for domain ${DNS_TEST_HOST}"
    FAILURES=$((FAILURES + 1))
fi

# -------------------------------------------------------------
# 3. Default Gateway Check
# -------------------------------------------------------------
if command -v ip >/dev/null 2>&1; then
    GATEWAY=$(ip route | grep default | awk '{print $3}' 2>/dev/null | head -n 1)
    if [[ -n "$GATEWAY" ]]; then
        echo "[INFO] Default Gateway detected: ${GATEWAY}"
        log_message "INFO" "NETWORK" "Default gateway accessible: ${GATEWAY}"
    else
        echo "[WARNING] No default gateway found"
        log_message "WARNING" "NETWORK" "No default gateway route detected"
    fi
fi

# -------------------------------------------------------------
# 4. TCP Port Availability Check
# -------------------------------------------------------------
echo "[INFO] Checking TCP Port ${APP_PORT} on ${APP_HOST}..."
PORT_OPEN=0

if command -v nc >/dev/null 2>&1; then
    if nc -z -w 3 "$APP_HOST" "$APP_PORT" >/dev/null 2>&1; then
        PORT_OPEN=1
    fi
elif command -v ss >/dev/null 2>&1; then
    if ss -tulpn | grep -q ":${APP_PORT} "; then
        PORT_OPEN=1
    fi
else
    # Bash built-in TCP check fallback
    if (echo > /dev/tcp/"$APP_HOST"/"$APP_PORT") >/dev/null 2>&1; then
        PORT_OPEN=1
    fi
fi

if [[ $PORT_OPEN -eq 1 ]]; then
    echo "[SUCCESS] Port ${APP_PORT} on ${APP_HOST} is reachable."
    log_message "INFO" "PORT" "Port ${APP_PORT} on ${APP_HOST} is open and responding"
else
    echo "[ERROR] Port ${APP_PORT} on ${APP_HOST} is UNAVAILABLE!"
    log_message "ERROR" "PORT" "Port ${APP_PORT} on ${APP_HOST} unavailable"
    FAILURES=$((FAILURES + 1))
fi

# -------------------------------------------------------------
# 5. HTTP/HTTPS Endpoint Check
# -------------------------------------------------------------
echo "[INFO] Checking HTTP Endpoint ${HTTP_ENDPOINT}..."
if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 "$HTTP_ENDPOINT" 2>/dev/null)
    if [[ "$HTTP_CODE" == "$HTTP_EXPECTED_CODE" || "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
        echo "[SUCCESS] HTTP Endpoint ${HTTP_ENDPOINT} returned status code ${HTTP_CODE}."
        log_message "INFO" "HTTP" "HTTP endpoint ${HTTP_ENDPOINT} returned code ${HTTP_CODE}"
    else
        echo "[ERROR] HTTP Endpoint ${HTTP_ENDPOINT} failed with status code ${HTTP_CODE:-000} (Expected: ${HTTP_EXPECTED_CODE})!"
        log_message "ERROR" "HTTP" "Application endpoint ${HTTP_ENDPOINT} unavailable (HTTP Code: ${HTTP_CODE:-000})"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "[WARNING] 'curl' command not installed"
    log_message "WARNING" "HTTP" "Command 'curl' unavailable for endpoint check"
fi

echo "=== NETWORK MONITORING CHECK COMPLETED ==="

if (( FAILURES > 0 )); then
    exit 1
fi
exit 0
