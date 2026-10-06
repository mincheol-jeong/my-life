# MY LIFE — Database Design

## 1. Scope

V1 MVP는 Drift를 통해 로컬 SQLite에 접근합니다.

V1 MVP 실제 table은 다음 다섯 개입니다.

```text
records
expenses
photos
calendar_imports
payment_imports
```

`events`, `places`, `trips`, `trip_records`, user 또는 sync table은 V1 MVP schema와 migration에 포함하지 않습니다.

`records`, `expenses`, `photos`, `calendar_imports`, `payment_imports`가 실제 구현되었습니다.

## 2. Principles

1. SQLite가 V1 MVP의 유일한 source of truth입니다.
2. UI는 AppDatabase에 직접 접근하지 않습니다.
3. UUID TEXT primary key를 사용합니다.
4. Foreign key enforcement를 활성화합니다.
5. Record는 `deleted_at` 기반 soft delete를 사용합니다.
6. System timestamp와 사용자가 기록한 local date/time을 분리합니다.
7. 사진 바이너리는 SQLite에 저장하지 않습니다.
8. schema 변경은 versioned migration으로 수행합니다.

## 3. Record Invariants

V1 MVP Record는 정확히 하나의 타입을 가집니다.

| Record type | Required storage |
| --- | --- |
| `MEMO` | `records` row만 사용 |
| `EXPENSE` | `records` row와 정확히 하나의 `expenses` row |
| `PHOTO` | `records` row와 한 개 이상의 `photos` row |

Repository transaction이 이 불변식을 보장합니다. V1 MVP는 한 Record에 Expense와 Photo를 동시에 연결하지 않습니다.

## 4. Date and Time Storage

### System Timestamp

`created_at`, `updated_at`, `deleted_at`은 UTC Unix epoch milliseconds를 `INTEGER`로 저장합니다.

- `created_at`: 생성 시각, 변경하지 않음
- `updated_at`: Record 또는 subtype data가 변경될 때 갱신
- `deleted_at`: 활성 Record는 NULL, soft-deleted Record는 삭제 UTC timestamp

### Life Event Time

Timeline의 날짜가 timezone 변환으로 바뀌지 않도록 local calendar 값을 보존합니다.

- `event_date`: `TEXT NOT NULL`, `YYYY-MM-DD`
- `event_time_minutes`: `INTEGER NULL`, local midnight 이후 0–1439분

날짜만 입력한 Record는 `event_time_minutes = NULL`입니다. 이를 임의의 UTC instant로 변환하지 않습니다.

## 5. `records`

모든 V1 MVP Record의 공통 정보를 저장합니다.

| Column | SQLite type | Nullable | Constraint / Meaning |
| --- | --- | ---: | --- |
| `id` | TEXT | NO | PK, UUID |
| `type` | TEXT | NO | `MEMO`, `EXPENSE`, `PHOTO` 중 하나 |
| `title` | TEXT | YES | Optional user title |
| `content` | TEXT | YES | Memo content 또는 공통 설명 |
| `event_date` | TEXT | NO | Local calendar date |
| `event_time_minutes` | INTEGER | YES | 0–1439 |
| `place_name` | TEXT | YES | Optional metadata, 독립 Place가 아님 |
| `created_at` | INTEGER | NO | UTC epoch milliseconds |
| `updated_at` | INTEGER | NO | UTC epoch milliseconds |
| `deleted_at` | INTEGER | YES | Soft-delete tombstone |

Constraints:

- `CHECK(type IN ('MEMO', 'EXPENSE', 'PHOTO'))`
- `CHECK(event_time_minutes IS NULL OR event_time_minutes BETWEEN 0 AND 1439)`
- Memo의 title/content 규칙과 subtype 존재 규칙은 Repository validation 및 transaction test로 보장합니다.

title이 NULL이어도 허용합니다. 화면은 Requirements의 타입별 fallback label을 사용합니다.

## 6. `expenses`

Expense Record의 subtype data를 저장합니다.

