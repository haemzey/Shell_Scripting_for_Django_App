#!/bin/bash

set -euo pipefail

DOCKER_LOG_DIR="/var/log/docker_logs"
BACKUP_LOG_DIR="/home/hamza/backup_docker_log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$BACKUP_LOG_DIR/backupslogs_$DATE.log"

mkdir -p "$BACKUP_LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d_%H-%M-%S')] $1" | tee -a "$LOG_FILE"
}

backup() {

   if tar -czvf "$BACKUP_LOG_DIR/dockerlogs_$DATE.tar.gz" "$DOCKER_LOG_DIR" > /dev/null; then
   log "backup successsfully done at ${BACKUP_LOG_DIR}"
   return 0

   else
   log "Error: backup fails at ${BACKUP_LOG_DIR}"
   return 1
   fi
}

rotation() {

    mapfile -t rotation < <( find "$BACKUP_LOG_DIR" \
    -maxdepth 1 \
    -type f \
    -name "backupslogs_*.tar.gz" \
    -mtime +1 \
    -printf '%T@ %p\n' |
    sort -rn |
    cut -d' ' -f2-
    )

    log "rotation started"

    for backup_file in "${rotation[@]}"; do
    rm -- "${backup_file}"
    log "old backups are removed ${backup_file}"
    done

    log "rotation completed"
}

cleanup_docker_log_dir() {

    find "$DOCKER_LOG_DIR" -type f -name "docker_compose_*.log" -mtime +1 -delete
    log "Older docker compose logs are deleted"
}

if ! backup; then
echo "backup failed"
exit 1
fi

if ! rotation; then
echo "rotation failed"
exit 1
fi

if ! cleanup_docker_log_dir; then
echo "cleanup_docker_log_dir" 
exit 1
fi 


