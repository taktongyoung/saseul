# SASEUL Node 자동 백업 및 복원 시스템

SASEUL 블록체인 노드의 블록 데이터를 자동으로 백업하고, 매일 지정된 시간에 초기화 후 백업 데이터로 복원하여 빠르게 재시작하는 자동화 스크립트입니다.

## 개요

SASEUL 노드를 운영하다 보면 블록 데이터가 커지거나 동기화 문제가 발생할 수 있습니다. 이 시스템은 정상 상태의 블록 데이터를 백업해두고, 매일 새벽 1시에 자동으로 블록을 초기화한 뒤 백업본에서 복원하여 **처음부터 동기화하지 않고** 즉시 운영을 재개할 수 있도록 합니다.

## 시스템 구성

```
┌─────────────────────────────────────────────────────┐
│                    Host Server                       │
│                                                      │
│  /var/saseul-data/          (블록 데이터 - 볼륨 마운트) │
│  /var/saseul-backup/        (백업 저장소)              │
│  /usr/local/bin/saseul-*.sh (자동화 스크립트)          │
│  /var/log/saseul-reset.log  (실행 로그)               │
│                                                      │
│  ┌────────────────────────────────────────┐          │
│  │  Docker Container: saseul-node         │          │
│  │  Image: artifriends/saseul-network     │          │
│  │  Port: 0.0.0.0:80 -> 80/tcp           │          │
│  │                                        │          │
│  │  /var/saseul/saseul-network/data/      │          │
│  │    ├── bunch/          (블록 번들)      │          │
│  │    ├── chain_tree/     (체인 트리)      │          │
│  │    ├── main_chain/     (메인 체인)      │          │
│  │    ├── resource_chain/ (리소스 체인)    │          │
│  │    ├── status/         (상태 DB)        │          │
│  │    ├── network/        (네트워크 정보)  │          │
│  │    ├── sync_tree/      (동기화 트리)    │          │
│  │    ├── system_contract/(시스템 컨트랙트)│          │
│  │    ├── wallets/        (지갑 - 보존)    │          │
│  │    ├── env             (환경설정 - 보존)│          │
│  │    └── secrets         (비밀키 - 보존)  │          │
│  └────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────┘
```

## 구동 원리

### 백업 (saseul-backup.sh)

1. 현재 노드의 블록 데이터 디렉토리(`/var/saseul-data/`)를 tar.gz로 압축
2. 지갑(`wallets/`), 환경설정(`env`), 비밀키(`secrets`), 로그(`log/`)는 백업에서 제외 (노드 고유 데이터)
3. 기존 백업이 있으면 `.old`로 보관 후 새 백업 생성, 성공 시 `.old` 삭제
4. 백업 실패 시 `.old` 파일을 원래 이름으로 복원 (안전장치)

### 복원 및 재시작 (saseul-restore-restart.sh)

1. **노드 중지**: `saseul-script stop` 명령으로 안전하게 종료. 20초 내 종료되지 않으면 `saseul-script kill`로 강제 종료
2. **블록 데이터 삭제**: `bunch`, `chain_tree`, `main_chain`, `resource_chain`, `status`, `network`, `sync_tree`, `system_contract` 디렉토리 내용 삭제. `wallets`, `env`, `secrets`는 보존
3. **백업 복원**: tar.gz 파일을 데이터 디렉토리에 압축 해제
4. **노드 시작**: `saseul-script start`로 재시작
5. **상태 확인**: 노드가 정상적으로 `running` 상태인지 검증

### 데이터 흐름

```
[백업 시점]                    [복원 시점 - 매일 01:00]

노드 실행 중                    노드 중지
     │                              │
     ▼                              ▼
블록 데이터 ──tar.gz──▶ 백업파일 ──tar.xz──▶ 블록 데이터 복원
(17GB)                 (/var/saseul-backup/)       │
                                                    ▼
                                              노드 재시작
                                                    │
                                                    ▼
                                         백업 시점부터 이어서 동기화
                                         (처음부터 쌓지 않음)
```

## 파일 구성

```
saseul-project/
├── README.md                          # 이 문서
├── scripts/
│   ├── saseul-backup.sh               # 블록 데이터 백업 스크립트
│   └── saseul-restore-restart.sh      # 블록 데이터 복원 및 재시작 스크립트
└── cron/
    └── saseul-cron                    # crontab 설정 파일
```

## 설치 방법

### 사전 요구사항

- Docker가 설치되어 있어야 합니다
- SASEUL 노드 컨테이너(`saseul-node`)가 실행 중이어야 합니다
- root 권한이 필요합니다

### 1. 저장소 클론

```bash
git clone https://github.com/taktongyoung/saseul.git
cd saseul
```

### 2. 스크립트 설치

```bash
# 스크립트 복사
cp scripts/saseul-backup.sh /usr/local/bin/
cp scripts/saseul-restore-restart.sh /usr/local/bin/

# 실행 권한 부여
chmod +x /usr/local/bin/saseul-backup.sh
chmod +x /usr/local/bin/saseul-restore-restart.sh

# 백업 디렉토리 생성
mkdir -p /var/saseul-backup
```

### 3. 초기 백업 생성

```bash
# 현재 정상 동작 중인 노드의 블록 데이터를 백업
saseul-backup.sh
```

### 4. Cron 등록 (매일 01:00 자동 실행)

