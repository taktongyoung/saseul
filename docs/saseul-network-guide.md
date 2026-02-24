# SASEUL(사슬) 네트워크 쉽게 알아보기

## SASEUL이 뭐야?

SASEUL(사슬)은 **블록체인**이라는 기술로 만들어진 네트워크야.

블록체인이 뭐냐고? 쉽게 말하면 **모든 사람이 함께 쓰는 거대한 일기장** 같은 거야.

- 한 명이 일기장을 가지고 있으면 그 사람이 마음대로 고칠 수 있지?
- 그런데 **모든 사람이 똑같은 일기장 복사본을 가지고 있으면** 아무도 몰래 고칠 수가 없어!
- 이게 바로 블록체인의 원리야.

SASEUL 네트워크에서는 이 일기장을 관리하는 컴퓨터를 **"노드(Node)"** 라고 불러.

---

## Docker가 뭐야?

SASEUL 노드를 설치하려면 **Docker(도커)** 라는 프로그램이 필요해.

Docker는 **컴퓨터 안에 작은 컴퓨터를 만드는 마법 상자** 같은 거야.

```
┌──────────────────────────────┐
│    내 컴퓨터                   │
│                               │
│   ┌───────────────────┐      │
│   │  Docker 상자       │      │
│   │                    │      │
│   │  SASEUL 노드가     │      │
│   │  여기서 돌아가!     │      │
│   └───────────────────┘      │
└──────────────────────────────┘
```

왜 이렇게 할까?
- 내 컴퓨터를 더럽히지 않아! (프로그램이 꼬이지 않아)
- 누구나 똑같은 환경에서 실행할 수 있어!
- 필요 없으면 상자째 지우면 끝!

---

## SASEUL 노드는 뭘 하는 거야?

노드가 하는 일을 식당에 비유하면 이래:

| 노드가 하는 일 | 식당에 비유하면 |
|---|---|
| **블록 동기화 (sync)** | 다른 식당에서 레시피를 가져오는 것 |
| **블록 체이닝 (chaining)** | 레시피대로 요리를 만드는 것 |
| **합의 (consensus)** | 모든 식당이 같은 메뉴인지 확인하는 것 |
| **마이닝 (mining)** | 새로운 레시피를 만들어서 보상받는 것 |
| **피어 검색 (peer search)** | 주변에 다른 식당이 있는지 찾는 것 |

---

## 컴퓨터 사양은 얼마나 필요해?

| 항목 | 최소 사양 |
|---|---|
| CPU | 4코어 (뇌가 4개인 컴퓨터) |
| RAM (메모리) | 8GB (한 번에 기억할 수 있는 양) |
| 저장공간 | 256GB (일기장을 저장할 공간) |

AWS 클라우드를 쓴다면 **r5.xlarge** 라는 타입을 추천해.
집에 있는 Windows PC나 Mac으로도 할 수 있어!

---

## 설치하는 방법 (따라하기)

### 1단계: Docker 설치하기

**AWS Linux 서버인 경우:**
```bash
sudo dnf install -y docker
sudo systemctl enable --now docker
```

**Windows나 Mac인 경우:**
- Windows: https://docs.docker.com/desktop/install/windows-install
- Mac: https://docs.docker.com/desktop/install/mac-install
- 위 사이트에서 Docker Desktop을 다운받아서 설치하면 돼!

### 2단계: SASEUL 노드 설치하기

```bash
# SASEUL 프로그램 다운로드
sudo docker pull artifriends/saseul-network:latest

# 블록 데이터를 저장할 폴더 만들기
sudo mkdir /var/saseul-data

# SASEUL 노드 실행!
sudo docker run -d --init --name saseul-node \
  -p 80:80 \
  -v /var/saseul-data:/var/saseul/saseul-network/data \
  --entrypoint /bin/saseul-init \
  artifriends/saseul-network:latest
```

이게 무슨 뜻이냐면:

| 부분 | 뜻 |
|---|---|
| `docker run` | Docker 상자를 실행해! |
| `-d` | 조용히 뒤에서 돌아가게 해 |
| `--init` | 프로그램을 깔끔하게 시작/종료해 |
| `--name saseul-node` | 이 상자 이름은 "saseul-node"야 |
| `-p 80:80` | 80번 문(포트)을 열어서 다른 노드와 대화해 |
| `-v /var/saseul-data:...` | 블록 데이터를 내 컴퓨터에 저장해 (상자가 사라져도 데이터는 남아!) |

