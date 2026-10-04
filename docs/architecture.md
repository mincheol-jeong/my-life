# MY LIFE — Architecture

## 1. Architecture Overview

MY LIFE는 Offline First Mobile Architecture를 기반으로 합니다.

초기 버전에서는 서버 없이 모바일 디바이스 내부의 SQLite를 사용합니다.

향후 Cloud Sync가 필요해지면 Remote API를 추가합니다.

```text
                    ┌──────────────────────┐
                    │      MY LIFE APP     │
                    │       Flutter        │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │    Presentation      │
                    │                      │
                    │ Screen / Widget      │
                    │ Riverpod Provider    │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │       Domain         │
                    │                      │
                    │ Entity                │
                    │ Business Logic        │
                    │ Repository Interface  │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │        Data          │
                    │                      │
                    │ Repository Impl      │
                    │ Local Data Source    │
                    │ Remote Data Source   │
                    └───────┬───────┬──────┘
                            │       │
                     ┌──────▼───┐ ┌─▼──────────┐
                     │  SQLite  │ │ REST API   │
                     │  Drift   │ │  Future    │
                     └──────────┘ └─────┬──────┘
                                        │
                                  ┌─────▼─────┐
                                  │ PostgreSQL│
                                  └───────────┘
```

---

# 2. Layer Architecture

## Presentation Layer

사용자에게 화면을 표시합니다.

```text
Screen
Widget
Provider
State
```

Presentation Layer는 Database에 직접 접근하지 않습니다.

---

## Domain Layer

애플리케이션의 핵심 개념을 관리합니다.

```text
Record
Expense
Travel
Photo
Place
Event
```

Domain Layer는 Flutter UI 구현 세부사항에 의존하지 않는 것을 목표로 합니다.

---

## Data Layer

실제 데이터를 읽고 저장합니다.

```text
Repository
├── LocalDataSource
└── RemoteDataSource
```

초기에는 LocalDataSource만 구현합니다.

---

# 3. Feature Architecture

기능은 다음과 같이 구성합니다.

```text
features/
├── calendar_import/
│   ├── application/
│   ├── data/
│   ├── domain/
│   └── presentation/
├── home/
│   └── presentation/
├── expense/
│   ├── application/
│   ├── data/
│   ├── domain/
│   └── presentation/
├── timeline/
│   ├── application/
│   ├── data/
│   ├── domain/
│   └── presentation/
├── record/
│   ├── application/
│   ├── data/
│   ├── domain/
│   └── presentation/
├── photo/
│   ├── application/
│   ├── data/
│   ├── domain/
│   └── presentation/
├── finance/
│   └── presentation/
└── settings/
    └── presentation/
```

---

# 4. Core Data Flow

사용자가 지출을 추가하는 경우:

```text
User
 │
 ▼
ExpenseScreen
 │
 ▼
ExpenseController / Provider
 │
 ▼
ExpenseRepository
 │
 ▼
Drift Database
 │
 ▼
SQLite
```

`ExpenseRepository`가 `records`와 `expenses`를 하나의 Drift transaction으로 저장·수정합니다. 단순 CRUD에 중복 Repository나 DataSource 계층을 추가하지 않습니다.

Photo는 `PhotoRepository`가 `records`/`photos` transaction과 `PhotoStorage`의 앱 전용 파일을 조정합니다. DB 작업 전 원본과 썸네일을 준비하고, DB 실패 시 새로 만든 파일을 정리합니다. 삭제는 파일을 임시 영역으로 이동한 후 transaction 성공 시 확정하고, 실패 시 복구합니다.

표시 언어는 Riverpod locale controller가 관리하며 한국어와 English를 지원합니다. 선택값은 `shared_preferences`에 저장하고, 기록 데이터는 언어와 관계없이 SQLite에 유지합니다.

Timeline은 각 기능의 CRUD를 다시 구현하지 않습니다. `TimelineRepository`가 active `records`를 기준으로 `expenses`와 `photos`를 읽기 전용 join하고, local date/type filter와 정렬 결과를 Drift stream으로 제공합니다. Riverpod은 filter 상태와 stream을 화면에 연결합니다.

Calendar Import는 사용자가 Me에서 실행하는 opt-in adapter입니다. `CalendarDeviceService`가 OS 권한과 calendar/event 읽기를 담당하고, `CalendarImportRepository`가 선택된 event를 Memo Record와 `calendar_imports` mapping으로 transaction 저장합니다. OS calendar에는 쓰지 않습니다.

Photo metadata는 사용자가 선택한 첫 파일만 `PhotoMetadataReader`가 분석합니다. EXIF 촬영시각과 GPS를 작성 초기값으로 제안하고, GPS reverse geocoding 실패는 좌표 fallback으로 처리합니다. 분석 실패는 Photo 저장을 막지 않습니다.

저장 완료 후:

