# MY LIFE — UI / UX Design

## 1. Design Goal

```text
Minimal
Personal
Warm
Calm
Premium
```

개인 생활 기록 앱으로 느껴져야 하며 업무용 Dashboard처럼 보이지 않아야 합니다.

## 2. Mobile and Accessibility

- Android와 iOS 모바일 화면을 우선합니다.
- 한 손으로 주요 기록 흐름을 완료할 수 있어야 합니다.
- 충분한 터치 영역과 색상 대비를 제공합니다.
- Icon만으로 의미를 전달하지 않습니다.
- 시스템 font scale과 다양한 화면 크기에 대응합니다.

## 3. Main Navigation

Bottom Navigation을 사용합니다.

```text
Home | Timeline | + Record | Finance | Me
```

중앙 Record 버튼은 일반 tab content가 아니라 빠른 기록 진입점으로 동작할 수 있습니다.

MVP navigation에는 Event, Place, Travel을 노출하지 않습니다.

## 4. Home

MVP Home은 현재 구현된 데이터만 사용합니다.

```text
┌─────────────────────────────┐
│ MY LIFE                     │
│ 2026.09.29                  │
│                             │
│ 이번 달 지출               │
│ ₩1,243,000                  │
│                             │
│ 최근 기록                  │
│ 📝 오늘 있었던 일          │
│ 💰 스타벅스                │
│ 📷 주말 사진               │
│                             │
│ 최근 사진                  │
│ [thumbnail] [thumbnail]     │
└─────────────────────────────┘
```

- Expense 또는 Photo Phase 전에는 해당 section을 숨기거나 명확한 empty state로 표시합니다.
- Event 기반 Today 영역과 Travel 카드는 MVP 필수 UI에 포함하지 않습니다.
- 최근 Record 선택 시 해당 타입의 detail로 이동합니다.
- 최근 Record는 Timeline과 같은 local date/time 최신순으로 최대 5개를 표시합니다.
- 최근 사진은 같은 정렬 기준의 Photo Record 최대 6개에서 첫 사진을 대표 썸네일로 표시하고, 선택 시 Photo detail로 이동합니다.
- 이번 달 지출은 삭제되지 않은 Expense의 기록 local date 기준으로 합산합니다. 지출이 없으면 `₩0`과 empty 안내를 표시합니다.
- 기록·지출·사진 영역은 각각 loading/error/retry 상태를 제공하며 다른 영역을 가리지 않습니다.
- 기록이 없으면 기록하기 진입점을 제공합니다. 사진 파일을 표시하지 못하면 대체 이미지를 표시하고 detail 이동은 유지합니다.
- 자정 및 앱 복귀 시 오늘 날짜와 집계 월을 갱신합니다.

## 5. Record Creation

중앙 `+`를 누르면 Bottom Sheet를 표시합니다.

```text
┌─────────────────────────────┐
│ 무엇을 기록할까요?          │
│                             │
│ [📝 메모] [💰 지출]        │
│ [📷 사진]                   │
└─────────────────────────────┘
```

V1 MVP에는 Memo, Expense, Photo만 표시합니다. 현재 Phase에서 구현된 Record Type만 활성 상태로 노출합니다.

```text
App Start
   ↓
Home
   ↓
Record (+)
   ↓
Memo / Expense / Photo
   ↓
Input
   ↓
Save
   ↓
Timeline
```

## 6. Timeline

사용자가 기록한 local date별로 그룹화하고 최신순으로 표시합니다.

```text
[전체] [메모] [지출] [사진]   [기간]

2026.09.29
────────────────────
📝 오늘 있었던 일

💰 식비
₩45,000

📷 주말 사진 · 3장
```

- Filter는 전체, 메모, 지출, 사진만 제공합니다.
- Date Range Filter는 시작일과 종료일을 포함하는 범위로 적용하며 선택을 해제할 수 있습니다.
- 서로 다른 타입의 Record를 하나의 복합 card로 합치지 않습니다.
- 같은 날짜에서 time이 있는 Record는 time 내림차순, time이 없는 Record는 일관된 보조 정렬 기준을 사용합니다.

## 7. Memo Input and Detail

입력:

- Optional title
- Optional content
- Date
- Optional time
- Optional place name

title과 content 중 하나는 필요합니다.

Detail은 Memo 정보만 표시하며 연결된 Expense나 Photo를 표시하지 않습니다.