### 3단계: 초기 설정

```bash
# 노드 초기 설정 (처음 한 번만)
sudo docker exec -it saseul-node saseul-install

# 질문이 나와:
#   "Please enter your endpoint" → 내 서버 주소 입력 (예: 123.456.789.0:80)
#   "Please enter your miner address" → 그냥 엔터 (기본 지갑 사용)
```

### 4단계: 노드 시작!

```bash
# 노드 시작
sudo docker exec -it saseul-node saseul-script start

# 잘 돌아가는지 로그 확인
sudo docker exec -it saseul-node saseul-script log -f
```

---

## 자주 쓰는 명령어 모음

### 기본 명령어

```bash
# 노드 상태 보기 (지금 몇 번째 블록인지, 잘 돌아가는지)
sudo docker exec -it saseul-node saseul-script info

# 노드 시작하기
sudo docker exec -it saseul-node saseul-script start

# 노드 멈추기
sudo docker exec -it saseul-node saseul-script stop

# 노드 다시 시작하기
sudo docker exec -it saseul-node saseul-script restart

# 노드 강제 종료 (멈추지 않을 때)
sudo docker exec -it saseul-node saseul-script kill
```

### 로그(기록) 보기

```bash
# 실시간 로그 보기 (Ctrl+C로 나가기)
sudo docker exec -it saseul-node saseul-script log -f

# 마이닝 로그 보기
sudo docker exec -it saseul-node saseul-script log -m -f
```

### 블록 데이터 관리

```bash
# 데이터가 정상인지 검사
sudo docker exec -it saseul-node saseul-script data check

# 상태 데이터베이스 다시 만들기
sudo docker exec -it saseul-node saseul-script data rebuild

# 모든 블록 데이터 초기화 (처음부터 다시!)
sudo docker exec -it saseul-node saseul-script data reset --all

# 트리 데이터만 초기화 (블록은 유지)
sudo docker exec -it saseul-node saseul-script data reset --tree

# 상태 데이터만 초기화
sudo docker exec -it saseul-node saseul-script data reset --status

# 특정 블록 높이로 되돌리기
sudo docker exec -it saseul-node saseul-script data rewind -n 2000000
```

### 마이닝(채굴) 관련

```bash
# 외부 마이닝 켜기
sudo docker exec -it saseul-node saseul-script mining external on

# 마이닝 시작
sudo docker exec -it saseul-node saseul-script mining start

# GPU 마이닝 시작 (그래픽카드가 있는 경우)
sudo docker exec -it saseul-node saseul-script mining gpu start

# GPU 마이닝 상태 확인
sudo docker exec -it saseul-node saseul-script mining gpu check
```

---

## 마이닝이 뭐야? (채굴)

마이닝은 **수학 문제를 풀어서 보상을 받는 것**이야.

```
1. 노드가 어려운 수학 문제를 풀어 → "나 정답 찾았다!"
2. 다른 노드들이 확인해                → "진짜네, 맞아!"
3. 새로운 블록을 만들 권한을 받아      → "너가 다음 블록 만들어!"
4. 보상으로 "Resource"를 받아          → 용돈 같은 거!
5. Resource를 SL 코인으로 바꿀 수 있어 → "Refine" 이라는 거래를 보내면 돼
```

**Resource**: 채굴하면 받는 보상 포인트
**SL 코인**: 실제 사용할 수 있는 코인 (Resource를 변환해야 해)
**Refine**: Resource를 SL로 바꾸는 과정

---

## 업데이트 하는 방법

새 버전이 나오면 이렇게 업데이트해:

```bash
# 1. 노드 멈추기
sudo docker stop saseul-node

# 2. 기존 상자 지우기 (데이터는 안전해! /var/saseul-data에 있으니까)
sudo docker rm saseul-node

# 3. 새 버전 다운로드
sudo docker pull artifriends/saseul-network:latest

# 4. 새 상자로 다시 시작
sudo docker run -d --init --name saseul-node \
  -p 80:80 \
  -v /var/saseul-data:/var/saseul/saseul-network/data \
  --entrypoint /bin/saseul-init \
  artifriends/saseul-network:latest

# 5. 설정 및 시작
sudo docker exec -it saseul-node saseul-install
sudo docker exec -it saseul-node saseul-script start
```

---

## 문제가 생겼을 때 (문제 해결)

### 블록 동기화가 멈췄어!

다른 길(포크)로 잘못 들어갔을 수 있어. 길을 다시 찾아주자:

