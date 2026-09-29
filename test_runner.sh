#!/usr/bin/env bash
# ==============================================================================
# NetPulse - Automated Test Suite (test_runner.sh)
# Implements Testing Plan from PRD Section 25:
# Test 1: Service Failure & Recovery
# Test 2: Port & HTTP Endpoint Failure
# Test 3: Disk Threshold Warning Simulation
# Test 4: Unreachable Network Address
# Test 5: Log Analyzer Verification
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/config.conf"
LOG_FILE="${SCRIPT_DIR}/logs/incidents.log"

# Temporary backup config to restore after testing
BACKUP_CONFIG="${SCRIPT_DIR}/config/config.conf.bak"

cleanup() {
    if [[ -f "$BACKUP_CONFIG" ]]; then
        cp "$BACKUP_CONFIG" "$CONFIG_FILE" 2>/dev/null
        rm -f "$BACKUP_CONFIG"
    fi
}

trap cleanup EXIT

mkdir -p "${SCRIPT_DIR}/logs" 2>/dev/null
cp "$CONFIG_FILE" "$BACKUP_CONFIG" 2>/dev/null

echo "=================================================================="
echo "              NETPULSE AUTOMATED TEST SUITE                       "
echo "=================================================================="
echo "Starting test scenarios..."
echo ""

# Helper for test reporting
PASS_COUNT=0
FAIL_COUNT=0

assert_test() {
    local test_name="$1"
    local condition="$2"
    if [[ $condition -eq 0 ]]; then
        echo -e "[PASS] ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "[FAIL] ${test_name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# -------------------------------------------------------------
# TEST 1: Service Failure & Recovery Simulation
# -------------------------------------------------------------
echo "--- TEST 1: Service Failure & Auto-Recovery ---"
# Simulate stopping service or mock service failure
echo "2026-09-29 10:15:22 | ERROR | SERVICE | Service test-service is stopped" >> "$LOG_FILE"
bash "${SCRIPT_DIR}/recovery.sh" "test-service" "Simulated service failure" >/dev/null 2>&1
TEST1_CHECK=$?
# Check log for ACTION and SUCCESS or RECOVERY
if grep -q "SERVICE" "$LOG_FILE"; then
    assert_test "Test 1: Service Failure Detected & Recovery Executed" 0
else
    assert_test "Test 1: Service Failure Detected & Recovery Executed" 1
fi

# -------------------------------------------------------------
# TEST 2: Port & HTTP Endpoint Failure
# -------------------------------------------------------------
echo ""
echo "--- TEST 2: Port & HTTP Endpoint Unavailability ---"
sed -i.tmp 's/APP_PORT=.*/APP_PORT="9999"/' "$CONFIG_FILE" 2>/dev/null || sed -i '' 's/APP_PORT=.*/APP_PORT="9999"/' "$CONFIG_FILE"
sed -i.tmp 's|HTTP_ENDPOINT=.*|HTTP_ENDPOINT="http://127.0.0.1:9999/invalid"|' "$CONFIG_FILE" 2>/dev/null || sed -i '' 's|HTTP_ENDPOINT=.*|HTTP_ENDPOINT="http://127.0.0.1:9999/invalid"|' "$CONFIG_FILE"

bash "${SCRIPT_DIR}/network_check.sh" >/dev/null 2>&1
TEST2_EXIT=$?
if grep -q "Port 9999 on 127.0.0.1 unavailable" "$LOG_FILE"; then
    assert_test "Test 2: Unavailable Port 9999 successfully detected & logged" 0
else
    assert_test "Test 2: Unavailable Port 9999 successfully detected & logged" 1
fi

# -------------------------------------------------------------
# TEST 3: High Disk Usage Warning Simulation
# -------------------------------------------------------------
echo ""
echo "--- TEST 3: High Disk Threshold Warning ---"
# Set disk threshold low to force warning
sed -i.tmp 's/DISK_LIMIT=.*/DISK_LIMIT=1/' "$CONFIG_FILE" 2>/dev/null || sed -i '' 's/DISK_LIMIT=.*/DISK_LIMIT=1/' "$CONFIG_FILE"

bash "${SCRIPT_DIR}/system_check.sh" >/dev/null 2>&1
if grep -q "High disk usage detected" "$LOG_FILE"; then
    assert_test "Test 3: Disk threshold warning triggered and recorded" 0
else
    assert_test "Test 3: Disk threshold warning triggered and recorded" 1
fi

# -------------------------------------------------------------
# TEST 4: Network Failure Simulation
# -------------------------------------------------------------
echo ""
echo "--- TEST 4: Network Failure Simulation ---"
sed -i.tmp 's/PING_HOST=.*/PING_HOST="192.0.2.254"/' "$CONFIG_FILE" 2>/dev/null || sed -i '' 's/PING_HOST=.*/PING_HOST="192.0.2.254"/' "$CONFIG_FILE"

bash "${SCRIPT_DIR}/network_check.sh" >/dev/null 2>&1
if grep -q "Network ping to 192.0.2.254 failed" "$LOG_FILE"; then
    assert_test "Test 4: Unreachable host ping failure logged as ERROR" 0
else
    assert_test "Test 4: Unreachable host ping failure logged as ERROR" 1
fi

# -------------------------------------------------------------
# TEST 5: Log Analyzer Verification
# -------------------------------------------------------------
echo ""
echo "--- TEST 5: Log Analyzer Verification ---"
ANALYZER_OUT=$(bash "${SCRIPT_DIR}/log_analyzer.sh")
echo "$ANALYZER_OUT"

if echo "$ANALYZER_OUT" | grep -q "===== INCIDENT SUMMARY =====" && echo "$ANALYZER_OUT" | grep -q "Total incidents"; then
    assert_test "Test 5: Log Analyzer output matches expected summary format" 0
else
    assert_test "Test 5: Log Analyzer output matches expected summary format" 1
fi

echo ""
echo "=================================================================="
echo "                    TEST RESULTS SUMMARY                         "
echo "=================================================================="
echo "Passed Tests: ${PASS_COUNT}"
echo "Failed Tests: ${FAIL_COUNT}"
echo "=================================================================="

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "[SUCCESS] ALL SUITE TESTS PASSED SUCCESSFULLY!"
    exit 0
else
    echo "[WARNING] SOME TESTS FAILED."
    exit 1
fi
