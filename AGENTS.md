# MY LIFE — Codex Development Guide

## 1. Project Overview

MY LIFE는 개인의 일상과 추억을 기록하고 시간의 흐름에 따라 다시 확인하는 Android/iOS 모바일 애플리케이션입니다.

현재 목표는 **V1 MVP**입니다. 문서 정합성 확인 후 `mobile/`에서 Phase 1부터 순서대로 구현합니다.

## 2. Source of Truth

구현 전에 다음 문서를 순서대로 확인합니다.

1. `AGENTS.md`
2. `README.md`
3. `VERSION.md`
4. `CHANGELOG.md`
5. `docs/requirements.md`
6. `docs/architecture.md`
7. `docs/design.md`
8. `docs/database.md`
9. `docs/ui-ux.md`
10. `docs/roadmap.md`

문서가 충돌하면 임의로 결정하지 않고 사용자에게 확인합니다. 현재 Phase 밖의 기능을 구현하지 않습니다.

## 3. Core Principles

### Mobile First

- Android와 iOS에서 자연스러운 사용성을 우선합니다.
- 한 손 사용과 빠른 입력을 고려합니다.

### Offline First

- V1 MVP 핵심 기능은 네트워크 없이 동작해야 합니다.
- 로컬 SQLite가 V1 MVP의 유일한 데이터 원본입니다.

### Record First

V1 MVP의 Record는 단일 타입 엔티티입니다.

```text
Record
├── MEMO
├── EXPENSE
└── PHOTO
```

하나의 Record는 하나의 타입만 가집니다. 복합 Record는 V1 MVP에서 구현하지 않습니다.

`SEARCH`, `CALENDAR`, `EVENT`, 독립 `PLACE`, `TRAVEL`은 Post-V1 기능입니다. Travel은 Record Type이 아니라 여러 Record를 묶는 Container/Aggregate로 설계합니다.

### Simple, Testable Architecture

기본 경계는 다음과 같습니다.

```text
Presentation
     ↓
Riverpod Provider / Controller
     ↓
Repository
     ↓
AppDatabase (Drift)
     ↓
SQLite
```

V1 MVP의 단순 CRUD를 위해 UseCase, LocalDataSource, RemoteDataSource, Generic Repository, Service Locator를 의무적으로 만들지 않습니다.

### Feature Based Architecture

기능별로 코드를 구성하되 공통 인프라만 `core`에 둡니다.

```text
lib/
├── app/
├── core/
└── features/
    ├── home/
    ├── expense/
    ├── record/
    ├── timeline/
    ├── finance/
    ├── photo/
    └── settings/
```

## 4. V1 MVP Scope

V1 MVP에 포함합니다.

- Home
- Timeline
- Record creation/detail/edit/delete
- Memo Record
- Expense Record와 기본 Finance 집계
- Photo Record와 로컬 파일 저장
- 사용자가 선택한 기기 캘린더 일정의 Memo 단방향 가져오기
- 사용자가 선택한 사진의 촬영 날짜·장소 metadata 제안
- Local SQLite storage
- Me: App Version, Open Source Licenses

V1 MVP에서 제외합니다.

- Event
- 독립 Place
- Travel
- Search와 독립 Calendar 화면/양방향 동기화
- Account/Login
- Backup/Restore
- Backend/Cloud Sync/Multi-device Sync
- AI
- Social/Recommendation
- Push Notification
- Advanced Analytics

## 5. Technology Rules

Flutter 프로젝트는 다음 식별자를 사용합니다.

- Location: `mobile/`
- Project name: `my_life`
- Android application ID: `com.mincheol.mylife`
- iOS bundle ID: `com.mincheol.mylife`
- Flutter channel: `stable`

Phase별로 필요한 패키지만 추가합니다.

- Phase 1: Flutter, Dart, Riverpod, GoRouter, Drift, SQLite
- Phase 2 이후 필요 시: UUID
- Phase 4: `image_picker`, `path_provider`, `path`, `image`
- Lightweight device import: `device_calendar_plus`, `native_exif`, `geocoding`
- Display Language: Flutter Localizations, `shared_preferences`
- Cloud Sync Phase: Dio 또는 당시 결정한 HTTP client

