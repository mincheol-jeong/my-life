# MY LIFE — Requirements

## 1. Product Goal

MY LIFE는 사용자의 일상과 추억을 기록하고 시간의 흐름에 따라 다시 확인할 수 있는 개인 생활 기록 애플리케이션입니다.

```text
기록 → 연결 → 검색 → 회고
```

V1 MVP는 빠른 기록, 로컬 보존, Timeline 조회에 집중합니다.

## 2. V1 MVP Scope

V1 MVP에 포함합니다.

- Home
- Timeline
- Record 생성, 조회, 수정, 삭제
- Memo Record
- Expense Record
- Photo Record
- 기본 Finance 집계
- Me 최소 화면
- 한국어 / English 표시 언어 선택
- 로컬 사진 파일 저장
- 사용자가 선택한 기기 캘린더 일정의 Memo 단방향 가져오기
- opt-in Calendar 단방향 자동 반영
- Android 결제 알림 / iOS 단축어 텍스트의 지출 초안과 확인 후 저장
- 선택한 사진의 촬영 날짜·장소 metadata 제안
- Drift/SQLite 기반 Local Storage

V1 MVP Record Type은 다음 세 가지뿐입니다.

```text
MEMO
EXPENSE
PHOTO
```

V1 MVP에서 제외합니다.

- Event
- 독립 Place
- Travel
- Search와 독립 Calendar 화면/양방향 동기화
- Backup/Restore
- Login/Account
- Backend/Cloud Sync/Multi-device Sync
- AI
- Social/Recommendation
- Push Notification
- 환불 및 음수 지출

## 3. Record Model

V1 MVP의 Record는 단일 타입 엔티티입니다. 하나의 Record는 하나의 Record Type만 가집니다.

```text
Record
├── MEMO
├── EXPENSE
└── PHOTO
```

한 Record에 Expense와 Photo를 동시에 직접 연결하는 복합 Record는 V1 MVP에서 구현하지 않습니다.

모든 Record는 다음 공통 정보를 가집니다.

- UUID
- Record Type
- Optional Title
- Optional Content
- 사용자가 기록한 local date
- Optional local time
- Optional place name metadata
- Created/Updated/Deleted system timestamp

타입별 입력 규칙은 다음과 같습니다.

- Memo: title 또는 content 중 하나 이상 필요
- Expense: amount와 category 필요; title은 선택
- Photo: 사진 한 장 이상 필요; title은 선택

화면 표시용 title이 비어 있으면 타입별 fallback label을 사용합니다.

- Memo: content의 첫 번째 유효한 줄 또는 `메모`
- Expense: memo가 있으면 memo, 없으면 category 표시명
- Photo: `사진` 또는 사진 수를 포함한 label

## 4. Home

앱을 열었을 때 현재 기록 상태를 빠르게 확인합니다.

V1 MVP Home에 표시합니다.

- 현재 local date
- 최근 Record
- 이번 달 총 지출
- 최근 Photo Record

최근 Record는 Timeline 정렬을 재사용해 최대 5개, 최근 Photo Record는 최대 6개의 대표 썸네일을 표시합니다. 각 항목에서 타입별 detail로 이동합니다. 이번 달 총 지출은 active Expense의 기록 local date 기준으로 집계하고 저장·수정·삭제 stream을 반영합니다. 오늘 날짜와 집계 월은 자정 및 앱 복귀 시 갱신합니다.

해당 기능의 Phase가 아직 완료되지 않았거나 데이터가 없으면 해당 section의 empty state를 표시합니다.

V1 MVP Home에는 Event 기반 Today 영역과 Travel 카드를 표시하지 않습니다.

## 5. Timeline

Timeline은 모든 활성 Record를 사용자가 기록한 local date/time 기준 최신순으로 표시합니다.

기능:

- 날짜별 그룹화
- Record 상세 이동
- Record 수정
- Record soft delete
- Record Type filter
- Date Range filter
- Empty, Loading, Error state

필터:

```text
전체 | 메모 | 지출 | 사진
```

저장 직후 같은 Repository의 변경 stream을 통해 Timeline과 관련 화면에 반영되어야 합니다.

