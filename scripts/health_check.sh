#!/bin/bash
set -euo pipefail

# ── Configuration ─────────────────────────────────────
REPORT="/var/log/healthreport.txt"
DISK_THRESHOLD=80
MEM_THRESHOLD=80
SERVICES=("httpd" "sshd" "firewalld" "dovecot" "exim")

# ── Functions ─────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" | tee -a "$REPORT"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR : $1" >&2
    exit 1
}

cleanup() {
    echo "-----------------------------------"
    echo "Health check complete."
    echo "Full report saved at: $REPORT"
}

check_disk() {
    log "=== DISK USAGE ==="
    df -h | awk 'NR>1 {print $1, $5}' | while IFS=" " read -r filesystem usage
    do
        percent=${usage%%%}
        if [[ "$percent" =~ ^[0-9]+$ ]] && [ "$percent" -gt "$DISK_THRESHOLD" ]
        then
            log "WARNING: $filesystem is at $usage — above ${DISK_THRESHOLD}% threshold"
        else
            log "OK: $filesystem is at $usage"
        fi
    done
}

check_memory() {
    log "=== MEMORY USAGE ==="
    local total=$(free -m | awk 'NR==2 {print $2}')
    local used=$(free -m | awk 'NR==2 {print $3}')
    local percent=$(( used * 100 / total ))

    if [ "$percent" -gt "$MEM_THRESHOLD" ]
    then
        log "WARNING: Memory usage at ${percent}% — above ${MEM_THRESHOLD}% threshold"
    else
        log "OK: Memory usage at ${percent}%"
    fi
}

check_services() {
    log "=== SERVICE STATUS ==="
    for service in "${SERVICES[@]}"
    do
        if systemctl is-active --quiet "$service"
        then
            log "OK: $service is running"
        else
            log "WARNING: $service is NOT running"
        fi
    done
}

# ── Main ──────────────────────────────────────────────
trap cleanup EXIT

echo "===================================" > "$REPORT"
echo "   SERVER HEALTH REPORT" >> "$REPORT"
echo "===================================" >> "$REPORT"

log "Host   : $(hostname)"
log "Date   : $(date)"
log "Uptime : $(uptime -p)"
echo "" >> "$REPORT"

check_disk
echo "" >> "$REPORT"
check_memory
echo "" >> "$REPORT"
check_services