| Column | SQLite type | Nullable | Constraint / Meaning |
| --- | --- | ---: | --- |
| `id` | TEXT | NO | PK, UUID |
| `record_id` | TEXT | NO | FK → `records.id`, UNIQUE |
| `amount` | INTEGER | NO | KRW 원 단위, 양수 |
| `category` | TEXT | NO | 정의된 category enum |
| `payment_method` | TEXT | NO | 정의된 payment enum |
| `memo` | TEXT | YES | Optional expense memo |

Constraints:

- `UNIQUE(record_id)`로 Record 1:1을 보장합니다.
- `FOREIGN KEY(record_id) REFERENCES records(id) ON DELETE CASCADE`
- `CHECK(amount > 0)`
- Category와 Payment Method는 정의된 enum 값만 허용합니다.

Record soft delete 시 Expense row는 보존됩니다. 실제 hard purge가 Post-V1에 추가되면 `ON DELETE CASCADE`가 종속 row를 제거합니다.

Expense subtype 수정 시 parent `records.updated_at`도 같은 transaction에서 갱신합니다.

## 7. `photos`

Photo Record에 연결된 사진 metadata를 저장합니다.

| Column | SQLite type | Nullable | Constraint / Meaning |
| --- | --- | ---: | --- |
| `id` | TEXT | NO | PK, UUID |
| `record_id` | TEXT | NO | FK → `records.id` |
| `file_path` | TEXT | NO | App storage root 기준 relative path |
| `thumbnail_path` | TEXT | YES | Relative thumbnail path |
| `width` | INTEGER | YES | Positive pixel width |
| `height` | INTEGER | YES | Positive pixel height |
| `sort_order` | INTEGER | NO | Record 내 표시 순서, 0 이상 |

Constraints:

- `FOREIGN KEY(record_id) REFERENCES records(id) ON DELETE CASCADE`
- `CHECK(width IS NULL OR width > 0)`
- `CHECK(height IS NULL OR height > 0)`
- `CHECK(sort_order >= 0)`
- `UNIQUE(record_id, sort_order)`

Photo Record는 한 개 이상의 photo row를 가져야 합니다. 생성과 수정은 transaction으로 처리하여 빈 Photo Record가 만들어지지 않게 합니다.

개별 사진 삭제 시 해당 `photos` row를 hard delete하고 앱 관리 원본과 thumbnail 파일을 삭제합니다. 마지막 photo row는 사용자 확인 없이 삭제할 수 없습니다. 확인 후 parent Photo Record 전체 삭제 절차를 사용합니다.

## 8. Relationships

```text
records (MEMO)
    └── subtype table 없음

records (EXPENSE) 1 ─── 1 expenses

records (PHOTO)   1 ─── N photos

records (MEMO imported from calendar) 1 ─── 1 calendar_imports
```

## 9. `calendar_imports`

기기 캘린더에서 Memo로 가져온 occurrence의 중복 방지 정보만 저장합니다. 캘린더 내용을 복제하는 Event table이 아닙니다.

| Column | SQLite type | Nullable | Constraint / Meaning |
| --- | --- | ---: | --- |
| `record_id` | TEXT | NO | PK, FK → `records.id` |
| `calendar_id` | TEXT | NO | OS calendar identifier |
| `external_instance_id` | TEXT | NO | 단일/반복 일정 occurrence identifier |
| `imported_at` | INTEGER | NO | UTC epoch milliseconds |
| `source_snapshot` | TEXT | YES | 마지막 원본 Memo 필드 JSON; local 수정 보호 비교 기준 |

`UNIQUE(calendar_id, external_instance_id)`로 같은 occurrence의 중복 가져오기를 방지합니다. Record를 soft delete해도 mapping은 보존하여 사용자가 삭제한 일정을 다시 가져오지 않습니다.

자동 반영은 원본 snapshot과 현재 Record의 필드를 비교하여 local 수정 여부를 판단합니다. 기존 v5 mapping의 snapshot이 NULL이면 `updated_at == imported_at`인 경우에만 갱신하고 snapshot을 초기화합니다. 원본 삭제는 선택한 기간/접근 가능한 캘린더의 완전한 읽기가 성공했을 때만 반영합니다.

