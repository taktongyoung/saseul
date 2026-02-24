# SASEUL 노드 업데이트 보고서

**작성일**: 2026-02-24
**서버**: general008 (59.8.221.234:18080)

---

## 1. 업데이트 개요

| 항목 | 이전 | 현재 |
|------|------|------|
| SASEUL 버전 | v2.1.9.6 | **v2.2.0.3** |
| Docker 이미지 빌드 | 2023-07-20 (667MB) | **2026-02-23 (7.62GB)** |
| 이미지 태그 | artifriends/saseul-network:latest | artifriends/saseul-network:latest |

### v2.2.0.3 주요 변경사항 (릴리스 노트 기준)
- 네트워크 트래픽 50~80% 감소
- 내장 GPU 마이너 지원 추가 (v2.2.0.2~)
- CLI 명령어 구조 변경 (`startmining` → `mining start` 등)
- `forcesync` 명령어 제거
- `info` 출력 형식 변경

---

## 2. 업데이트 절차 (실행 순서)

### Step 1: 관련 서비스 중지
```bash
sudo systemctl stop gpu-autominer.service
sudo systemctl stop watchdog.service
sudo systemctl stop saseul-ensure-mining.timer
sudo systemctl stop saseul-ensure-mining.service
sudo systemctl stop saseul-startmining.service
```
- GPU_AutoMiner 프로세스 수동 kill (general008 유저 소유)

### Step 2: 데이터 백업
- `/var/saseul-data/env` → `/var/saseul-data/env.bak` 백업
- 기존 env 설정값 기록:
  - endpoint: `59.8.221.234:18080`
  - owner: `0570f01f9cdd71575eeed1a998f80cce825290e32270`

### Step 3: 컨테이너 교체
```bash
docker stop saseul-node
docker rm saseul-node
docker pull artifriends/saseul-network:latest
```

### Step 4: 새 컨테이너 생성
```bash
docker run -d --init --name saseul-node \
  -p 18080:80 \
  -v /var/saseul-data:/var/saseul/saseul-network/data \
  -v /var/saseul-shared:/shared \
  --restart unless-stopped \
  --entrypoint /bin/saseul-init \
  artifriends/saseul-network:latest
```

**주의**: 가이드 기본 명령어와 다른 점:
- 포트: `80:80` → `18080:80`
- 추가 볼륨: `/var/saseul-shared:/shared` (GPU 마이너 소켓용)
- 재시작 정책: `--restart unless-stopped`

### Step 5: 초기 설정
```bash
# v2.2에서 env 파일 형식이 변경되어 기존 env 제거 후 재설치
rm /var/saseul-data/env
echo -e "59.8.221.234:18080\n0570f01f9cdd71575eeed1a998f80cce825290e32270" | \
  docker exec -i saseul-node saseul-install
```

### Step 6: 노드 시작 및 채굴 활성화
```bash
docker exec saseul-node saseul-script start
docker exec saseul-node saseul-script mining start
docker exec saseul-node saseul-script mining external on
```

### Step 7: 스크립트 수정 및 서비스 재시작
v2.2 호환 스크립트 배포 후 서비스 재시작 (아래 섹션 참조)

---

## 3. v2.2 호환 스크립트 수정사항

### 3-1. saseul-startmining.sh (`/usr/local/bin/`)

| 변경 내용 | 이전 (v2.1) | 이후 (v2.2) |
|-----------|-------------|-------------|
| 채굴 시작 명령 | `saseul-script startmining` | `saseul-script mining start` |
| 성공 메시지 | `"Mining has started successfully"` | `"Mining started"` |

### 3-2. saseul-ensure-mining.sh (`/usr/local/bin/`)

| 변경 내용 | 이전 (v2.1) | 이후 (v2.2) |
|-----------|-------------|-------------|
| 상태 확인 | `saseul-script info` → `mining:` 파싱 | `saseul-script mining check` → `Mining:` 파싱 |
| 채굴 시작 | `saseul-script startmining` | `saseul-script mining start` |
| 정상 판단값 | `"1"` 또는 `"true"` | `"on"` |

### 3-3. Watchdog.sh (`/home/general008/`)

`api_info()` 함수의 `info` 출력 파싱 로직 변경:

| 항목 | 이전 (v2.1) | 이후 (v2.2) |
|------|-------------|-------------|
| Main 높이 | `last_block:` 섹션 → `height:` | `[Main Chain]` 섹션 → `height:` |
| Resource 높이 | `last_resource_block:` 섹션 → `height:` | `[Resource Chain]` 섹션 → `height:` |
| 섹션 종료 감지 | `last_resource_block:`, `[Miners]` | `[` 로 시작하는 다음 섹션 |

