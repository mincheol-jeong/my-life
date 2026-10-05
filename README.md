# MY LIFE

MY LIFE는 메모, 지출, 사진으로 일상을 기록하고 Timeline에서 다시 확인하는 Offline First 모바일 애플리케이션 프로젝트입니다.

## Current Status

- Current phase: Phase 6 — Home complete; Phase 7 next
- Application code: Foundation, Record + Memo, Expense, Photo, Timeline, Home implemented in `mobile/`
- Supported platforms: Android, iOS
- Current development version: 0.1.0
- Flutter: 3.47.5 stable
- Dart: 3.13.4
- Flutter project location: `mobile/`
- Flutter project name: `my_life`
- Android application ID / iOS bundle ID: `com.mincheol.mylife`
- Phase 1 Foundation: Complete
- Phase 2 Record + Memo: Complete
- Phase 3 Expense: Complete
- Phase 4 Photo: Complete
- Phase 5 Timeline: Complete
- Phase 6 Home: Complete
- Lightweight Calendar Import / Photo metadata suggestion: Complete
- Device Calendar auto-reflection / Payment draft import: Implemented; actual card alerts require device verification
- Languages: 한국어 / English

현재 개발 환경에서 Android SDK 36, Android Studio JDK 25, Xcode 27.0, CocoaPods 1.17.0을 사용하여 Android debug와 iOS simulator build를 검증했습니다. 자동화 테스트는 현재 79개입니다.

Phase 2에서 Memo 생성·조회·수정·soft delete, 앱 재실행 후 로컬 DB 유지, schema v1→v2 migration을 테스트했습니다.

Phase 3에서 Expense 생성·조회·수정·soft delete, Record 1:1 transaction, schema v2→v3 migration, 앱 재실행 후 데이터 유지를 테스트했습니다.

Phase 4에서 카메라/갤러리 Photo Record, 앱 전용 원본·썸네일 저장, 개별/전체 삭제, schema v3→v4 migration을 구현했습니다. Me에서 한국어와 English를 선택하고 재실행 후에도 유지할 수 있습니다.

Phase 5에서 모든 active Record의 날짜별 최신순 Timeline, 타입/기간 필터, 상세 화면 이동, empty/loading/error 상태를 구현했습니다. 삭제된 Record는 Timeline에 표시되지 않습니다.

Phase 6 Home은 오늘 local date, 최근 기록 5개, 이번 달 총 지출, 최근 Photo Record 6개의 대표 썸네일을 표시합니다. 기록과 사진은 Timeline과 같은 기록 날짜·시간 최신순이며, 선택하면 해당 타입의 상세 화면으로 이동합니다. 삭제된 기록은 제외하고 각 영역에 empty/loading/error 및 재시도를 제공합니다. 자정과 앱 복귀 시 날짜·월별 지출 기준을 갱신합니다.

Me에서 사용자가 선택한 기기 캘린더 일정과 기간을 Memo로 한 번 가져올 수 있습니다. 원본 캘린더에는 쓰지 않으며 중복 occurrence는 건너뜁니다. Photo 작성은 선택한 첫 사진의 EXIF 날짜·GPS를 읽어 수정 가능한 날짜·시간·장소 초기값을 제안합니다.

Calendar 자동 반영을 별도로 켜면 선택한 캘린더와 고정 기간의 원본 변경을 앱 실행·복귀 및 사용 중 5분마다 반영합니다. 직접 수정한 Memo는 보호하며 OS 읽기 실패 시 기존 기록을 삭제하지 않습니다. 앱 종료 중 동기화는 보장하지 않습니다.

Me의 지출 가져오기는 Android 선택 앱 알림 또는 iOS 단축어 텍스트를 미확인 초안으로 받고, 사용자가 기존 Expense form에서 확인 후 저장합니다. 카드 네 종류의 실제 알림 형식 호환성은 아직 실기기에서 검증하지 않았습니다.

## V1 MVP Scope

- Home
- Timeline
- Memo Record
- Expense Record와 기본 Finance 집계
- Photo Record와 로컬 파일 저장
- Drift/SQLite 기반 로컬 저장

Search, 독립 Calendar/Event, 양방향 동기화, 독립 Place, Travel, Backup/Restore, Backend, Cloud Sync, AI는 V1 MVP 범위가 아닙니다.

## Planned Technology

- Flutter / Dart
- Riverpod
- GoRouter
- Drift / SQLite
- Image Picker / Path Provider / Image
- Flutter Localizations / Shared Preferences
- Device Calendar Plus / Native EXIF / Geocoding

패키지는 각 Phase에서 실제 필요할 때만 추가합니다.

`docs/ui-ux.md`가 UI/UX의 공식 source of truth입니다. 설계 스튜디오 화면은 참고 자료이며, 차이가 있으면 문서를 먼저 갱신한 뒤 구현합니다.