```bash
# 방법 A: crontab 직접 편집
crontab -e
# 아래 줄 추가:
0 1 * * * /usr/local/bin/saseul-restore-restart.sh >> /var/log/saseul-reset.log 2>&1

# 방법 B: cron 파일 복사
cp cron/saseul-cron /etc/cron.d/
chmod 644 /etc/cron.d/saseul-cron
```

## 명령어 사용법

### 백업 스크립트

```bash
# 현재 블록 데이터를 백업
saseul-backup.sh

# 출력 예시:
# [2026-02-24 15:30:00] ========== 백업 시작 ==========
# [2026-02-24 15:30:01] 현재 노드 상태: Version: 2.2.0.2 Committed: resource=2015464, main=3363313
# [2026-02-24 15:32:15] 백업 완료: /var/saseul-backup/saseul-block-backup.tar.gz (5.2G)
# [2026-02-24 15:32:15] ========== 백업 완료 ==========
```

### 복원 및 재시작 스크립트

```bash
# 블록 초기화 후 백업에서 복원하여 재시작
saseul-restore-restart.sh

# 출력 예시:
# [2026-02-25 01:00:00] ========== 복원 및 재시작 시작 ==========
# [2026-02-25 01:00:00] 노드 중지 중...
# [2026-02-25 01:00:05] 노드 중지 완료
# [2026-02-25 01:00:05] 기존 블록 데이터 삭제 중...
# [2026-02-25 01:00:06] 블록 데이터 삭제 완료
# [2026-02-25 01:00:06] 백업 데이터 복원 중...
# [2026-02-25 01:02:30] 백업 데이터 복원 완료
# [2026-02-25 01:02:35] 노드 시작 중...
# [2026-02-25 01:02:40] 노드 시작 성공: Committed: resource=2015464, main=3363313
# [2026-02-25 01:02:40] ========== 복원 및 재시작 완료 ==========
```

### SASEUL 노드 관리 명령어 (참고)

```bash
# 노드 상태 확인
docker exec saseul-node saseul-script info

# 노드 시작 / 중지 / 재시작
docker exec saseul-node saseul-script start
docker exec saseul-node saseul-script stop
docker exec saseul-node saseul-script restart

# 노드 강제 종료
docker exec saseul-node saseul-script kill

# 블록 데이터 관리
docker exec saseul-node saseul-script data check      # 데이터 일관성 검사
docker exec saseul-node saseul-script data rebuild     # 상태 DB 재구축
docker exec saseul-node saseul-script data reset --all # 전체 초기화
docker exec saseul-node saseul-script data rewind      # 특정 높이로 되감기

# 로그 확인
docker exec saseul-node saseul-script log -f           # 실시간 로그
docker exec saseul-node saseul-script log -m -f        # 마이닝 로그

# 복원 실행 로그 확인
tail -f /var/log/saseul-reset.log
```

## 보존되는 데이터 (초기화 시 삭제되지 않음)

| 파일/디렉토리 | 설명 |
|---|---|
| `wallets/` | 지갑 데이터 (wallet.dat, metadata) |
| `env` | 노드 환경설정 (노드 고유 식별 정보) |
| `secrets` | 노드 비밀키 |

## 삭제 후 복원되는 데이터

| 디렉토리 | 설명 |
|---|---|
| `bunch/` | 블록 번들 데이터 |
| `chain_tree/` | 체인 트리 구조 |
| `main_chain/` | 메인 체인 블록 데이터 |
| `resource_chain/` | 리소스 체인 데이터 |
| `status/` | 상태 데이터베이스 |
| `network/` | 네트워크 피어 정보 |
| `sync_tree/` | 동기화 트리 데이터 |
| `system_contract/` | 시스템 컨트랙트 데이터 |

## 로그 확인

모든 실행 로그는 `/var/log/saseul-reset.log`에 기록됩니다.

```bash
# 전체 로그 확인
cat /var/log/saseul-reset.log

# 실시간 로그 모니터링
tail -f /var/log/saseul-reset.log

# 최근 실행 결과만 확인
tail -20 /var/log/saseul-reset.log
```

## 문제 해결

### 백업 파일이 없다는 오류

```
백업 파일이 없습니다: /var/saseul-backup/saseul-block-backup.tar.gz
```

`saseul-backup.sh`를 먼저 실행하여 초기 백업을 생성하세요.

### 노드 시작 실패

```
노드 시작 실패! 수동 확인 필요
```

1. 컨테이너 상태 확인: `docker ps -a | grep saseul`
2. 컨테이너 로그 확인: `docker logs saseul-node --tail 50`
3. 데이터 일관성 검사: `docker exec saseul-node saseul-script data check`
4. 필요 시 상태 DB 재구축: `docker exec saseul-node saseul-script data rebuild`

### 백업을 최신으로 갱신하고 싶을 때

노드가 정상 운영 중인 상태에서 수동으로 백업을 실행합니다:

```bash
saseul-backup.sh
```

## 환경 정보

- **SASEUL Version**: v2.2.0.2
- **Docker Image**: artifriends/saseul-network:latest
- **Container Name**: saseul-node
- **Host Data Path**: /var/saseul-data
- **Container Data Path**: /var/saseul/saseul-network/data
- **Port Mapping**: 0.0.0.0:80 -> 80/tcp
