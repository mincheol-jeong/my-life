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
                         ┌─────────────┐
                         │    USER     │
                         └──────┬──────┘
                                │
                                │
                         ┌──────▼──────┐
                         │   RECORD    │
                         └──────┬──────┘
                                │
          ┌─────────────┬───────┼────────┬─────────────┐
          │             │       │        │             │
          ▼             ▼       ▼        ▼             ▼
       ┌──────┐      ┌──────┐ ┌─────┐ ┌──────┐    ┌───────┐
       │ Memo │      │Expense│ │Photo│ │Event │    │ Place │
       └──────┘      └──────┘ └─────┘ └──────┘    └───────┘
          │             │       │        │             │
          └─────────────┴───────┴────────┴─────────────┘
                                │
                                ▼
                           ┌─────────┐
                           │ Travel │
                           └─────────┘
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
 ├── Photo
 ├── Event
 ├── Place
 └── Travel
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

초기 버전에서는 오른쪽 SQLite만 사용합니다.

---

# 6. Future Cloud Sync

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
