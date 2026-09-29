# NetPulse: Linux Network Incident Auto-Responder

> **Product Type:** DevOps / System Monitoring & Automation Tool  
> **Target Audience:** DevOps L1 Engineers, System Administrators, Developers  
> **Environment:** Linux  
> **Version:** 1.0 (MVP Scope)

---

## 🚀 1. Overview

**NetPulse** is a lightweight, Linux-native monitoring and incident auto-response system designed to continuously inspect system resources, network connectivity, services, and HTTP/TCP application endpoints. 

When NetPulse detects a failure, it automatically triggers a 5-step operational workflow:
$$\text{Detect} \longrightarrow \text{Diagnose} \longrightarrow \text{Recover} \longrightarrow \text{Verify} \longrightarrow \text{Log}$$

Instead of relying on heavy third-party agent software, NetPulse leverages standard Linux utilities (`systemctl`, `curl`, `nc`, `ping`, `nslookup`, `df`, `free`, `ps`, `cron`, `bash`) to perform automated first-level triage and recovery.

---

## 🏗️ 2. Architecture & Workflow

```
                    +------------------+
                    |      Cron        |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |    monitor.sh    |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
              v              v              v
       +-----------+   +-----------+   +-----------+
       |  System   |   |  Network  |   |  Service  |
       |   Check   |   |   Check   |   |   Check   |
       +-----+-----+   +-----+-----+   +-----+-----+
             |               |               |
             +---------------+---------------+
                             |
                             v
                    +------------------+
                    |    Diagnosis     |
                    +--------+---------+
                             |
                    +--------+---------+
                    |                  |
                    v                  v
             Recovery Needed       No Recovery
                    |                  |
                    v                  |
             +-------------+           |
             |  Recovery  |           |
             |   Script   |           |
             +------+------+           |
                    |                  |
                    v                  |
             +-------------+           |
             | Verification|           |
             +------+------+           |
                    |                  |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |  Incident Logs   |
                    +------------------+
```

---

## 📁 3. Project Structure

```text
netpulse/
│
├── monitor.sh          # Master orchestrator script
├── system_check.sh     # CPU, Memory, Disk, Uptime, Process monitor
├── network_check.sh    # Ping, DNS, Gateway, TCP Port, HTTP Endpoint monitor
├── service_check.sh    # System service status monitor (systemctl/service)
├── recovery.sh         # Automated diagnosis, service restart & verification engine
├── log_analyzer.sh     # Incident log parsing & summary reporter
├── setup_cron.sh       # Cron job installation and management helper
├── test_runner.sh      # Automated PRD test suite (5 failure scenarios)
│
├── config/
│   └── config.conf     # Centralized threshold & target configuration
│
├── logs/
│   └── incidents.log   # Timestamped incident event log
│
├── reports/
│   └── health_report.txt# Auto-generated system health state summary
│
└── README.md           # Documentation
```

---

## ⚙️ 4. Configuration (`config/config.conf`)

Customize thresholds and target endpoints easily without editing core scripts:

```bash
# General Paths
LOG_FILE="${NETPULSE_DIR}/logs/incidents.log"
REPORT_FILE="${NETPULSE_DIR}/reports/health_report.txt"

# Resource Threshold Limits (%)
CPU_LIMIT=90
MEMORY_LIMIT=85
DISK_LIMIT=80

# Network & Endpoint Settings
PING_HOST="8.8.8.8"
DNS_TEST_HOST="google.com"
APP_HOST="127.0.0.1"
APP_PORT="8080"
HTTP_ENDPOINT="http://127.0.0.1:8080"
HTTP_EXPECTED_CODE="200"

# Service & Auto-Recovery Settings
SERVICE_NAME="nginx"
ENABLE_AUTO_RECOVERY="true"
MAX_RESTART_ATTEMPTS=1
RECOVERY_COOLDOWN=3
```

---

## 🛠️ 5. Quick Start & Execution Guide

### Step 1: Make Scripts Executable
```bash
chmod +x *.sh
```

### Step 2: Run Master Monitoring Cycle
```bash
./monitor.sh
```