## Development Setup

Flutter stable과 Android Studio 또는 Xcode를 설치한 뒤 개발 환경과 연결된 기기를 확인합니다.

```bash
flutter doctor -v
flutter devices
```

의존성과 Drift 생성 코드를 준비합니다. 아래 명령은 저장소 루트에서 실행합니다.

```bash
cd mobile
flutter pub get
dart run build_runner build
```

## Automated Tests

전체 정적 검사와 자동화 테스트는 `mobile/`에서 실행합니다.

```bash
dart format .
flutter analyze
flutter test
```

특정 테스트만 실행할 수도 있습니다.

```bash
flutter test test/features/timeline/data/timeline_repository_test.dart
flutter test test/features/home
flutter test test/widget_test.dart
```

- Repository 테스트는 in-memory SQLite에서 CRUD, 제약조건, 정렬, 필터와 stream 갱신을 확인합니다.
- Widget 테스트는 navigation과 Memo/Expense/Timeline/언어 선택의 핵심 사용자 흐름을 확인합니다.
- 테스트는 실제 기기의 Camera/Gallery 권한 선택기까지 자동화하지 않습니다. 해당 흐름은 아래 기기 테스트로 확인합니다.

## Run on a Simulator or Device

사용 가능한 대상은 먼저 `flutter devices`로 확인하고 표시된 device id를 사용합니다.

```bash
cd mobile
flutter run -d <device-id>
```

iOS Simulator는 Flutter가 제공하는 emulator id로 시작하고, `flutter devices`가 보여주는 실제 Simulator device id로 앱을 실행합니다.

```bash
flutter emulators --launch apple_ios_simulator
flutter devices
flutter run -d <ios-simulator-id>
```

Xcode 27에서는 Simulator 관리 화면이 Device Hub라는 이름으로 표시될 수 있습니다. `apple_ios_simulator`는 시작용 emulator id이며 `flutter run -d`의 device id가 아닙니다.

Android Emulator는 Android Studio의 Device Manager에서 시작하거나 `flutter emulators`로 목록을 확인한 뒤 실행합니다.

```bash
flutter emulators
flutter emulators --launch <emulator-id>
flutter run -d <android-device-id>
```

실제 Android 기기는 개발자 옵션과 USB 디버깅을 켜고 연결합니다. 실제 iOS 기기는 Xcode signing 설정과 기기 신뢰가 필요합니다. Camera와 실제 사진 보관함, 권한 거부/허용 동작은 가능하면 실제 기기에서 확인합니다.

## Manual Test Checklist

1. 중앙 `+`에서 Memo, Expense, Photo를 각각 저장합니다.
2. Timeline에서 날짜별 최신순과 같은 날짜의 시간 내림차순을 확인합니다.
3. 전체/메모/지출/사진 필터와 기간 필터를 각각 적용하고 해제합니다.
4. 각 Timeline card를 눌러 올바른 상세 화면으로 이동하는지 확인합니다.
5. 기록을 수정한 직후 Timeline에 변경 내용이 반영되는지 확인합니다.
6. 기록을 삭제한 뒤 Timeline에서 사라지는지 확인합니다.
7. 앱을 완전히 종료하고 다시 실행해 Record와 앱 관리 사진이 유지되는지 확인합니다.
8. Me에서 한국어/English를 변경하고 앱 재실행 후 선택이 유지되는지 확인합니다.
9. 실제 기기에서 Camera/Gallery 권한 허용과 거부, 여러 사진 선택, 원본 유지와 앱 내 삭제를 확인합니다.
10. Me → 캘린더 가져오기에서 권한을 허용하고 기간·캘린더를 선택해 Memo가 생성되는지 확인합니다.
11. 같은 기간을 다시 가져왔을 때 기존 일정이 중복 생성되지 않는지 확인합니다.
12. GPS와 촬영시각이 있는 실제 사진을 선택해 날짜·시간·장소 제안과 수동 수정이 동작하는지 확인합니다.
13. Home에서 이번 달 지출 합계와 최근 기록·사진을 확인하고 각각 상세 화면으로 이동합니다.
14. 지출 금액/날짜 수정과 삭제가 Home 합계에 반영되고, 사진 삭제 후 대표 썸네일이 갱신되는지 확인합니다.
15. 자정 또는 월 경계 이후 앱을 다시 열어 Home의 오늘 날짜와 지출 집계 월이 갱신되는지 확인합니다.

## Build Verification

배포용 signing이 필요 없는 현재 개발 단계의 검증 명령입니다.

```bash
cd mobile
flutter build apk --debug
flutter build ios --simulator
```