Memo/Expense/Photo 상세 화면은 저장 후에도 상단 왼쪽 이동 버튼을 항상 표시합니다. 이전 화면이 있으면 뒤로 돌아가고, 저장 후 직접 진입처럼 이전 화면이 없으면 Home으로 이동합니다. 조회 중·오류·기록 없음 상태에서도 동일하게 제공합니다. 수정/삭제 버튼은 유지합니다.

## 8. Expense Input and Detail

```text
┌─────────────────────────────┐
│ 지출                        │
│                             │
│ 금액          ₩ 45,000     │
│ 카테고리      식비          │
│ 결제 방법     카드          │
│ 메모          저녁 식사     │
│ 제목          선택          │
│ 날짜          2026.09.29    │
│ 시간          선택          │
│                             │
│             [저장]          │
└─────────────────────────────┘
```

- 금액은 원 단위 양의 정수만 받습니다.
- title은 필수가 아닙니다.
- Timeline/detail label은 title, memo, category 순으로 fallback합니다.
- Expense detail에는 Expense 정보만 표시합니다.
- Expense 상세에는 왼쪽 뒤로가기와 별도의 홈 버튼을 함께 표시합니다. 홈 버튼은 이전 화면 유무와 관계없이 Home으로 이동하며 조회 중·오류·기록 없음 상태에도 표시합니다.

## 9. Photo Input and Detail

- Camera 촬영 또는 Gallery 선택을 제공합니다.
- 한 Photo Record에 여러 사진을 선택할 수 있습니다.
- 저장 전 선택 목록과 순서를 확인할 수 있습니다.
- 썸네일을 우선 표시하고 원본은 detail에서 로드합니다.
- Photo detail에는 Photo Record의 사진만 표시하며 Expense를 함께 표시하지 않습니다.
- 선택한 첫 사진에 촬영 날짜·시간·GPS metadata가 있으면 입력값으로 제안하고, 저장 전 사용자가 수정할 수 있습니다.
- metadata 분석 중 사용자가 수정한 날짜·시간·장소는 지연 응답으로 덮어쓰지 않습니다. 첫 사진이 바뀌면 이전 사진의 응답은 무시합니다.
- 사진 저장/삭제 중 반복 실행 버튼을 비활성화합니다.

## 10. Calendar Import

Me의 `캘린더 가져오기`에서만 접근합니다.

자동 반영 설정 저장에 실패하면 기존 설정을 유지하고 오류를 안내합니다. 저장 완료 전에는 새 설정을 확정된 것으로 표시하지 않습니다.

```text
권한 설명 → 사용자가 허용 → 기간 선택 → 캘린더 선택 → Memo 가져오기
```

- 권한 dialog는 화면 진입만으로 표시하지 않고 사용자가 허용 버튼을 누를 때 요청합니다.
- 기본 캘린더만 최초 선택하며 사용자가 변경할 수 있습니다.
- 결과는 가져온 수와 중복/빈 일정으로 건너뛴 수를 표시합니다.
- 원본 캘린더를 변경하지 않는다는 설명을 화면에 표시합니다.
- `캘린더 변경 자동 반영`은 별도의 opt-in switch입니다. 현재 선택한 캘린더와 고정 기간을 저장하고 실행/복귀/사용 중 5분마다 확인합니다. 저장된 기간을 표시하고 현재 선택으로 갱신하거나 끌 수 있습니다.
- 원본의 추가·수정·삭제와 직접 수정한 메모의 보호 수를 표시합니다. 권한이 없어도 자동 반영 끄기를 제공합니다.

### Payment Import

Me → 지출 가져오기 → 연결 허용 → Android 알림 접근 설정/앱 선택 또는 iOS 단축어 설정 → 미확인 지출 → 원문 확인과 Expense form 수정 → 저장.

- 화면 진입만으로 연결/권한을 켜지 않습니다. Android 권한 범위, 로컬 보관과 원문 비전송을 설명합니다.
- iOS에는 URL template 복사와 단축어 설정 안내를 제공합니다. 알림 텍스트 전달은 OS/실기기에 따라 확인이 필요하다고 표시합니다.
- 미확인 목록은 합계에 포함하지 않고 원문과 금액 제안을 표시합니다. 버리기와 수동 확인/재시도를 제공합니다.
- 검토 화면은 기존 Expense form이며 원문, 수신 시각 fallback 안내, 수정 가능한 금액/분류/제목/메모/날짜/시간을 표시합니다.
- 승인 취소/환불의 자동 상계 또는 미검증 카드 지원 완료 표시를 하지 않습니다.