### 3-4. F_Sync.sh (`/var/saseul-shared/`)

| 변경 내용 | 이전 (v2.1) | 이후 (v2.2) |
|-----------|-------------|-------------|
| 강제 동기화 | `saseul-script forcesync --peer <host>` | `saseul-script tracker reset` + `tracker add <host>` |
| 채굴 시작 | `saseul-script startmining` | `saseul-script mining start` |
| 동기화 후 대기 | `sleep 2` | `sleep 5` (재시작 후 안정화 시간 확보) |

---

## 4. 현재 상태 (업데이트 직후)

### 노드 상태
| 항목 | 상태 |
|------|------|
| 버전 | v2.2.0.3 |
| 모든 서비스 | running (master, peer_search, block_sync, chaining, consensus) |
| Mining | on |
| External Miner | on |
| 활성 피어 | ~420개 |

### 동기화 진행 (블록 동기화 중)
- 업데이트로 인해 v2.1 → v2.2 데이터 호환 문제로 처음부터 재동기화
- 동기화 속도: Main ~793블록/분, Resource ~2,621블록/분
- 예상 완료: Main 약 70시간, Resource 약 12시간

### GPU 채굴
| 항목 | 상태 |
|------|------|
| GPU_AutoMiner | 실행 중 (PID 활성) |
| GPU 0 | GTX 1660 SUPER - 인식 정상, 메모리 할당됨 |
| GPU 1 | GTX 1660 SUPER - 인식 정상, 메모리 할당됨 |
| gpu_pow.sock | LISTEN 정상 |
| 실제 해시 연산 | 대기 중 (동기화 완료 후 자동 시작) |

### systemd 서비스
| 서비스 | 상태 |
|--------|------|
| gpu-autominer.service | active (running) |
| watchdog.service | active (running) |
| saseul-ensure-mining.timer | active (waiting) |
| saseul-startmining.service | active (exited) |

### 영향 없는 프로세스
| 프로세스 | 상태 |
|----------|------|
| XMRig (Monero 채굴) | 영향 없음, 계속 실행 중 |
| AnyDesk | 영향 없음 |
| nginx | 영향 없음 |

---

## 5. v2.2 CLI 명령어 변경 참조표

| 기능 | v2.1 명령어 | v2.2 명령어 |
|------|-------------|-------------|
| 채굴 시작 | `saseul-script startmining` | `saseul-script mining start` |
| 채굴 중지 | `saseul-script stopmining` | `saseul-script mining stop` |
| 채굴 상태 | `saseul-script info` (mining: 필드) | `saseul-script mining check` |
| 외부 마이너 | 없음 | `saseul-script mining external on/off` |
| GPU 마이너 | 없음 (외부 바이너리) | `saseul-script mining gpu start/stop/check` |
| 강제 동기화 | `saseul-script forcesync --peer <host>` | 제거됨 → `tracker reset` + `restart` |
| 트래커 초기화 | `saseul-script resettracker` | `saseul-script tracker reset` |
| 데이터 초기화 | `saseul-script reset` | `saseul-script data reset` |
| 블록 되감기 | `saseul-script restoreblock` / `rewindblock` | `saseul-script data rewind` |
| 상태 재구축 | `saseul-script rebundling` | `saseul-script data rebuild` |
| 환경 설정 | `saseul-script getenv` / `setenv` / `setendpoint` | `saseul-script env get` / `env endpoint` / `env miner` |
| 노드 정보 | `saseul-script info` | `saseul-script info` (출력 형식 변경) |

---

## 6. 향후 확인 사항

- [ ] 블록 동기화 완료 확인 (예상: 24~48시간)
- [ ] 동기화 완료 후 GPU 채굴 해시레이트 정상 확인
- [ ] Watchdog 정상 동작 확인 (블록 정체 감지 및 복구)
- [ ] success_logs에 새 채굴 성공 기록 생성 확인
- [ ] 구 Docker 이미지 정리: `docker image prune`

---

## 7. 롤백 절차 (필요시)

```bash
# 서비스 중지
sudo systemctl stop gpu-autominer watchdog saseul-ensure-mining.timer

# 컨테이너 교체
docker stop saseul-node && docker rm saseul-node

# 구 이미지로 복원 (이미지 ID: 8eb2391642fc)
docker run -d --init --name saseul-node \
  -p 18080:80 \
  -v /var/saseul-data:/var/saseul/saseul-network/data \
  -v /var/saseul-shared:/shared \
  --restart unless-stopped \
  --entrypoint /bin/saseul-init \
  8eb2391642fc

# env 복원
cp /var/saseul-data/env.bak /var/saseul-data/env

# 스크립트 원본 복원 (백업에서)
# 서비스 재시작
```
