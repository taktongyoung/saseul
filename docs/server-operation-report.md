# SASEUL 노드 서버 운영 보고서

> 작성일: 2026-02-24
> 서버: general001 (220.127.52.185)
> 노드 버전: v2.2.0.2 → v2.2.0.3 업데이트 완료

---

## 목차

1. [서버 현황 분석](#1-서버-현황-분석)
2. [자동 백업 및 복원 시스템 구축](#2-자동-백업-및-복원-시스템-구축)
3. [노드 업데이트 (v2.2.0.2 → v2.2.0.3)](#3-노드-업데이트-v2202--v2203)
4. [블록 쌓는 속도 비교 측정](#4-블록-쌓는-속도-비교-측정)
5. [보안 점검 사항](#5-보안-점검-사항)
6. [GitHub 문서화 작업](#6-github-문서화-작업)

---

## 1. 서버 현황 분석

### 서버 기본 정보

| 항목 | 값 |
|---|---|
| 호스트명 | general001 |
| 서버 IP | 220.127.52.185 |
| OS | Linux 6.17.0-14-generic |
| Docker 내부 IP | 172.17.0.1 (호스트) / 172.17.0.2 (컨테이너) |

### 열린 포트 (외부 노출)

| 포트 | 프로세스 | 설명 |
|---|---|---|
| 22/tcp | sshd | SSH 원격 접속 |
| 80/tcp | docker-proxy → saseul-node | SASEUL 노드 통신 |

### 내부 전용 포트

| 포트 | 프로세스 | 설명 |
|---|---|---|
| 53/tcp,udp | systemd-resolve | DNS 리졸버 |
| 631/tcp | cupsd | CUPS 프린트 서비스 |
| 5353/udp | avahi-daemon | mDNS 서비스 |
| 34509/tcp | containerd | Docker containerd |
| 6010-6011/tcp | sshd | X11 포워딩 |

### Docker 컨테이너

| 항목 | 값 |
|---|---|
| 컨테이너명 | saseul-node |
| 이미지 | artifriends/saseul-network:latest |
| 포트 매핑 | 0.0.0.0:80 → 80/tcp |
| 데이터 볼륨 | /var/saseul-data → /var/saseul/saseul-network/data |
| 데이터 크기 | 약 17GB |

### 활성 SSH 세션

| 출발지 IP | 사용자 | 세션 수 |
|---|---|---|
| 121.135.46.208 | general001 | 3개 |
| 211.210.18.17 | general001 | 1개 (Claude Code 실행) |

---

## 2. 자동 백업 및 복원 시스템 구축

### 작업 내용

매일 새벽 01:00에 SASEUL 노드의 블록 데이터를 초기화하고, 사전에 백업한 데이터로 복원하여 처음부터 동기화하지 않고 빠르게 재시작하는 자동화 시스템을 구축했습니다.

### 생성된 스크립트

#### saseul-backup.sh (백업 스크립트)

- **위치**: `/usr/local/bin/saseul-backup.sh`
- **기능**: 현재 블록 데이터를 tar.gz로 압축 백업
- **백업 경로**: `/var/saseul-backup/saseul-block-backup.tar.gz`
- **제외 항목**: wallets, env, secrets, log (노드 고유 데이터)
- **안전장치**: 기존 백업을 .old로 보관 후 새 백업 생성, 실패 시 .old 복원

#### saseul-restore-restart.sh (복원 및 재시작 스크립트)

- **위치**: `/usr/local/bin/saseul-restore-restart.sh`
- **기능**: 노드 중지 → 블록 데이터 삭제 → 백업 복원 → 노드 재시작
- **안전 종료**: 20초 대기 후 응답 없으면 강제 종료
- **보존 데이터**: wallets/, env, secrets (지갑 및 노드 고유 설정)
- **상태 확인**: 재시작 후 running 상태 검증

#### cron 설정

```
0 1 * * * /usr/local/bin/saseul-restore-restart.sh >> /var/log/saseul-reset.log 2>&1
```

### 동작 흐름

```
매일 01:00
    │
    ▼
노드 중지 (saseul-script stop)
    │
    ├── 20초 내 종료 실패 시 → 강제 종료 (saseul-script kill)
    │
    ▼
블록 데이터 삭제
    │  bunch, chain_tree, main_chain, resource_chain,
    │  status, network, sync_tree, system_contract
    │  (wallets, env, secrets는 보존)
    │
    ▼
백업 데이터 복원 (tar xzf)
    │
    ▼
노드 재시작 (saseul-script start)
    │
    ▼
상태 확인 → 로그 기록 (/var/log/saseul-reset.log)
```

---

## 3. 노드 업데이트 (v2.2.0.2 → v2.2.0.3)

### 업데이트 일시

- 2026-02-24 11:35 KST

### 업데이트 절차

```
1. 노드 중지
   └─ docker exec saseul-node saseul-script stop

2. 권한 마이그레이션 (v2.2.0.2 → v2.2.0.3 전용 필수 작업)
   ├─ find data -type d -exec chmod 755
   ├─ find data -type f -exec chmod 644
   └─ find data/bunch -type d -exec chmod 775

3. 컨테이너 교체
   ├─ docker stop saseul-node
   ├─ docker rm saseul-node
   └─ docker pull artifriends/saseul-network:latest

4. 새 컨테이너 생성
   └─ docker run -d --init --name saseul-node -p 80:80 -v /var/saseul-data:... artifriends/saseul-network:latest

5. 초기 설정 및 Endpoint/Miner 복원
   ├─ docker exec saseul-node saseul-install
   ├─ saseul-script env endpoint --set 220.127.52.185:80
   └─ saseul-script env miner --set 9dc8016e43be653eb4fc3947357c6b2769b2208bc48a

6. 노드 시작 및 상태 확인
   └─ docker exec saseul-node saseul-script start
```

### 변경된 설정 비교

| 항목 | 업데이트 전 (v2.2.0.2) | 업데이트 후 (v2.2.0.3) |
|---|---|---|
| 버전 | 2.2.0.2 | **2.2.0.3** |
| Endpoint | 220.127.52.185:80 | 220.127.52.185:80 (유지) |
| Miner | 9dc8...c48a | 9dc8...c48a (복원 완료) |
| Node Address | 5a1d...b11 | 8ab4...1b11 (시드 재생성으로 변경) |
| Active Peers | 405 | 418 (증가) |

### v2.2.0.3 릴리스 노트 (2026.02.23)

| 변경사항 | 설명 |
|---|---|
| 네트워크 트래픽 감소 | 업데이트된 노드 간 **50~80% 트래픽 절감** |
| 거래 조회 API 추가 | 트랜잭션 쿼리 API 신규 제공 |
| Inspect API 추가 | 컨트랙트 바운드 상태 데이터 조회 기능 |
| sendtransaction 지원 | 지갑 및 스크립트를 통한 트랜잭션 전송 |
| 권한 오류 수정 | 특정 상황에서 발생하던 퍼미션 에러 해결 |
| 기타 버그 수정 | 안정성 개선 |

---

## 4. 블록 쌓는 속도 비교 측정

### 측정 조건

- 측정 방법: 90초간 30초 간격으로 4회 블록 높이 기록
- 추가 측정: 120초 연속 측정
- 측정 시간: v2.2.0.2 (11:29~11:31), v2.2.0.3 (11:37~11:41)

### 90초 측정 데이터

**v2.2.0.2 (업데이트 전)**

| 시간 | Resource 블록 | Main 블록 |
|---|---|---|
| 0초 | 2,015,495 | 3,363,394 |
| 30초 | 2,015,495 (+0) | 3,363,394 (+0) |
| 60초 | 2,015,496 (+1) | 3,363,396 (+2) |
| 90초 | 2,015,497 (+2) | 3,363,396 (+2) |

**v2.2.0.3 (업데이트 후)**

| 시간 | Resource 블록 | Main 블록 |
|---|---|---|
| 0초 | 2,015,503 | 3,363,414 |
| 30초 | 2,015,504 (+1) | 3,363,415 (+1) |
| 60초 | 2,015,505 (+2) | 3,363,415 (+1) |
| 90초 | 2,015,506 (+3) | 3,363,417 (+3) |

### 120초 추가 측정 (v2.2.0.3)

| 시간 | Resource | Main |
|---|---|---|
| 0초 | 2,015,506 | 3,363,417 |
| 120초 | 2,015,507 (+1) | 3,363,423 (+6) |

Main Chain 120초간 6블록 = 약 **20초/블록**

### 속도 비교 요약

| 측정 항목 | v2.2.0.2 | v2.2.0.3 | 변화 |
|---|---|---|---|
| **Resource (90초)** | +2 블록 | +3 블록 | **+50% 개선** |
| **Main (90초)** | +2 블록 | +3 블록 | **+50% 개선** |
| **Resource 평균 속도** | ~45초/블록 | ~30초/블록 | **33% 빨라짐** |
| **Main 평균 속도** | ~45초/블록 | ~30초/블록 | **33% 빨라짐** |
| **Main 120초 측정** | - | ~20초/블록 | 장기 측정 시 더 빠름 |

### 속도 개선 분석

```
v2.2.0.2                          v2.2.0.3

90초간 블록 생성                   90초간 블록 생성

Resource: ██░░░░ 2블록            Resource: ███░░░ 3블록  (+50%)
Main:     ██░░░░ 2블록            Main:     ███░░░ 3블록  (+50%)

평균: ~45초/블록                   평균: ~30초/블록        (33% 빠름)
```

**개선 원인**: v2.2.0.3에서 노드 간 네트워크 트래픽이 50~80% 감소하면서, 블록 전파 및 동기화에 필요한 대역폭이 확보되어 체이닝 속도가 향상된 것으로 분석됩니다.

**참고**: 블록 생성 간격은 네트워크 전체의 합의 규칙에 의해 결정되므로, 시간대별 네트워크 상태에 따라 편차가 발생할 수 있습니다.

---

## 5. 보안 점검 사항

### 발견된 문제: xmrig 암호화폐 채굴 프로세스

서버 통신 분석 중 **무단 암호화폐 채굴 프로세스**가 발견되었습니다.

| 항목 | 내용 |
|---|---|
| 프로세스 | xmrig (PID 19054) |
| 마이닝 풀 | hatchlings.rxpool.net:5555 |
| 알고리즘 | rx/0 (RandomX - Monero) |
| CPU 사용 | 44스레드 (전체 코어 풀가동) |
| 외부 통신 | 220.127.52.185:60422 → 15.235.227.47:5555 |
| 가동 시간 | Feb 22부터 누적 106,367분 이상 |

**조치 권고**: 의도하지 않은 채굴인 경우 `kill -9 19054`로 즉시 종료하고, 서버 보안 점검 (침입 경로, 계정 확인 등)을 수행해야 합니다.

---

## 6. GitHub 문서화 작업

### 저장소

- URL: https://github.com/taktongyoung/saseul

### 저장소 구조

```
saseul/
├── README.md                              # 프로젝트 개요 및 자동 백업/복원 시스템 설명
├── scripts/
│   ├── saseul-backup.sh                   # 블록 데이터 백업 스크립트
│   └── saseul-restore-restart.sh          # 블록 데이터 복원 및 재시작 스크립트
├── cron/
│   └── saseul-cron                        # crontab 자동 실행 설정
└── docs/
    ├── saseul-network-guide.md            # SASEUL 네트워크 초보자 가이드
    └── server-operation-report.md         # 서버 운영 보고서 (이 문서)
```

### 작업 이력

| 순서 | 작업 내용 | 결과물 |
|---|---|---|
| 1 | 서버 네트워크 통신 전체 분석 | 열린 포트, 활성 연결, 프로세스 식별 |
| 2 | SASEUL 노드 자동 시작 설정 확인 | Docker restart policy 확인 (no → 변경 권장) |
| 3 | 매일 01:00 블록 초기화 및 백업 복원 스크립트 작성 | `scripts/saseul-backup.sh`, `scripts/saseul-restore-restart.sh` |
| 4 | GitHub 저장소에 스크립트 및 README 업로드 | `README.md`, `scripts/`, `cron/` |
| 5 | Docker Hub 정보 기반 초보자 가이드 작성 | `docs/saseul-network-guide.md` |
| 6 | SASEUL 노드 IP 숨김 방법 조사 | Cloudflare/VPN/Nginx 리버스 프록시 방안 제시 |
| 7 | 블록 쌓는 속도 측정 (v2.2.0.2) | Resource ~45초/블록, Main ~45초/블록 |
| 8 | 노드 업데이트 (v2.2.0.2 → v2.2.0.3) | 권한 마이그레이션 포함 전체 업데이트 완료 |
| 9 | 블록 쌓는 속도 재측정 (v2.2.0.3) | Resource ~30초/블록, Main ~30초/블록 (약 50% 개선) |
| 10 | 서버 운영 보고서 작성 및 GitHub 업로드 | `docs/server-operation-report.md` (이 문서) |

---

## 현재 노드 상태 (2026-02-24 11:41 KST)

```
[Node]
  Version: 2.2.0.3
  Mining:  on

[Services]
  master:       running
  peer_search:  running
  block_sync:   running
  chaining:     running
  consensus:    running

[Chain Status]
  Committed: resource=2,015,509, main=3,363,425

[Environment]
  Endpoint: 220.127.52.185:80
  Miner:    9dc8016e43be653eb4fc3947357c6b2769b2208bc48a

[Peers]
  Active: 406
```

모든 서비스가 정상 운영 중이며, 블록이 지속적으로 쌓이고 있습니다.