### `payment_imports`

| Column | Type | Meaning |
| --- | --- | --- |
| `id` | TEXT PK | UUID |
| `source` | TEXT NOT NULL | Android package 또는 단축어 source |
| `external_id` | TEXT NOT NULL | 알림 key/postTime 또는 단축어의 전달 ID |
| `raw_text` | TEXT NOT NULL | 미확인 원문; 저장/버리기 후 빈 문자열 |
| `received_at` | INTEGER NOT NULL | UTC epoch milliseconds |
| `record_id` | TEXT nullable FK | 확인 후 저장된 Expense Record |
| `dismissed_at` | INTEGER nullable | 버린 시각, UTC epoch milliseconds |

`UNIQUE(source, external_id)`는 동일 handoff의 재수신을 막습니다. `record_id IS NULL AND dismissed_at IS NULL`인 row만 미확인으로 조회합니다. 확인은 Record/Expense 생성과 mapping 갱신을 같은 transaction으로 처리합니다. 저장 전에는 Expense가 없으므로 Home/Finance 합계에 영향을 주지 않습니다. 기존 Record 삭제 후에도 mapping을 보존합니다.

Android/iOS private native preferences의 입력 handoff queue는 최대 100개이며 7일 이내 항목만 읽습니다. Drift ingest 성공 이후에만 acknowledge하며 실패한 작업은 다음 실행에서 재시도합니다. SQLite에 가져온 초안은 사용자가 처리할 때까지 보존합니다.

## 10. Indexes

Primary/unique constraint가 만드는 index 외에 다음 query index를 사용합니다.

- Active Timeline: `records(event_date DESC, event_time_minutes DESC, created_at DESC)` where `deleted_at IS NULL`
- Type filter: `records(type, event_date DESC, event_time_minutes DESC)` where `deleted_at IS NULL`
- Expense aggregation: `expenses(category)`
- Photo ordering: `photos(record_id, sort_order)`; unique constraint로 충족 가능

Finance query는 `expenses`와 active `records`를 join하고 `records.event_date`로 월/일 범위를 제한합니다. 실제 query plan을 test/profile한 뒤 불필요하거나 중복된 index를 추가하지 않습니다.

Phase 7은 선택한 월의 `[월 시작, 다음 월 시작)` 범위에서 `event_date, category` GROUP BY와 INTEGER SUM을 사용합니다. 같은 query 결과에서 월 총액과 카테고리/일별 합계를 구성하므로 조회 시점 차이에 따른 합계 불일치를 피합니다. `type = EXPENSE`, `deleted_at IS NULL`을 적용하며 미확인 payment mapping은 join하지 않습니다. schemaVersion은 6으로 유지합니다.

## 11. Delete Policy

V1 MVP의 Record 삭제는 다음 transaction으로 처리합니다.

1. `records.deleted_at`을 현재 UTC epoch milliseconds로 설정합니다.
2. `records.updated_at`을 같은 값으로 갱신합니다.
3. Expense Record이면 Expense row를 보존합니다.
4. Photo Record이면 연결된 Photo metadata row를 삭제하고 앱 관리 원본/thumbnail 파일을 정리합니다.

모든 기본 Timeline, Home, Finance query는 `deleted_at IS NULL` 조건을 적용합니다.

V1 MVP에는 Trash, Restore, background purge가 없습니다. 일반 Record와 Expense Record는 subtype data를 보존하지만, Photo는 저장 공간과 사용자 의도에 맞춰 개별/전체 삭제 시 앱이 관리하는 파일과 metadata를 즉시 정리합니다. Gallery의 사용자 원본은 삭제하지 않습니다.

## 12. Photo File Policy

