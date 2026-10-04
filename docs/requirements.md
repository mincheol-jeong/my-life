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
- 자동/background sync, 양방향 sync와 앱 내부 Event/Calendar 기능은 제공하지 않습니다.

## 10. Finance

V1 MVP Finance는 Expense Record를 집계합니다.

- 이번 달 총 지출
- 카테고리별 지출
- 일별 지출

차트는 필수 요구사항이 아닙니다. 숫자와 간단한 목록을 우선합니다.

기본 통화 KRW만 표시하며 다중 통화는 V1 MVP에서 지원하지 않습니다.

## 11. Me

V1 MVP Me 화면에는 다음만 표시합니다.

- Display Language: 한국어 / English
- App Version
- Open Source Licenses
- Device Calendar Import 진입점

선택한 언어는 로컬 환경설정에 저장하고 앱 재실행 후에도 유지합니다. 초기값은 한국어입니다.

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

Calendar와 Photo metadata는 사용자가 요청한 시점의 가져오기 입력일 뿐입니다. 가져온 Memo/Photo Record는 이후 SQLite에서 offline으로 동작합니다. Reverse geocoding이 실패해도 GPS 좌표 또는 수동 입력으로 계속할 수 있습니다.

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

## 17. Out of Scope

- SNS와 친구 기능
- 공개 프로필
- 광고와 결제
- 커뮤니티
- 추천 알고리즘
- 과도한 gamification