Sample CLI Output:
```text
==================================================================
          NETPULSE - SYSTEM MONITORING ENGINE                    
          Execution Time: 2026-09-29 10:15:31                        
==================================================================

--- [1/3] RUNNING SYSTEM HEALTH CHECK ---
=== SYSTEM HEALTH CHECK ===
[INFO] Uptime: up 2 hours, 15 minutes
[INFO] CPU Usage: 12% (Threshold: 90%)
[INFO] Memory Usage: 34% (Threshold: 85%)
[INFO] Disk Usage: 45% (Threshold: 80%)
[INFO] Total Running Processes: 182
=== SYSTEM HEALTH CHECK COMPLETED ===

--- [2/3] RUNNING NETWORK & ENDPOINT CHECK ---
=== NETWORK MONITORING CHECK ===
[INFO] Testing ping connectivity to 8.8.8.8...
[SUCCESS] Ping check to 8.8.8.8 passed.
[INFO] Testing DNS resolution for google.com...
[SUCCESS] DNS resolution for google.com passed.
[INFO] Default Gateway detected: 192.168.1.1
[INFO] Checking TCP Port 8080 on 127.0.0.1...
[SUCCESS] Port 8080 on 127.0.0.1 is reachable.
[INFO] Checking HTTP Endpoint http://127.0.0.1:8080...
[SUCCESS] HTTP Endpoint http://127.0.0.1:8080 returned status code 200.
=== NETWORK MONITORING CHECK COMPLETED ===

--- [3/3] RUNNING SERVICE CHECK ---
=== SERVICE MONITORING CHECK ===
[INFO] Monitoring service: nginx
[SUCCESS] Service 'nginx' is running.

==================================================================
          MONITORING CYCLE COMPLETE                              
          Health Report generated: reports/health_report.txt
==================================================================
```

---

## 📊 6. Log Analyzer (`log_analyzer.sh`)

Parse and analyze timestamped incident logs (`logs/incidents.log`):

```bash
# View Overall Incident Summary
./log_analyzer.sh

# Output:
===== INCIDENT SUMMARY =====

Total incidents : 12
Errors          : 4
Warnings        : 8
Recovered       : 9
Unresolved      : 3
```

### Additional Options:
- `./log_analyzer.sh --errors` : Display all ERROR level entries
- `./log_analyzer.sh --warnings` : Display all WARNING level entries
- `./log_analyzer.sh --actions` : Display recovery actions and success verifications
- `./log_analyzer.sh -n 20` : Show last 20 log entries

---

## ⏰ 7. Automated Scheduling with Cron (`setup_cron.sh`)

Install or manage automatic monitoring execution every 5 minutes:

```bash
# Install cron job (Default: every 5 minutes)
./setup_cron.sh --install

# Check status of installed cron job
./setup_cron.sh --status

# Remove cron job
./setup_cron.sh --remove
```

---

## 🧪 8. Testing Suite (`test_runner.sh`)

Execute the complete PRD Test Plan to verify all 5 failure & recovery scenarios:

```bash
./test_runner.sh
```

**Scenarios Tested:**
1. **Service Failure & Auto-Recovery:** Verifies diagnosis, `systemctl restart`, warm-up cooldown, and verification.
2. **Port & Endpoint Failure:** Verifies detection of unavailable ports/HTTP status codes.
3. **High Disk Usage Warning:** Verifies threshold alert generation.
4. **Network Unreachable:** Verifies ping & DNS failure detection.
5. **Log Analyzer Verification:** Verifies report counts and formatting compliance.

---

## 📝 9. Incident Log Format

Log entries adhere strictly to the standardized NetPulse pipe-delimited format:
```text
YYYY-MM-DD HH:MM:SS | SEVERITY | COMPONENT | MESSAGE
```

**Example Log File (`logs/incidents.log`):**
```text
2026-09-29 10:15:22 | WARNING | PORT | Port 8080 unavailable
2026-09-29 10:15:23 | INFO    | PROCESS | Application process not responding
2026-09-29 10:15:25 | ACTION  | SERVICE | Restarting application
2026-09-29 10:15:31 | SUCCESS | PORT | Port 8080 restored
```

---

## 🌟 10. Future Enhancements (Post-MVP)
- **Web Dashboard:** Real-time web UI showing system status, uptime graphs, and incident history.
- **Email / Slack Notifications:** Webhook notifications for unresolved incident escalation.
- **Docker Monitoring:** Container state and `docker stats` integration.
- **Multi-Node SSH Monitoring:** Remote server health inspection via SSH keys.
