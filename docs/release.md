# MY LIFE — 배포 준비와 회사 실기기 검증

Status: `IN PROGRESS — DEVICE VERIFICATION PENDING`

2026-10-06: 사용자 요청으로 실기기 검증은 나중에 진행합니다. 개발 버전 `0.1.1+2`는 자동화/로컬 빌드 검증용이며, 아래 실기기 gate는 `NOT TESTED`로 유지합니다.

## 1. 지금 확인 가능한 것 / 아직 확인하지 않은 것

- 자동화: Repository, migration, 사진 파일 실패/중단 후 복구, Widget와 큰 글자/키보드 흐름.
- 로컬 빌드: `0.1.1+2` Android debug APK, iOS simulator와 전체 테스트 130개/정적 검사 통과 (2026-10-06). 인증서 없는 Android release의 명시적 차단은 2026-10-05 확인했습니다. 서명된 release 성공을 의미하지 않습니다.
- 회사에서 확인: 실제 카드 알림, iOS 단축어 원문 전달, 권한/카메라/사진 보관함, 강제 종료/앱 업데이트, VoiceOver/TalkBack.
- 인증서 준비 후 확인: Android signed release와 iOS 기기 archive/distribution. 현재 스토어 출시 준비 완료로 표시하지 않습니다.
- 현재 Android debug build는 성공하지만 `native_exif`의 기존 Kotlin Gradle Plugin 사용 경고가 남습니다. Flutter/Gradle을 올리기 전 plugin의 Built-in Kotlin 대응을 확인해야 하며, 이번 작업에서 임의 업그레이드는 하지 않습니다.

## 2. Android signing

release 빌드는 debug key로 서명하지 않습니다. `mobile/android/key.properties`의 네 항목이 없으면 release task가 설명과 함께 실패합니다. debug build는 기존대로 사용합니다.

1. 운영자가 본인의 upload keystore를 안전한 저장소에 생성/보관합니다. 키·비밀번호를 이 채팅이나 Git 저장소에 올리지 않습니다.
2. `mobile/android/key.properties.example`을 참고해 로컬 `key.properties`에 `storeFile`, `storePassword`, `keyAlias`, `keyPassword`를 입력합니다. storeFile은 절대 경로를 권장합니다.
3. keystore/비밀번호의 별도 복구 수단과 권한을 준비합니다. 실제 release build는 인증서 제공 후 검증합니다.
4. release artifact가 debug 인증서로 서명되지 않았는지 확인하고 Play Console의 서명/업로드 키를 연결합니다.

인증서 없이 release build를 통과시키려고 debug key fallback을 추가하지 않습니다. 예제 파일은 실제 인증서나 비밀번호가 아닙니다.

## 3. iOS signing / 권한

- 실제 기기에서 Xcode Runner의 `com.mincheol.mylife`와 본인 Development Team, provisioning을 설정합니다.
- 회사 기기의 신뢰/Developer Mode를 확인하고 실제 기기 빌드를 먼저 실행합니다. simulator 성공은 기기 서명 검증을 대신하지 않습니다.
- App Store Connect/TestFlight 배포는 운영자 계정·권한·약관 처리 후 진행합니다. 지금 계정/인증서를 생성하거나 업로드하지 않습니다.
- Camera/Photo/Calendar 목적 문구의 OS 언어 표시, privacy manifest/SDK, privacy policy URL, Data Safety/App Privacy 선언을 실제 데이터 흐름과 대조합니다.
- 출시용 아이콘·스크린샷·지원 연락처·개인정보처리방침 공개 URL도 운영자가 확정해야 합니다. Me의 로컬 보관 안내는 공식 개인정보처리방침을 대신하지 않습니다.

## 4. 회사에서 실행할 체크리스트

결과에 OS/기기/앱 version+build, 날짜, 기대/실제 결과, PASS/FAIL을 기록합니다. 캡처에서 카드번호·연락처·개인 기록은 가립니다. 결과가 없는 항목은 `NOT TESTED`로 둡니다.

| 항목 | Android | iPhone | 기대 결과 |
| --- | --- | --- | --- |
| Memo/Expense/Photo 저장·수정·삭제 | NOT TESTED | NOT TESTED | Timeline/Home/Finance 일치 |
| 앱 완전 종료·재시작 | NOT TESTED | NOT TESTED | 기록/앱 사진/언어 유지 |
| 기존 설치 위에 업데이트 (삭제 없이) | NOT TESTED | NOT TESTED | 기존 DB·사진 보존, Me 새 버전 |
| 카메라/사진 권한 허용·거부·철회 | NOT TESTED | NOT TESTED | 수동 입력 유지, 이해 가능한 오류 |
| EXIF 없는 사진/촬영시각·GPS 있는 사진 | NOT TESTED | NOT TESTED | 없는 값은 강제 추정하지 않음 |
| 캘린더 단일/반복 일정 추가·시간 수정·삭제 | NOT TESTED | NOT TESTED | 원본 비수정, 중복 방지, local 수정 보호 |
| 캘린더 권한 철회·앱 종료 중 원본 변경 | NOT TESTED | NOT TESTED | 오삭제 없음, 앱 복귀 후 읽기 |
| 삼성카드/쿠팡 와우 카드/카카오뱅크/온통대전 | NOT TESTED | NOT TESTED | 실제 발신 앱/텍스트별 승인 초안, 확인 전 합계 제외 |
| 결제 취소/충전/이체/중복 알림 | NOT TESTED | NOT TESTED | 보수적 제외, 기존 Expense 자동 취소 없음 |
| iOS 단축어 텍스트/URL 인코딩/같은 ID | N/A | NOT TESTED | opt-in 상태에서만 수신, 같은 ID 재처리 안 함 |
| 저장/사진 삭제 중 강제 종료·저장 공간 부족 | NOT TESTED | NOT TESTED | 불완전 Record 없음, 다음 사진 접근에서 복구/오류 안내 |
| 한국어/English·큰 글자·키보드·화면 회전 | NOT TESTED | NOT TESTED | 입력/저장/뒤로가기 접근 가능 |
| TalkBack/VoiceOver | NOT TESTED | NOT TESTED | 필드·버튼 이름·순서·터치 범위 확인 |
| Me 버전/라이선스/로컬 보관 안내 | NOT TESTED | NOT TESTED | 실제 빌드와 일치, offline 표시 |

## 5. 출시 중단 조건

기록 유실·계정 간 정보 노출·미확인 지출 자동 저장·권한 거부 후 오삭제·migration 실패가 있으면 출시하지 않습니다. 인증서/공개 정책/스토어 심사/실기기 gate가 남아 있는 동안 V1 Stabilization은 완료가 아닙니다.

공식 배포 정책은 제출 시 다시 확인합니다: [Apple Review](https://developer.apple.com/app-store/review/guidelines/), [Google 정책](https://play.google.com/about/developer-content-policy/).