Freezed, Dio, 코드 생성 도구와 기타 패키지는 실제 사용처가 생기기 전에 추가하지 않습니다. Drift가 요구하는 생성 도구는 Drift를 도입할 때 함께 추가할 수 있습니다.

## 6. Coding Rules

- 명확한 이름을 사용합니다.
- Widget에 비즈니스 로직을 넣지 않습니다.
- Provider/Controller는 화면 상태와 사용자 동작을 조정합니다.
- Repository는 기능 단위 데이터 읽기/쓰기와 필요한 트랜잭션을 담당합니다.
- UI에서 Drift나 SQLite에 직접 접근하지 않습니다.
- 불필요한 추상화와 범용 base class를 만들지 않습니다.
- 유지보수성과 가독성을 기능 수보다 우선합니다.

## 7. Database Rules

- Drift를 통해서만 SQLite에 접근합니다.
- schema 변경마다 `schemaVersion`을 증가시키고 migration을 작성합니다.
- 개발 편의를 위해 기존 사용자 DB를 삭제하는 방식으로 migration 문제를 해결하지 않습니다.
- UUID TEXT PK를 사용합니다.
- Record는 `deleted_at` 기반 soft delete를 사용합니다.
- 시스템 timestamp는 UTC로 저장합니다.
- 생활 기록의 local date/time 의미를 보존합니다.
- 사진 바이너리는 DB에 저장하지 않습니다.

## 8. UI Rules

- `docs/ui-ux.md`가 Flutter UI/UX 구현의 공식 source of truth입니다.
- 설계 스튜디오/Work 화면은 참고 자료이며, 차이가 있으면 문서를 먼저 갱신합니다.
- Minimal, Personal, Warm, Calm 방향을 유지합니다.
- 관리자 Dashboard처럼 만들지 않습니다.
- 주요 입력은 한 손으로 빠르게 완료할 수 있어야 합니다.
- V1 MVP에 없는 Search, 독립 Calendar/Event, Place, Travel을 사용 가능한 기능처럼 노출하지 않습니다. 승인된 Calendar Import는 Me에서만 제공합니다.
- Empty, Loading, Error 상태를 사용자 언어로 제공합니다.
- 충분한 터치 영역, 대비, 글자 크기와 시스템 font scale을 고려합니다.

## 9. V1 MVP Phase Order

```text
Foundation
  → Record + Memo
  → Expense
  → Photo
  → Timeline
  → Home
  → Finance
  → Me
  → V1 MVP Stabilization
```

각 Phase의 quality gate가 통과하기 전에 다음 Phase를 구현하지 않습니다.

## 10. Testing Rules

우선순위는 다음과 같습니다.

1. Repository와 domain 규칙
2. Database query와 migration
3. Provider/Controller
4. 핵심 Widget flow

테스트가 실패하는 상태에서 작업을 완료했다고 판단하지 않습니다.

## 11. Change Workflow

```text
Read Documents
      ↓
Inspect Existing Code
      ↓
Plan
      ↓
Implement
      ↓
Format
      ↓
Analyze
      ↓
Test
      ↓
Review
```

기존 변경사항은 사용자 소유로 간주하고 관련 없는 파일을 되돌리거나 덮어쓰지 않습니다.

## 12. Documentation and Versioning

- README는 실제 저장소 상태만 설명합니다.
- 존재하지 않는 명령, 기능, 설정을 완료된 것처럼 문서화하지 않습니다.
- VERSION은 release 준비 시 실제 앱 버전과 맞춥니다.
- CHANGELOG는 `Unreleased` 아래에 사용자 또는 개발자에게 의미 있는 변경을 기록합니다.
- 버전을 매 commit마다 자동으로 올리지 않습니다.
- Architecture, Database, UI 또는 개발 절차가 바뀌면 관련 문서를 함께 갱신합니다.

## 13. Definition of Done

- 현재 Phase 요구사항을 만족합니다.
- 기존 기능을 깨뜨리지 않습니다.
- 관련 테스트가 있고 통과합니다.
- `flutter analyze`가 통과합니다.
- 불필요한 코드와 패키지가 없습니다.
- 문서가 실제 구현과 일치합니다.
