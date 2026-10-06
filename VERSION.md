# MY LIFE Version

Current Development Version: `0.1.1`

Status: Pre-release Development

Release Date: Unreleased

## Versioning

MY LIFE는 Semantic Versioning을 사용합니다.

```text
MAJOR.MINOR.PATCH
```

- MAJOR: 호환성이 깨지는 변경
- MINOR: 하위 호환 가능한 기능 추가
- PATCH: 버그 수정과 작은 개선

개발 단계에서는 `0.x.x`를 사용합니다. 현재 `0.1.1`은 V1 MVP를 향한 pre-release development version입니다. Flutter build는 `0.1.1+2`입니다.

- 사용자 승인으로 커밋할 때마다 기본 PATCH를 증가시킵니다: `0.1.0` → `0.1.1` → `0.1.2`.
- MINOR/MAJOR 변경은 별도 사용자 지시에 따릅니다. 위 Semantic Versioning 분류는 해당 변경을 결정할 때의 기준입니다.
- Flutter build number도 매 커밋 증가시킵니다: `0.1.0+1` → `0.1.1+2`.
- 커밋별 버전 증가는 정식 릴리스/태그 생성과 별개입니다. 배포 전 변경사항은 CHANGELOG의 `Unreleased`에 유지합니다.

V1 MVP가 안정 릴리스 조건을 만족하면 첫 정식 버전을 `1.0.0`으로 지정합니다. 즉, `V1 MVP`는 제품 범위이고 `1.0.0`은 그 범위의 첫 안정 release version입니다.

`mobile/pubspec.yaml`의 버전을 실제 애플리케이션 버전의 기준으로 사용하고 VERSION과 README를 항상 일치시킵니다.

릴리스 전에 VERSION, CHANGELOG, README, 테스트 및 빌드 결과를 함께 검증합니다.
