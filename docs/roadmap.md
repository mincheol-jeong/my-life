# MY LIFE — Development Roadmap

## 1. Development Strategy

V1 MVP를 작은 Phase로 나누어 순서대로 완성합니다. 각 Phase는 이전 Phase의 format, analyze, test와 필요한 build 검증이 통과한 뒤 시작합니다.

## 2. V1 MVP Phase Overview

```text
Phase 1  Foundation
   ↓
Phase 2  Record + Memo
   ↓
Phase 3  Expense
   ↓
Phase 4  Photo
   ↓
Phase 5  Timeline
   ↓
Phase 6  Home
   ↓
Phase 7  Finance
   ↓
Phase 8  Me
   ↓
V1 MVP Stabilization
```

## 3. Phase 1 — Foundation

Status: `DONE`

Tasks:

- `mobile/` Flutter project 생성
- Project name `my_life`
- Android application ID와 iOS bundle ID `com.mincheol.mylife`
- Android/iOS target, Flutter stable channel
- Riverpod
- GoRouter와 Bottom Navigation shell
- Drift/SQLite와 AppDatabase
- Theme architecture; V1 MVP에는 Theme Selector 없음
- 필요한 directory structure
- Error handling과 privacy-safe logging
- Analyze/test 기반

Completion:

- 실제 Flutter/Dart 버전을 README에 기록합니다.
- Android와 iOS project configuration의 identifier가 일치합니다.
- 기본 앱과 AppDatabase test가 동작합니다.
- `dart format .`, `flutter analyze`, `flutter test`가 통과합니다.

Current verification:

- Flutter 3.47.5 stable / Dart 3.13.4
- Format, analyze, Foundation tests 통과
- Android debug APK build와 iOS simulator build 통과

## 4. Phase 2 — Record + Memo

Status: `DONE`

Tasks:

- UUID와 Record type model
- `records` table과 migration
- Record repository와 CRUD
- Memo Record 생성/수정/soft delete
- Memo input과 Record detail
- Validation과 fallback label

Completion:

- Memo가 SQLite에 저장되고 앱 재실행 후 유지됩니다.
- Memo validation, repository, migration test가 통과합니다.

Current verification:

- `records` schema v2 migration과 active Record index 검증
- Memo create/read/update/soft-delete 및 fallback label test 통과
- Record 선택부터 Memo 저장/상세 이동까지 widget flow test 통과
- Format, analyze, test 통과

## 5. Phase 3 — Expense

Status: `DONE`

Tasks:

- `expenses` table과 migration
- Expense model과 Record 1:1 invariant
- Expense repository logic와 transaction
- Expense 입력/수정/soft delete
- KRW 양의 INTEGER validation

Completion:

- Expense가 Record와 1:1로 저장됩니다.
- 앱 재실행 후 데이터가 유지됩니다.
- amount, FK, UNIQUE, transaction test가 통과합니다.

Current verification:

- `expenses` schema v3와 version 1/2 upgrade migration 검증
- Expense create/read/update/soft-delete와 title/memo/category fallback label test 통과
- Record 1:1, FK, UNIQUE, amount CHECK, transaction rollback test 통과
- DB 재개방 후 Expense 지속성과 Expense 저장/상세 widget flow test 통과
- Format, analyze, 21 tests 통과
- Android debug APK build와 iOS simulator build 통과

## 6. Phase 4 — Photo

Status: `DONE`

Tasks:

- `photos` table과 migration
- Photo Record 1:N transaction
- Gallery와 Camera
- App private local file storage
- Multiple Photos와 ordering
- Thumbnail과 Photo detail
- 개별 Photo metadata/관리 파일 삭제
- 마지막 Photo 확인과 Photo Record 전체 삭제

Completion:

- Photo Record가 한 장 이상의 사진을 가집니다.
- 앱 재실행 후 사진이 유지됩니다.
- Gallery 원본은 변경되지 않습니다.
- 실패 시 불완전한 Record 또는 고아 작업 파일이 남지 않습니다.

Current verification:

- `photos` schema v4와 version 1/2/3 upgrade migration 검증
- Camera/Gallery, 다중 선택 순서, 앱 전용 원본·썸네일 저장 구현
- Photo metadata 수정, 개별 삭제, 마지막 사진 및 전체 Record 삭제 구현
- DB/file rollback, FK, UNIQUE, dimension/order constraint, 원본 보존, 재실행 지속성 test 통과
- 한국어/English 현지화와 Me 언어 선택·저장 구현
- Format, analyze, 31 tests 통과
- Android debug APK build와 iOS simulator build 통과

## 7. Phase 5 — Timeline

Status: `DONE`

Tasks:

- 전체 active Record 조회
- Local date grouping과 최신순 정렬
- Record card와 detail navigation
- Record Type Filter: 전체/메모/지출/사진
- Date Range Filter
- Empty, Loading, Error state

Completion:

- 모든 V1 MVP Record Type이 일관되게 표시됩니다.
- 삭제된 Record가 표시되지 않습니다.
- 기본 type/date filter가 동작합니다.

Current verification:

- `records`/`expenses`/`photos`를 조합하는 Timeline 전용 read repository 구현
- local date 그룹, 날짜/시간/생성 순 정렬과 soft-deleted Record 제외 검증
- 전체/메모/지출/사진과 inclusive date range filter 구현 및 test 통과
- Memo/Expense/Photo card와 각 detail navigation 구현
- Empty, Loading, Error/retry state 구현
- Format, analyze, 36 tests 통과
- Android debug APK build와 iOS simulator build 통과

## 7.1 Approved Lightweight Device Import

Status: `DONE`

- 사용자가 허용·선택한 calendar/date range의 event를 Memo로 단방향 가져오기
- `calendar_imports` schema v5 mapping으로 occurrence 중복 방지
- OS calendar 원본 비수정, background/양방향 sync 제외
- 선택한 첫 사진의 EXIF 촬영시각·GPS를 Photo 입력값으로 제안
- OS reverse geocoding 실패 시 좌표 fallback, metadata 실패 시 수동 입력 유지
- Memo/Expense/Photo 작성 화면 명시적 뒤로가기
- schema migration/repository/widget 포함 40 tests와 analyze 통과
- Android debug APK와 iOS simulator build 및 iPhone 18 Pro simulator 설치 통과

## 8. Phase 6 — Home

Status: `DONE`

Tasks:

- 오늘 local date
- 최근 Record
- 이번 달 Expense 요약
- 최근 Photo
- Section별 empty/loading/error state

구현되지 않은 Post-V1 기능은 표시하지 않습니다.

Completion:

- Record, Expense, Photo 변경이 Home에 반영됩니다.
- Event Today와 Travel card가 존재하지 않습니다.

Current verification:

- 오늘 local date와 자정/앱 복귀 갱신 구현
- Timeline과 같은 정렬의 최근 Record 5개, 최근 Photo Record 6개 대표 썸네일과 detail 이동 구현
- active Expense의 local date 기준 월별 SUM과 create/update/delete 실시간 반영 검증
- 월초/월말·연말·윤년·soft delete와 사진 join 전 parent limit 검증
- 각 section의 empty/loading/error·재시도와 한국어/English 화면 흐름 검증
- Format, analyze, 전체 51 tests 통과
- Android debug APK build와 iOS simulator build 통과

## 8.1 Approved Device Connections

- Android 알림 접근 + 선택 앱 source의 지출 초안 수집
- iOS opt-in 단축어 URL 텍스트 수신; 실제 카드 알림/자동화 호환성은 device verification 필요
- 원문 확인 후 기존 Expense form 저장, 처리 transaction과 동일 source/external ID 중복 방지
- Calendar opt-in 단방향 자동 반영; launch/resume/foreground 5분 주기, 고정 기간과 local 수정 보호
- schema v6 migration과 권한 철회/OS 읽기 실패 시 데이터 보존
- Format, analyze, 전체 79 tests와 Android debug/iOS simulator build 통과

## 9. Phase 7 — Finance

Status: `NEXT`

Tasks:

- 월별 총 지출
- 카테고리별 지출
- 일별 지출
- Finance UI
- Soft-deleted Expense 제외

Expense CRUD를 다시 구현하지 않고 Phase 3 데이터를 집계합니다.

Completion:

- Expense 저장/수정/삭제가 Timeline, Home, Finance에 일관되게 반영됩니다.

## 10. Phase 8 — Me

Status: `TODO`

Tasks:

- Display Language 선택은 Phase 4에서 완료
- App Version
- Open Source Licenses

Theme Selector, Login, Account, Backup/Restore, Notification, App Lock, Cloud Sync, AI 설정을 노출하지 않습니다.

Completion:

- 실제 app version을 표시합니다.
- Open Source Licenses 화면에 접근할 수 있습니다.

## 11. V1 MVP Stabilization

Status: `TODO`

- 전체 사용자 flow 회귀 test
- Migration과 persistence 검증
- Android/iOS build 검증
- 접근성 및 다양한 화면 크기 확인
- README 실행/테스트/빌드 절차 검증
- CHANGELOG 정리
- 안정 릴리스 준비 시 version 검토

## 12. Post-V1

다음 기능은 V1 MVP 구현에 포함하지 않습니다.

- Search
- 독립 Calendar 화면과 양방향 동기화
- Travel
- Event
- 독립 Place
- Backup/Restore
- Login/Account
- Backend
- Cloud Sync
- AI
- Dark Theme 사용자 설정
- Advanced Analytics

이를 위한 UI, table, API, service를 미리 만들지 않습니다.

## 13. Quality Gate

각 Phase 완료 후 가능한 범위에서 실행합니다.

```bash
dart format .
flutter analyze
flutter test
```

필요한 Phase에서는 Android/iOS build도 확인합니다. 테스트 삭제나 analyzer rule 비활성화로 실패를 숨기지 않습니다.

## 14. Documentation Rule

- 구현과 문서를 항상 일치시킵니다.
- 의미 있는 변경을 CHANGELOG의 `Unreleased`에 기록합니다.
- 모든 변경마다 VERSION을 올리지 않습니다.
- 실제 검증된 명령만 README에 기록합니다.