## 11. Finance

Finance는 복잡한 금융 Dashboard가 아니라 간단한 지출 요약입니다.

```text
September 2026

총 지출
₩1,243,000

식비          ₩382,000
교통          ₩221,000
쇼핑          ₩198,000

일별 지출
09.29          ₩45,000
```

- 월별 총 지출, 카테고리별 지출, 일별 지출을 표시합니다.
- 현재 월을 기본으로 이전/다음 월 버튼과 이번 달로 돌아가기 버튼을 제공합니다. 월 표시와 접근성 tooltip은 선택한 언어를 사용합니다.
- 카테고리는 합계 내림차순(동률은 enum 순), 일별은 날짜 최신순입니다. 지출이 있는 분류/날짜만 표시합니다.
- 기록 local date로 집계하고 미확인 결제 초안은 포함하지 않습니다. 월 총액과 카테고리/일별 합계는 같은 조회 결과를 사용합니다.
- 삭제된 Expense Record를 제외합니다.
- 차트보다 숫자와 이해하기 쉬운 정보를 우선합니다.
- 빈 월은 `₩0`과 안내를 표시합니다. 조회 중에는 loading, 실패하면 사용자 언어의 error/retry를 제공합니다. 다른 월을 읽는 동안 이전 월 금액을 표시하지 않습니다.
- 기본 현재 월은 자정/앱 복귀 시 갱신하되 명시적으로 조회 중인 월은 유지합니다. 월 선택은 영구 저장하지 않습니다.

## 12. Me

MVP Me는 최소 항목만 제공합니다.

- Display Language: 한국어 / English
- Current app version
- Device Calendar Import / Payment Import 진입점
- Open Source Licenses
- 로컬 보관과 백업/복원 미지원·데이터 유실 위험 안내

App Lock, Notification, Backup, Restore, Export는 구현 Phase 전에는 사용 가능한 설정으로 노출하지 않습니다.

언어를 변경하면 현재 화면에 즉시 반영하고 재실행 후에도 유지합니다.

저장 중에는 언어 선택을 잠시 비활성화합니다. 저장 실패 시 이전 선택과 언어로 돌아가고 SnackBar로 재시도를 안내합니다. 앱 버전은 설치된 native build의 `version+build`를 표시하고 loading/error/retry를 제공합니다. 라이선스 목록/본문은 Flutter 기본 LicensePage로 표시합니다. 설정은 큰 글자에서 세로로 scroll할 수 있습니다.

## 13. States

### Empty

```text
아직 기록이 없습니다.
오늘의 첫 번째 순간을 기록해보세요.
[기록하기]
```

### Loading

화면 전체를 불필요하게 막지 않으며 section 또는 content 단위 상태를 사용합니다.

### Error

기술 exception을 노출하지 않습니다.

```text
기록을 불러오지 못했습니다.
다시 시도해주세요.
```

## 14. Theme

- 색상과 typography는 Theme에서 중앙 관리합니다.
- 둥글고 부드러운 모서리를 사용합니다. 입력창과 기록 card는 radius 20, 사진 thumbnail은 16, dialog는 24, bottom sheet 상단은 28을 기준으로 합니다.
- 입력창은 따뜻한 밝은 배경과 얇은 테두리, focus/error 시 명확한 테두리를 제공합니다. 버튼과 filter chip은 pill 형태를 사용하며 기본 터치 영역을 줄이지 않습니다.
- 모서리를 다듬기 위해 새로운 dashboard card나 장식·그림자를 추가하지 않습니다. 기존 화면 구성·색감·기록 흐름을 유지합니다.
- MVP는 Light Theme을 기본으로 합니다.
- Dark Theme은 실제 지원 시점 전까지 설정으로 노출하지 않습니다.
- 불필요한 animation, card, decoration을 추가하지 않습니다.

## 15. Future UI

Event, 독립 Place, Travel, Backup, Cloud Sync, AI는 해당 Phase에서 별도 UX를 설계합니다. MVP mockup과 navigation에는 완료된 기능처럼 표시하지 않습니다.
