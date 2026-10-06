# Changelog

MY LIFE의 사용자 또는 개발자에게 의미 있는 변경을 기록합니다.

형식은 Keep a Changelog의 범주를 따르며 버전은 Semantic Versioning을 사용합니다.

## [Unreleased]

### Added

- Phase 8 Me의 실제 Android/iOS version/build, 라이선스 목록/본문과 로컬 보관·백업 미지원 안내
- 사진 삭제 journal과 다음 사진 접근/쓰기 시 DB 기준 중단 복구, 미저장 앱 전용 사진 잔여물 정리
- Me 6개, 사진 실패/중단 복구 6개, 좁은 화면·큰 글자·키보드 입력 접근 3개의 추가 테스트
- Android signing 설정 예제와 회사 실기기/업데이트/스토어 배포 체크리스트
- Post-V1 회원 정보 관리와 수익화 제안 문서 (계정/결제 구현과 가격 확정 없음)
- Phase 7 Finance 월별 총액, 카테고리별·일별 지출과 이전/다음 월·이번 달 복귀
- Finance 한국어/English, empty/loading/error·재시도와 기본 월 자정/앱 복귀 갱신
- Finance 집계·월 선택·화면 회귀 테스트 17개와 README 수동 테스트 안내
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
- Home의 오늘 날짜, 최근 기록 5개, 이번 달 총 지출, 최근 사진 기록 6개 대표 썸네일
- Home section별 empty/loading/error·재시도, 타입별 detail 이동, 자정/앱 복귀 날짜 갱신
- Home 월 경계·soft delete·실시간 변경·사진 join limit·화면 흐름 테스트
- Android 선택 앱 결제 알림 수집과 iOS 단축어 URL 텍스트 handoff
- Me 지출 가져오기, 미확인 초안 검토/버리기, 확인 후 Expense transaction 저장
- Calendar opt-in 단방향 자동 반영, 원본 snapshot 기반 local 수정 보호
- schema v6 payment mapping/source snapshot과 기존 DB 보존 migration

### Changed

- 안정화 변경사항 커밋을 위해 개발 버전을 `0.1.1+2`로 증가 (정식 릴리스 아님; 실기기·서명 검증 미완료)
- 입력창·기록 card·사진 thumbnail·dialog·bottom sheet 모서리를 둥글게 통일하고 입력 테두리를 공통 Theme으로 관리
- Record 입력 화면의 공통 표시/뒤로가기, 날짜·시간·KRW formatter와 Home/Finance 날짜 갱신을 통합
- Timeline을 ListView.builder로 변경 (DB pagination은 미적용)
- 사용자 지시에 따라 커밋마다 기본 PATCH/build number 증가 및 앱·VERSION·README 일치 정책으로 변경
- Architecture/Design의 Record 관계, Repository 경계, V1 기술·navigation과 Post-V1 구분 정리
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
- Calendar 연동을 원본 비수정 상태로 유지하며 선택 기간의 foreground 자동 반영을 opt-in 확장

### Deprecated

- 없음

### Removed

- 미사용 SectionPlaceholder widget과 AppLogger.info 제거
- V1 MVP 범위에서 Search, Calendar, Event, 독립 Place, Travel, Backup/Restore 제거

### Fixed

- 지출 상세의 뒤로가기와 별개로 항상 Home으로 이동하는 홈 버튼 제공
- Memo/Expense/Photo 저장 후 상세 화면의 이동 버튼 누락 수정: 이전 화면으로 돌아가기 또는 Home fallback 제공
- Memo/Expense/Photo 저장 중 화면 종료 시 disposed controller 접근과 중복 제출
- 사진 동시 삭제로 마지막 사진 조건이 깨지는 경합과 삭제 중 반복 입력
- 늦게 도착한 사진 metadata가 수동 입력 또는 변경된 첫 사진의 제안을 덮어쓰는 문제
- 캘린더 설정 저장 실패 시 기존 설정 복원·오류 안내 및 겹치는 자동 반영 요청
- 음수/부호가 있는 결제 금액을 양수 지출로 오인하는 parser 문제
- 위 오류와 공통 formatter 회귀 테스트 19개 추가 (전체 130개 통과)
- 언어 설정 저장 실패 시 이전 선택 복원과 오류 안내, 언어/지출 dropdown의 큰 글자 가로 넘침
- 설계 문서 간 V1 MVP 범위와 Phase 중복 정리
- Memo, Expense, Photo 작성 화면에서 진입 경로와 관계없이 표시되는 뒤로가기 동작

### Security

- Android release의 debug 서명 fallback 제거와 인증서 설정 누락 시 명시적 실패
- 앱 관리 사진 경로의 저장소 밖 접근 차단