```bash
sudo docker exec -it saseul-node saseul-script stop
sudo docker exec -it saseul-node saseul-script tracker reset
sudo docker exec -it saseul-node saseul-script data reset --tree
sudo docker exec -it saseul-node saseul-script start
```

### 너무 깊이 잘못된 길로 갔어!

특정 블록 높이로 되돌리기:

```bash
sudo docker exec -it saseul-node saseul-script stop
sudo docker exec -it saseul-node saseul-script tracker reset
sudo docker exec -it saseul-node saseul-script data rewind -n 2000000
sudo docker exec -it saseul-node saseul-script start
```

### 내 노드 상태를 웹에서 확인하고 싶어!

브라우저에서 `http://내서버주소/chaininfo` 를 열면 볼 수 있어.

---

## 사용 가능한 버전 (태그 목록)

| 태그 | 설명 | CPU 종류 |
|---|---|---|
| `latest` | 최신 버전 (추천!) | amd64 (일반 PC) |
| `2.2.0.3` | 최신 정식 버전 | amd64 |
| `2.2.0.3-lite` | 가벼운 버전 | amd64 |
| `2.2.0.3-arm64` | ARM 프로세서용 | arm64 (M1/M2 Mac 등) |
| `arm64` | ARM 최신 버전 | arm64 |
| `2.2.0.2` | 이전 버전 | amd64 |

---

## 중요한 폴더 설명

```
/var/saseul-data/              ← 내 컴퓨터에 저장되는 블록 데이터
  ├── bunch/                   ← 블록 묶음 (일기장 페이지들)
  ├── chain_tree/              ← 체인 구조 (일기장 목차)
  ├── main_chain/              ← 메인 체인 (진짜 일기장)
  ├── resource_chain/          ← 리소스 체인 (보상 기록)
  ├── status/                  ← 현재 상태 (지금 잔액이 얼마인지)
  ├── network/                 ← 네트워크 (친구 목록)
  ├── sync_tree/               ← 동기화 정보
  ├── system_contract/         ← 스마트 컨트랙트 (자동 약속)
  ├── wallets/                 ← 내 지갑! (이건 절대 지우면 안 돼!)
  ├── env                      ← 환경 설정
  └── secrets                  ← 비밀키 (비밀번호 같은 것, 잃어버리면 복구 못 해!)
```

---

## 포트 (문) 설명

컴퓨터에는 여러 개의 문(포트)이 있어. SASEUL은 이 문들을 써:

| 포트 번호 | 용도 |
|---|---|
| **80** | 다른 노드와 대화하는 문 (필수!) |
| **22** | SSH 접속 (서버 관리용) |
| **443** | HTTPS 보안 연결 |

집 공유기를 쓴다면 **80번 포트를 열어줘야** 다른 노드와 통신할 수 있어!

---

## 버전 업데이트 기록

| 버전 | 날짜 | 바뀐 점 |
|---|---|---|
| **v2.2.0.3** | 2026.02.23 | 네트워크 트래픽 50~80% 감소, 거래 조회 API 추가, GPU 마이너 개선 |
| **v2.2.0.2** | 2026.02.13 | 실험적 GPU 마이너 추가, 동기화 성능 개선 |
| **v2.1.9.6** | 2023.07.20 | 625,000 블록에서 하드포크, 마이닝 난이도 수정 |
| **v2.1.7.6** | 2023.04.02 | 80번 외 다른 포트 사용 가능, 네트워크 트래픽 문제 해결 |

---

## 알아두면 좋은 것들

- **SASEUL은 오픈소스가 아니야!** ArtiFriends라는 회사가 만들고 관리해.
- **텔레그램**에서 공지를 받을 수 있어:
  - 공지 채널: https://t.me/saseul_notice
  - 질문 채널: https://t.me/+tHSKLYQeZCI2N2I1
- **블록 탐색기**: https://explorer.saseul.com (블록 정보를 웹에서 볼 수 있어)
- **Guardee 지갑**: https://guardee.io (핸드폰이나 크롬으로 지갑을 관리할 수 있어)
- **컴퓨터 시간이 정확해야 해!** 시간이 많이 다르면 노드가 제대로 작동하지 않아.

---

## 한 줄 요약

> SASEUL은 블록체인 네트워크이고, Docker라는 프로그램으로 내 컴퓨터에 노드를 설치하면
> 네트워크에 참여하고 채굴(마이닝)로 보상을 받을 수 있어!
