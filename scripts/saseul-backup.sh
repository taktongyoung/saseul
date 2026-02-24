#!/bin/bash
# SASEUL 블록 데이터 백업 스크립트
# 사용법: saseul-backup.sh

BACKUP_DIR="/var/saseul-backup"
DATA_DIR="/var/saseul-data"
BACKUP_FILE="${BACKUP_DIR}/saseul-block-backup.tar.gz"
LOG_FILE="/var/log/saseul-reset.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== 백업 시작 =========="

# 노드 상태 확인
NODE_INFO=$(docker exec saseul-node saseul-script info 2>/dev/null | head -5)
log "현재 노드 상태: $(echo "$NODE_INFO" | grep -E 'Committed|Version' | tr '\n' ' ')"

# 기존 백업 보관 (1세대)
if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "${BACKUP_FILE}.old"
    log "기존 백업을 .old로 이동"
fi

# 블록 데이터 백업 (wallets, env, secrets 제외 - 노드 고유 설정)
tar czf "$BACKUP_FILE" \
    -C "$DATA_DIR" \
    --exclude='wallets' \
    --exclude='env' \
    --exclude='secrets' \
    --exclude='log' \
    . 2>/dev/null

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    log "백업 완료: ${BACKUP_FILE} (${BACKUP_SIZE})"
    # 이전 백업 삭제
    rm -f "${BACKUP_FILE}.old"
else
    log "백업 실패!"
    # 실패 시 이전 백업 복원
    if [ -f "${BACKUP_FILE}.old" ]; then
        mv "${BACKUP_FILE}.old" "$BACKUP_FILE"
        log "이전 백업 복원"
    fi
    exit 1
fi

log "========== 백업 완료 =========="
