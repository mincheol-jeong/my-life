# MY LIFE — System Design

## 1. 전체 시스템

```text
┌───────────────────────────────────────────────┐
│                    MY LIFE                    │
│                                               │
│                 Flutter App                   │
│                                               │
│  ┌────────┐ ┌──────────┐ ┌───────────────┐   │
│  │  Home  │ │ Timeline │ │    Record     │   │
│  └────────┘ └──────────┘ └───────────────┘   │
│                                               │
│  ┌────────┐ ┌──────────┐                     │
│  │Finance │ │   Me     │                     │
│  └────────┘ └──────────┘                     │
│                                               │
└──────────────────────┬────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │    Riverpod     │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   Repository    │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │      Drift      │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │     SQLite      │
              └─────────────────┘
```

---

# 2. Record Relationship

```text
Record (exactly one type)
├── MEMO: records only, no Memo table
├── EXPENSE: Record 1:1 Expense
└── PHOTO: Record 1:N Photo (at least one)
```

---

# 3. Mobile Navigation

```text
                    MY LIFE
                       │
        ┌──────────────┼──────────────┐
        │              │              │
       Home         Timeline        Record
        │              │              │
        │              │        ┌─────┼─────┐
        │              │        │     │     │
        │              │      Memo Expense Photo
        │              │
        └──────────────┼──────────────┘
                       │
                 ┌─────┴─────┐
                 │           │
              Finance       Me
```

---

# 4. Record Creation Flow

```text
User
 │
 ▼
Tap "+"
 │
 ▼
Select Record Type
 │
 ├── Memo
 ├── Expense
 └── Photo
 │
 ▼
Input Data
 │
 ▼
Validation
 │
 ▼
Repository
 │
 ▼
SQLite
 │
 ▼
Riverpod State Update
 │
 ▼
Timeline Refresh
```

---

# 5. Offline First

```text
                    User
                     │
                     ▼
                  Flutter
                     │
              ┌──────┴──────┐
              │             │
           Online         Offline
              │             │
              ▼             ▼
             API          SQLite
              │             │
              ▼             │
          PostgreSQL        │
              │             │
              └──────┬──────┘
                     │
                  Sync
```

V1에서는 네트워크 여부와 무관하게 SQLite만 source of truth로 사용합니다. 위 Online/API 경로는 Post-V1 Cloud Sync 가능성을 나타내며 구현하지 않습니다.

승인된 기기 입력 확장도 로컬 원칙을 유지합니다. Calendar 단방향 자동 반영은 선택한 기기 캘린더를 읽어 Memo로 반영하고 local 수정은 보호합니다. Payment Import는 Android 선택 앱 알림 또는 iOS 단축어 텍스트 → native handoff queue → MethodChannel → Drift 미확인 초안 → 사용자 확인 → Expense transaction으로 처리합니다. OS 캘린더에는 쓰지 않고 금융 계정/API나 backend는 연결하지 않습니다.

---

# 6. Future Cloud Sync

이하 Cloud/AI/Travel은 Post-V1 방향이며 구현 설계나 현재 V1 기능이 아닙니다. Travel은 Record Type이 아니라 여러 Record를 묶는 Container/Aggregate입니다.

```text
                    Mobile
                       │
              ┌────────┴────────┐
              │                 │
            Local             Remote
              │                 │
            SQLite             API
              │                 │
              │              FastAPI
              │                 │
              │             PostgreSQL
              │                 │
              │             Object Storage
              │                 │
              └────── Sync ─────┘
```

Sync는 다음 원칙을 사용합니다.

```text
Local Change
     │
     ▼
Change Queue
     │
     ▼
API
     │
     ▼
Server
     │
     ▼
Sync Result
```

---

# 7. AI Architecture

```text
                 MY LIFE DATA
                      │
                      ▼
               Query / Context
                      │
                      ▼
                 AI Service
                      │
                      ▼
                OpenAI API
                      │
                      ▼
              Natural Language
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
        Search      Summary     Analysis
```

AI는 처음에는 Read Only로 동작합니다.

---

# 8. Final Architecture

```text
┌────────────────────────────────────────────────────────────┐
│                         MOBILE                             │
│                                                            │
│                       Flutter                              │
│                                                            │
│  Home │ Timeline │ Record │ Finance │ Me                   │
│                                                            │
│                     Riverpod                               │
│                         │                                  │
│                    Repository                              │
│                         │                                  │
│                       Drift                                │
│                         │                                  │
│                       SQLite                               │
└─────────────────────────┬──────────────────────────────────┘
                          │
                     Future Sync
                          │
                          ▼
┌────────────────────────────────────────────────────────────┐
│                         CLOUD                              │
│                                                            │
│                       FastAPI                              │
│                          │                                 │
│              ┌───────────┼───────────┐                     │
│              │           │           │                     │
│         PostgreSQL   Object Storage  AI                    │
│                                      │                     │
│                                 OpenAI API                 │
└────────────────────────────────────────────────────────────┘
```

---

# 9. Product Evolution

```text
                    MY LIFE

                      MVP
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
        Record       Timeline      Photo
          │            │            │
          └────────────┼────────────┘
                       │
                       ▼
                    Finance
                       │
                       ▼
                     Travel
                       │
                       ▼
                    Backup
                       │
                       ▼
                  Cloud Sync
                       │
                       ▼
                       AI
```

최종적으로 MY LIFE는 단순한 가계부나 일정 관리 앱이 아니라 개인의 기록을 장기간 축적하고 다시 활용할 수 있는 Personal Life Data Platform을 목표로 합니다.

위 Product Evolution 그림은 개념 방향이며 구현 순서는 roadmap을 따릅니다. 회원 정보 관리와 수익화는 `accounts.md`, `monetization.md`의 Post-V1 제안으로 추가합니다. 기존 guest/offline 기록은 유지하고 로그인만으로 기록을 업로드하지 않는 방향을 제안합니다. 계정·결제와 Expense Record는 다른 모델이며 V1에 미래 table을 추가하지 않습니다.
