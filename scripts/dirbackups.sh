#!/bin/bash
set -euo pipefail

# ── Configuration ─────────────────────────────────────
BACKUP_DIRS=("/etc" "/var/www" "/home")
BACKUP_DEST="/var/backups/sysbackup"
KEEP_DAYS=7
LOGFILE="/var/log/backup.log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# ── Functions ─────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" | tee -a "$LOGFILE"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR : $1" >&2
    exit 1
}

cleanup() {
    log "Backup script exiting"
    echo "-------------------------------"
}

create_backup() {
    local dir=$1
    local dirname=$(basename "$dir")
    local backupfile="$BACKUP_DEST/${dirname}_${DATE}.tar.gz"

    if [ ! -d "$dir" ]
    then
        log "SKIP: $dir does not exist"
        return
    fi

    log "Backing up: $dir"

    if tar -czf "$backupfile" "$dir" 2>/dev/null
    then
        local size=$(du -sh "$backupfile" | awk '{print $1}')
        log "SUCCESS: $(basename $backupfile) — Size: $size"
    else
        log "FAILED: Could not backup $dir"
    fi
}

remove_old_backups() {
    log "=== Removing backups older than $KEEP_DAYS days ==="
    local count=$(find "$BACKUP_DEST" -name "*.tar.gz" -mtime +"$KEEP_DAYS" | wc -l)
    find "$BACKUP_DEST" -name "*.tar.gz" -mtime +"$KEEP_DAYS" -delete
    log "Removed $count old backup(s)"
}

# ── Main ──────────────────────────────────────────────
trap cleanup EXIT

mkdir -p "$BACKUP_DEST" || error "Cannot create backup destination: $BACKUP_DEST"

log "=== Backup Started ==="
log "Host        : $(hostname)"
log "Destination : $BACKUP_DEST"
log "Retention   : $KEEP_DAYS days"
echo "" >> "$LOGFILE"

for dir in "${BACKUP_DIRS[@]}"
do
    create_backup "$dir"
done

echo "" >> "$LOGFILE"
remove_old_backups

echo "" >> "$LOGFILE"
log "=== Backup Complete ==="