```text
SQLite
 │
 ▼
Stream
 │
 ▼
Riverpod
 │
 ▼
Timeline
 │
 ▼
UI Update
```

---

# 5. Record Architecture

Record는 MY LIFE의 중심입니다.

```text
                         Record
                            │
       ┌────────────┬───────┼────────┬───────────┐
       │            │       │        │           │
      Memo        Expense  Photo    Event       Place
       │            │       │        │           │
       └────────────┴───────┴────────┴───────────┘
                            │
                          Travel
```

Record 자체에는 공통 정보만 저장합니다.

```text
Record
├── id
├── type
├── title
├── content
├── eventDate
├── createdAt
├── updatedAt
├── latitude
├── longitude
└── placeName
```

세부 데이터는 각 기능별 테이블에서 관리합니다.

---

# 6. Repository Pattern

Repository는 UI와 Data Source 사이의 추상화 계층입니다.

예:

```dart
abstract class RecordRepository {
  Future<Record> create(Record record);

  Future<Record?> findById(String id);

  Stream<List<Record>> watchAll();

  Future<void> update(Record record);

  Future<void> delete(String id);
}
```

구현:

```text
RecordRepository
       │
       ▼
RecordRepositoryImpl
       │
       ▼
RecordLocalDataSource
       │
       ▼
Drift
```

향후:

```text
RecordRepositoryImpl
       │
       ├── LocalDataSource
       │
       └── RemoteDataSource
```

로 확장할 수 있습니다.

---

# 7. State Management

Riverpod을 사용합니다.

기본 구조:

```text
Screen
  │
  ▼
Provider
  │
  ▼
Repository
```

Provider는 다음 상태를 관리합니다.

* Loading
* Data
* Empty
* Error

예:

```text
AsyncValue<List<Record>>
```

---

# 8. Navigation

GoRouter를 사용합니다.

기본 구조:

```text
/
├── home
├── timeline
├── record
│   ├── memo
│   ├── expense
│   ├── photo
│   └── event
├── finance
├── travel
└── settings
```

Bottom Navigation:

```text
Home
Timeline
Record
Finance
Me
```

---

# 9. Local Storage

Drift + SQLite를 사용합니다.

```text
Flutter
   │
   ▼
Drift
   │
   ▼
SQLite
```

SQLite를 직접 호출하지 않습니다.

모든 DB 접근은 Drift를 통해 수행합니다.

---

# 10. Image Storage

사진 파일 자체를 DB에 저장하지 않습니다.

```text
SQLite
│
└── photo.path
        │
        ▼
Application Documents Directory
        │
        └── images/
```

DB에는 파일 경로와 metadata만 저장합니다.

---

# 11. Future Cloud Architecture

Cloud Sync가 필요한 시점에 Remote API를 추가합니다.

```text
                  Mobile
                    │
          ┌─────────┴─────────┐
          │                   │
       SQLite              REST API
          │                   │
       Local             FastAPI
          │                   │
          │              PostgreSQL
          │                   │
          │              Object Storage
          │
          └────── Sync ───────┘
```

Cloud Sync는 MVP에 포함하지 않습니다.

---

# 12. AI Architecture

AI는 애플리케이션 핵심 로직에 직접 연결하지 않습니다.

```text
MY LIFE Data
     │
     ▼
AI Service
     │
     ▼
OpenAI API
```

AI는 다음 기능을 지원하는 것을 목표로 합니다.

* 자연어 검색
* 기록 요약
* 지출 분석
* 여행 기록 요약
* 기간별 생활 요약

AI가 원본 데이터를 직접 수정하지 않도록 합니다.

AI는 기본적으로 읽기 전용 분석 계층으로 시작합니다.

---

# 13. Security Architecture

MVP:

```text
Local Device
     │
     └── App Lock
```

향후:

```text
Biometric
     │
     ▼
Secure Storage
```

서버 연동 이후:

```text
HTTPS
JWT / OAuth
Encrypted Storage
Access Control
```

을 적용합니다.

---

# 14. Architecture Constraints

다음 구조는 금지합니다.

### UI에서 직접 DB 접근

```text
Widget → SQLite
```

### Global Singleton 남용

```text
모든 기능 → 하나의 거대한 Service
```

### Feature 간 직접 DB 접근

```text
Finance → Travel DB 직접 접근
```

필요한 경우 Repository를 통해 데이터를 가져옵니다.

---

# 15. MVP Architecture

MVP의 실제 범위:

```text
Flutter
 │
 ├── Riverpod
 ├── GoRouter
 ├── Freezed
 └── Drift
       │
       ▼
     SQLite
```

Backend:

```text
Not implemented
```

AI:

```text
Not implemented
```

Cloud:

```text
Not implemented
```

이 상태에서 먼저 완성도 높은 모바일 앱을 만드는 것을 목표로 합니다.