Android 결과는 `mobile/build/app/outputs/flutter-apk/app-debug.apk`에 생성됩니다. iOS simulator build는 macOS와 Xcode가 필요하며 실제 기기/스토어 배포용 archive를 만들지는 않습니다.

## Device Connections

### Android Payment Alerts

1. Me → 지출 가져오기 → 결제 알림 가져오기 허용을 켭니다.
2. 알림 접근 설정에서 MY LIFE를 허용합니다. 이는 전체 알림에 접근 가능한 OS 권한이며 앱은 선택한 source만 처리합니다.
3. 설치된 앱 목록에서 실제 결제 알림을 보내는 카드/은행 앱을 선택합니다. Samsung/KB/카카오뱅크/온통대전의 계정/API를 연결하는 기능은 아닙니다.
4. 해당 앱에서 결제 승인 알림을 켜고 실제 결제를 확인합니다. MY LIFE 실행·복귀 또는 사용 중 15초 주기로 미확인 초안을 수집합니다. 직접 확인 버튼으로도 가져올 수 있습니다.
5. 미확인 지출을 열어 원문·금액·날짜·카테고리·사용처를 확인하고 저장합니다. 저장 전에는 Home 합계에 포함되지 않습니다.

취소/충전/이체/청구와 모호한 금액은 제외합니다. 알림 본문이 숨겨지거나 지원하지 않는 형식이면 자동 제안이 되지 않으며 기존 수동 지출 입력을 사용합니다. 동일 알림 ID는 중복 처리하지 않지만 서로 다른 앱에서 온 같은 결제는 사용자가 구분해야 합니다. 취소 알림은 기존 지출을 자동 삭제하지 않습니다. OS가 강제 종료/배터리 정책으로 listener를 중지한 동안의 알림은 누락될 수 있습니다.

### iPhone Shortcuts Payment Text

1. Me → 지출 가져오기에서 연결을 허용합니다.
2. 단축어 → 자동화에서 앱 알림(iOS 27) 또는 메시지 수신을 조건으로 설정합니다. 앱 알림에서 원문을 전달할 수 있는지는 실기기에서 확인해야 합니다. MY LIFE가 다른 앱 알림을 직접 읽지는 않습니다.
3. 전달된 결제 텍스트를 단축어의 URL 인코딩 동작으로 인코딩합니다.
4. 복사한 `mylife://payment-import?source=shortcuts&text=` 뒤에 인코딩한 텍스트를 연결하고 URL 열기로 MY LIFE에 전달합니다. 안정된 외부 알림 ID가 있다면 `&id=<고유 ID>`를 추가할 수 있습니다.
5. Me → 지출 가져오기에서 초안을 검토하고 저장합니다. iOS 연결은 자동화가 앱을 여는 방식입니다. 잠금 상태/자동화 설정에 따라 사용자 조작이 필요할 수 있으며 background 저장을 보장하지 않습니다.

같은 외부 ID를 전달하면 재수신을 방지합니다. ID 없는 별도 URL 호출은 각각 새로운 초안이 될 수 있습니다. 사용 중인 카드 네 종류의 실기기 결제 알림/메시지 전달은 별도 확인이 필요합니다.

### Calendar Auto-reflection (Android / iOS)

1. Me → 캘린더 가져오기에서 권한을 허용합니다.
2. 캘린더와 포함 기간을 선택한 뒤 캘린더 변경 자동 반영을 켭니다. 기본값은 꺼짐입니다.
3. 원본 캘린더 앱에서 일정을 생성/수정/삭제하고 MY LIFE로 돌아와 Memo/Timeline에서 반영을 확인합니다.
4. MY LIFE에서 직접 수정한 Memo는 덮어쓰기/삭제하지 않고 보호 수로 표시합니다. 앱에서 삭제한 Memo는 재생성하지 않습니다. source 삭제로 soft delete된 Memo도 같은 ID로 자동 복원하지 않습니다.
5. 자동 반영을 끄거나 현재 선택한 캘린더와 기간으로 갱신할 수 있습니다. 동기화 기간은 고정 범위이며 자동으로 미래 날짜까지 확장하지 않습니다.

OS 캘린더의 로컬 저장소만 읽습니다. Google/iCloud 등 계정의 원격 동기화는 OS 캘린더가 담당합니다. 실시간 background 동기화나 MY LIFE → 캘린더 쓰기는 제공하지 않습니다.

## Documentation

- [Development Guide](AGENTS.md)
- [Requirements](docs/requirements.md)
- [Architecture](docs/architecture.md)
- [System Design](docs/design.md)
- [Database Design](docs/database.md)
- [UI/UX Design](docs/ui-ux.md)
- [Roadmap](docs/roadmap.md)
- [Version](VERSION.md)
- [Changelog](CHANGELOG.md)