## 6. Memo Record

입력 항목:

- Optional title
- Optional content
- Local date
- Optional local time
- Optional place name metadata

title과 content를 동시에 비울 수 없습니다.

Memo는 `records` 기본 필드를 사용하며 별도의 `memos` 테이블을 만들지 않습니다.

## 7. Expense Record

입력 항목:

- Amount
- Category
- Payment Method
- Optional memo
- Optional title
- Local date
- Optional local time

기본 통화는 KRW입니다. amount는 원 단위 양의 INTEGER이며 0 이하 값과 floating point를 허용하지 않습니다.

Category:

```text
FOOD
TRANSPORT
SHOPPING
ENTERTAINMENT
TRAVEL
HOUSING
SUBSCRIPTION
OTHER
```

`TRAVEL` category는 지출 분류일 뿐 Travel 기능이나 Record Type을 의미하지 않습니다.

Payment Method:

```text
CASH
CARD
TRANSFER
OTHER
```

Record와 Expense는 1:1입니다. Expense Record 저장·수정 시 `records`와 `expenses` 변경은 하나의 transaction으로 처리합니다.

## 8. Photo Record

Camera 또는 Gallery에서 사진을 추가할 수 있습니다.

하나의 Photo Record는 한 장 이상의 사진을 가지며 여러 사진을 가질 수 있습니다.

```text
Record 1 ─── N Photo
```

- 사진 바이너리는 SQLite에 저장하지 않습니다.
- 선택한 사진은 앱의 영구 private storage로 복사합니다.
- DB에는 앱 storage root 기준 relative path와 metadata만 저장합니다.
- 원본 URI나 임시 gallery path를 영구 경로로 사용하지 않습니다.
- 가능한 경우 thumbnail을 우선 표시합니다.
- 사용자가 선택한 첫 사진에 EXIF 촬영 시각이 있으면 Photo 작성 날짜/시간의 초기값으로 제안합니다.
- EXIF GPS가 있으면 OS reverse geocoder로 장소명을 제안하고 실패 시 좌표를 제안합니다.
- 자동 입력값은 저장 전에 사용자가 확인·수정할 수 있고 metadata가 없어도 수동 입력이 동작합니다.

개별 사진 삭제를 지원합니다.

- 해당 photo metadata와 앱 전용 저장소의 관리 파일을 삭제합니다.
- 같은 Photo Record의 다른 사진은 유지합니다.
- 사용자가 소유한 원본 Gallery 사진은 삭제하지 않습니다.
- 마지막 사진 삭제 시 사용자 확인 후 Photo Record 전체를 삭제합니다.

## 9. Device Calendar Import

- Me에서 사용자가 직접 시작하고 OS calendar full-access 권한을 명시적으로 허용합니다.
- 사용자가 캘린더와 포함 기간을 선택합니다.
- 선택한 일정은 기존 `MEMO` Record로 한 번 가져오며 원본 캘린더를 생성·수정·삭제하지 않습니다.
- 일정 title, description, 시작 local date/time, location을 Memo 필드로 변환합니다.
- 반복 일정은 occurrence 단위 external instance ID로 중복 가져오기를 방지합니다.
- 이미 가져온 일정과 title/content가 모두 빈 일정은 건너뜁니다.
- 자동 반영을 켜면 선택한 캘린더와 고정 기간을 저장하고 앱 실행·복귀 시와 사용 중 5분마다 OS 내용을 다시 읽습니다. 앱 종료 중 background 실행은 보장하지 않습니다.
- 원본 추가·수정·삭제를 Memo에 반영합니다. 마지막 원본 snapshot과 다른, 직접 수정한 Memo는 덮어쓰거나 삭제하지 않고 보호 수를 표시합니다. 앱에서 삭제한 Memo는 다시 생성하지 않습니다.
- source 삭제로 soft delete된 Memo도 같은 occurrence ID로 자동 복원하지 않습니다. V1에는 Restore가 없습니다.
- 권한 거부/철회, OS 읽기 실패, 선택한 캘린더에 접근할 수 없는 경우 기존 기록을 삭제하지 않습니다. 자동 반영은 언제든 끌 수 있습니다.
- 반복 occurrence ID가 시작 시각 변경으로 바뀌면 기존 untouched occurrence를 삭제하고 새 occurrence로 가져올 수 있습니다.
- 양방향 sync와 앱 내부 Event/Calendar 화면은 제공하지 않습니다.