- 동일 Photo Record의 수정·개별/전체 삭제는 Repository에서 직렬화합니다. 개별 삭제 transaction 안에서 active Record와 남은 사진 수를 재검증해 빈 active Photo Record를 만들지 않습니다.
- Camera/Gallery 결과의 임시 URI를 DB에 직접 저장하지 않습니다.
- 앱의 영구 private storage에 복사하고 앱 storage root 기준 relative path를 저장합니다.
- DB insert 전에 파일 복사를 완료합니다.
- DB transaction 실패 시 이번 작업에서 생성한 파일을 정리합니다.
- 파일 복사 실패 시 Record와 photo row를 저장하지 않습니다.
- 앱 storage 위치가 바뀌어도 relative path를 새 root와 결합할 수 있어야 합니다.
- 개별 사진 삭제는 앱 관리 파일을 임시 영역에 staging하고 metadata row 삭제 transaction 성공 후 파일 삭제를 확정합니다. transaction 실패 시 파일을 복원합니다.
- 파일 삭제가 실패하면 사용자에게 실패를 알리고 Repository가 metadata 복구 또는 재시도 가능한 일관된 상태를 유지합니다.
- 마지막 사진 삭제는 사용자 확인 후 Photo Record의 `deleted_at` 설정, 모든 photo metadata 삭제, 앱 관리 파일 삭제를 하나의 Repository operation으로 조정합니다.
- Gallery에서 가져온 사용자 원본은 절대 삭제하지 않습니다.
- 파일 삭제 전 앱 photo root의 `.trash/<token>/manifest.json`에 이동 의도를 flush한 뒤 rename합니다. 다음 앱 실행의 첫 사진 접근/쓰기에서 active DB path를 기준으로 참조 파일은 원위치로 복구하고, 삭제가 DB에 반영된 staged 파일은 정리합니다. 이는 사용자용 Trash/Restore가 아니라 중단 작업 복구입니다.
- DB에 없는 app-managed Record directory는 중단된 생성의 잔여물로 정리합니다. 현재 앱은 단일 PhotoRepository 인스턴스로 초기 복구를 직렬화합니다.
- manifest가 없거나 알 수 없는 기존 `.trash` 폴더는 추측으로 삭제하지 않습니다. 손상된 manifest/기존 파일과 충돌하면 자동 덮어쓰기하지 않고 실패를 반환합니다. 모든 관리 경로는 app photo root 밖으로 나가지 못하도록 제한합니다.

## 13. Migration and `schemaVersion`

- `AppDatabase.schemaVersion`은 양의 정수로 시작합니다.
- schema가 변경될 때마다 증가시킵니다.
- 각 이전 version에서 다음 version으로 가는 migration path를 유지합니다.
- migration은 table/column/index/constraint 변경과 필요한 data backfill을 포함합니다.
- 기존 DB 삭제 또는 무조건 재생성으로 migration을 대신하지 않습니다.
- 새 설치 schema test와 지원하는 이전 schema의 upgrade test를 작성합니다.
- migration 완료 후 foreign key check와 핵심 query를 검증합니다.

Current migration history:

| schemaVersion | Change |
| ---: | --- |
| 1 | AppDatabase와 migration 기반 |
| 2 | `records` table, Record constraint, active Timeline/type partial index |
| 3 | `expenses` table, Record FK/UNIQUE, amount/category/payment constraint, category index |
| 4 | `photos` table, Record FK, record/sort order UNIQUE, dimension/order constraint |
| 5 | `calendar_imports` table, imported occurrence UNIQUE와 Record FK |
| 6 | `payment_imports` table과 `calendar_imports.source_snapshot` |

현재 `AppDatabase.schemaVersion`은 `6`입니다. 새 설치 schema와 version 1/2/3/4/5에서 version 6 upgrade를 test합니다.

## 14. Post-V1 Architecture

- Event와 독립 Place는 해당 Phase에서 새로 설계합니다.
- Travel은 여러 Record를 묶는 Container/Aggregate이며 Record Type이 아닙니다.
- Cloud Sync 전에 conflict policy, remote revision, attachment tombstone과 purge 정책을 추가 migration으로 설계합니다.
- Post-V1 table은 V1 MVP schema에 미리 만들지 않습니다.
