#!/bin/bash
# SASEUL 블록 데이터 복원 및 재시작 스크립트
# 매일 01:00 cron으로 실행
# 사용법: saseul-restore-restart.sh

BACKUP_DIR="/var/saseul-backup"
DATA_DIR="/var/saseul-data"
BACKUP_FILE="${BACKUP_DIR}/saseul-block-backup.tar.gz"
LOG_FILE="/var/log/saseul-reset.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== 복원 및 재시작 시작 =========="

# 백업 파일 존재 확인
if [ ! -f "$BACKUP_FILE" ]; then
    log "백업 파일이 없습니다: ${BACKUP_FILE}"
    log "먼저 saseul-backup.sh를 실행하세요."
    exit 1
fi

# 1. 노드 중지
log "노드 중지 중..."
docker exec saseul-node saseul-script stop 2>/dev/null
sleep 5

# 프로세스가 완전히 종료되었는지 확인
RETRY=0
while docker exec saseul-node saseul-script info 2>/dev/null | grep -q "running"; do
    sleep 2
    RETRY=$((RETRY + 1))
    if [ $RETRY -ge 10 ]; then
        log "정상 종료 실패, 강제 종료 시도..."
        docker exec saseul-node saseul-script kill 2>/dev/null
        sleep 3
        break
    fi
done
log "노드 중지 완료"

# 2. 블록 데이터 삭제 (wallets, env, secrets 보존)
log "기존 블록 데이터 삭제 중..."
for dir in bunch chain_tree main_chain resource_chain status network sync_tree system_contract; do
    rm -rf "${DATA_DIR}/${dir:?}"/*
done
rm -f "${DATA_DIR}/policy"
log "블록 데이터 삭제 완료"

# 3. 백업 데이터 복원
log "백업 데이터 복원 중..."
tar xzf "$BACKUP_FILE" \
    -C "$DATA_DIR" \
    --exclude='wallets' \
    --exclude='env' \
    --exclude='secrets' \
    2>/dev/null

if [ $? -ne 0 ]; then
    log "복원 실패!"
    exit 1
fi
log "백업 데이터 복원 완료"

# 4. 노드 시작
log "노드 시작 중..."
docker exec saseul-node saseul-script start 2>/dev/null

sleep 5

# 5. 시작 확인
if docker exec saseul-node saseul-script info 2>/dev/null | grep -q "running"; then
    BLOCK_INFO=$(docker exec saseul-node saseul-script info 2>/dev/null | grep "Committed")
    log "노드 시작 성공: ${BLOCK_INFO}"
else
    log "노드 시작 실패! 수동 확인 필요"
    exit 1
fi

log "========== 복원 및 재시작 완료 =========="