### Payment Import

- Me → 지출 가져오기에서 명시적으로 연결을 켭니다. 기본값은 꺼짐입니다.
- Android는 OS 알림 접근 설정을 사용자가 허용하고 선택한 설치 앱의 새 결제 알림만 로컬 native queue로 받습니다. 알림 권한은 전체 알림 접근 권한임을 설명합니다. 과거 카드 내역 조회는 아닙니다.
- iOS는 사용자가 설정한 Shortcuts 자동화가 `mylife://payment-import?source=...&text=<URL encoded text>&id=<optional event ID>`로 텍스트를 전달합니다. MY LIFE는 다른 앱 알림을 직접 읽지 않습니다. iOS 27 앱 알림 trigger의 텍스트 전달 가능 여부는 실기기에서 검증합니다. 메시지 수신 자동화도 전달 adapter로 사용할 수 있습니다.
- 양의 KRW 승인/결제 텍스트만 보수적으로 해석합니다. 금액 후보가 모호하거나 취소·환불·충전·입금·이체·청구·해외 통화 등은 제외합니다. 카드 네 종류의 실제 텍스트 호환성을 보장하지 않으며 은행 login/API, SMS 직접 읽기, 네트워크 전송은 추가하지 않습니다.
- 금액·날짜·시간을 제안하고 카테고리는 OTHER로 시작합니다. 가맹점/분류는 원문을 보고 직접 확인합니다. 날짜가 없으면 수신 시각을 제안합니다.
- 미확인 초안은 Home/Finance 지출에 포함하지 않습니다. 기존 Expense form에서 확인·수정 후 transaction으로 Expense와 처리 mapping을 저장합니다.
- 동일 source/external ID를 다시 가져오지 않습니다. 서로 다른 알림·앱의 동일 결제를 자동으로 같은 거래로 단정하지 않습니다. iOS에서 안정된 ID를 전달하지 않은 별도 호출은 별도 초안이 될 수 있습니다.
- 저장/버리기 후 원문은 지우고 중복 방지 mapping은 보존합니다. 연결을 끄면 native 대기 queue를 지우고 새 수집을 중단합니다. 이미 SQLite에 들어온 초안은 개별로 버릴 수 있습니다.
- 취소 알림으로 기존 Expense를 자동 취소하지 않습니다. 사용자가 기존 지출을 삭제/수정합니다. 환불·음수 지출은 기존 V1 범위와 동일하게 제외합니다.

## 10. Finance

V1 MVP Finance는 Expense Record를 집계합니다.

- 월별 총 지출 (기본 이번 달, 이전/다음 월과 이번 달로 돌아가기)
- 카테고리별 지출
- 일별 지출

집계 기준은 Record의 local date이며 soft-deleted Expense와 미확인 결제 초안은 제외합니다. 지출이 있는 카테고리/날짜만 표시하며 카테고리는 합계 내림차순(동률은 enum 순), 일별은 날짜 최신순입니다. 총액과 두 분류 합계는 일치해야 하며 생성·수정·삭제가 stream으로 반영됩니다. 기본 월은 자정/앱 복귀 시 갱신하고 사용자가 조회 중인 월은 유지합니다.

차트는 필수 요구사항이 아닙니다. 숫자와 간단한 목록을 우선합니다.

기본 통화 KRW만 표시하며 다중 통화는 V1 MVP에서 지원하지 않습니다.

## 11. Me

V1 MVP Me 화면에는 다음만 표시합니다.

- Display Language: 한국어 / English
- App Version
- Open Source Licenses
- Device Calendar Import 진입점
- Payment Import 진입점
- 로컬 보관과 백업/기기 동기화 미지원·앱 삭제/초기화/기기 분실의 데이터 유실 위험 안내

선택한 언어는 로컬 환경설정에 저장하고 앱 재실행 후에도 유지합니다. 초기값은 한국어입니다.

