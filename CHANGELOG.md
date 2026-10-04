# Changelog

MY LIFE의 사용자 또는 개발자에게 의미 있는 변경을 기록합니다.

형식은 Keep a Changelog의 범주를 따르며 버전은 Semantic Versioning을 사용합니다.

## [Unreleased]

### Added

- V1 MVP 요구사항, 아키텍처, 데이터베이스, UI/UX 및 개발 Roadmap 문서
- Flutter 3.47.5 / Dart 3.13.4 기반 `mobile/` 프로젝트
- Riverpod, GoRouter, Drift/SQLite Foundation
- Home, Timeline, Record, Finance, Me navigation shell
- Light Theme, 기본 error logging, AppDatabase 및 Foundation tests
- UUID 기반 Record domain model과 Drift `records` table/schema v2 migration
- Memo 생성, 조회, 수정, soft delete Repository와 Riverpod controller
- Memo 입력/상세 화면, 유효성 검증, fallback label과 삭제 확인 흐름
- Record/Memo domain, Repository, migration, widget flow tests
- Record와 1:1로 저장되는 Drift `expenses` table과 schema v3 migration
- Expense category/payment domain, transaction Repository, Riverpod controller
- Expense 입력·상세·수정·soft delete 화면과 KRW 양의 정수 validation
- Expense persistence, FK, UNIQUE, CHECK, rollback, widget flow tests
- Photo Record 1:N `photos` table과 schema v4 migration
- Camera/Gallery 다중 선택, 순서 확인, 앱 전용 원본·썸네일 저장
- Photo metadata 수정, 개별 삭제, 마지막 사진 및 전체 Record 삭제 흐름
- 한국어/English 앱 현지화와 Me 언어 선택 저장
- active Record의 날짜별 최신순 Timeline과 Memo/Expense/Photo detail 이동
- Timeline 전체/타입/기간 필터와 empty/loading/error 상태
- Timeline repository/filter/widget tests와 실제 실행·테스트 README 안내
- 명시적 권한 후 선택한 기기 일정을 Memo로 가져오는 Calendar Import
- calendar occurrence 중복을 방지하는 `calendar_imports` table과 schema v5 migration
- 선택한 사진의 EXIF 촬영시각·GPS 기반 Photo 날짜·장소 제안

### Changed

- V1 MVP Record Type을 `MEMO`, `EXPENSE`, `PHOTO`로 확정
- Travel을 Record Type이 아닌 향후 Container/Aggregate로 정의
- 단순한 Feature Based Architecture와 Repository 경계를 명확화
- 공식 범위 명칭을 `V1 MVP`로 통일하고 Search/Calendar를 Post-V1로 분리
- V1 MVP 구현 순서를 Foundation부터 Me까지 8개 Phase로 확정
- UI/UX source of truth를 `docs/ui-ux.md`로 확정
- 개발 버전 `0.x.x`와 첫 안정 릴리스 `1.0.0`의 관계를 명확화
- Flutter project name을 `my_life`, Android/iOS 식별자를 `com.mincheol.mylife`로 확정
- Photo Record의 개별 사진 삭제와 실제 앱 관리 파일 정리 정책을 확정
- Calendar 연동을 원본 비수정·수동 실행·단방향 Memo 가져오기로 제한

### Deprecated

- 없음

### Removed

- V1 MVP 범위에서 Search, Calendar, Event, 독립 Place, Travel, Backup/Restore 제거

### Fixed

- 설계 문서 간 V1 MVP 범위와 Phase 중복 정리
- Memo, Expense, Photo 작성 화면에서 진입 경로와 관계없이 표시되는 뒤로가기 동작

### Security

- 없음