언어 저장 실패 시 이전 언어/선택으로 복귀하고 사용자 언어의 안내를 표시합니다. 버전은 native 설치 패키지의 version/build에서 읽으며 실패 시 재시도를 제공합니다. 라이선스는 Flutter의 실제 bundled LicenseRegistry를 표시합니다.

Theme Selector, Login, Account, Backup/Restore, Notification, App Lock, Cloud Sync와 AI 설정은 노출하지 않습니다.

## 12. Delete

Record 삭제는 `deleted_at` 기반 soft delete입니다.

- 기본 조회와 집계에서 삭제된 Record를 제외합니다.
- Expense Record soft delete 시 종속 Expense row는 보존합니다.
- Photo Record 전체 삭제 시 Record에는 `deleted_at`을 기록하고 연결된 Photo metadata, thumbnail 및 앱 관리 사진 파일은 정리합니다.
- V1 MVP에는 Trash, Restore, 자동 영구 삭제를 제공하지 않습니다.

## 13. Date and Time

System timestamp와 Life Event Time을 구분합니다.

### System Timestamp

`created_at`, `updated_at`, `deleted_at`은 UTC Unix epoch milliseconds로 저장합니다.

### Life Event Time

- local date는 `YYYY-MM-DD` calendar date로 보존합니다.
- local time은 선택 값이며 자정 이후 경과 분으로 저장합니다.
- timezone 변환으로 Timeline의 기록 날짜를 변경하지 않습니다.
- 날짜만 입력한 Record는 임의의 00:00 UTC instant로 해석하지 않습니다.

## 14. Offline First

V1 MVP의 Record 생성, 수정, 삭제, 조회와 Finance 집계는 네트워크 없이 동작해야 합니다.

SQLite가 유일한 source of truth이며 UI는 Repository가 제공하는 상태 또는 stream을 구독합니다.

Calendar와 Photo metadata는 opt-in 기기 입력입니다. Calendar 자동 반영은 기기의 캘린더 저장소만 읽으며 가져온 Memo/Photo Record는 SQLite에서 offline으로 동작합니다. Payment도 기기의 알림/단축어 입력을 확인한 뒤 로컬 Expense로 저장합니다. Reverse geocoding이 실패해도 GPS 좌표 또는 수동 입력으로 계속할 수 있습니다.

## 15. V1 MVP Success Criteria

```text
앱 실행
 ↓
Home
 ↓
+ Record
 ↓
Memo / Expense / Photo 선택
 ↓
입력 및 저장
 ↓
Timeline에서 확인
 ↓
앱 재실행
 ↓
데이터와 사진 유지
```

Expense는 Timeline과 Finance에 일관되게 반영되어야 합니다.

## 16. Post-V1 Scope

### Search / Calendar

- title, content, expense memo, place name text search
- Calendar view
- Advanced date navigation

### Event / Place

V1 MVP 이후 해당 Phase에서 데이터 모델과 UI를 다시 설계합니다. V1 MVP에는 `events`, `places` 테이블을 만들지 않습니다.

### Travel

Travel은 Record Type이 아니라 여러 Record를 묶는 Container/Aggregate입니다.

```text
Travel
├── Memo Record
├── Expense Record
├── Photo Record
└── Future Record Types
```

### Backup / Cloud Sync / AI

Backup 이후 Cloud Sync, AI 순서로 확장합니다. Cloud Sync가 실제로 시작될 때 conflict와 remote data source를 설계합니다.

### Approved Post-V1 Planning

회원 관리와 수익화는 후속 제안 문서로 추가합니다. [회원 정보 관리](accounts.md), [수익화 계획](monetization.md). 현재 V1 Scope 변경이나 구현 승인이 아니며, 회원가입/Cloud 동의 분리와 기록 조회·삭제 보존을 제안합니다.

## 17. V1 MVP Out of Scope

- SNS와 친구 기능
- 공개 프로필
- 광고와 MY LIFE 상품 결제 (Post-V1 계획만 존재)
- 커뮤니티
- 추천 알고리즘
- 과도한 gamification
