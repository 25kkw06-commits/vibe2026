# 타임고치 (vibe2026) — 진행 현황

코드·빌드 설정과 맞춰 둔 체크리스트입니다. 내용을 바꿀 때 **업데이트 날짜**만 적어 두면 됩니다.

**마지막 동기화:** 2026-05-12

---

## 여기까지 (UI·규칙·APK — 2026-05-12)

- [x] **테마** — 라이트 / 다크 / 시스템(`SharedPreferences`), 인트로·셋업·홈·추적 관리 화면 AppBar에서 팔레트 메뉴. `ThemeControllerScope` + `MaterialApp` `theme`·`darkTheme`·`themeMode`
- [x] **추적 앱 유동 변경** — 홈 AppBar **톱니** → `ManageLimitsScreen`: 앱 추가·삭제, **추적 on/off** 스위치, 한도 편집. 인트로/첫 셋업 문구를 “게임 후에도 변경 가능”으로 정리
- [x] **한도(분) 7일 잠금** — 그날 **처음** 한도 초과로 집계될 때 `StorageService.recordLimitExceededForEditLock` → 해당 패키지는 7일간 분 한도만 수정 불가(더 긴 잠금이 있으면 유지). 목록에서 앱 제거 시 잠금 데이터도 삭제. `LimitEditScreen`에서 슬라이더·입력 비활성 + 안내
- [x] **순환 import 정리** — `setup_screen` ↔ `tamagotchi_screen` ↔ `setup_intro` 방지: `main.dart`의 `MaterialApp.routes`에 `/setup_intro`, `/setup`, `/game` 등록 후 `pushNamed`·`pushNamedAndRemoveUntil` 사용
- [x] **릴리스 APK 빌드** — `flutter build apk --release` 성공(프로젝트 로컬 SDK: `.flutter_sdk/flutter/bin/flutter.bat` 등). 산출: `build/app/outputs/flutter-apk/app-release.apk`, Gradle 후처리: `build/apk_named/time_gochi-release.apk`
- [x] 빌드 직전 **누락 import** 복구(`StatBar`, `TamagotchiAvatar`, `LimitEditScreen`, `setup_screen` 등)

---

## 여기까지 (문서·저장소)

- [x] [README.md](README.md) — 프로젝트 설명·구조·규칙 상세 정리
- [x] 본 파일(`PROGRESS.md`) — 완료/할 일/빌드 표 형태로 정리
- [x] 원격: [github.com/25kkw06-commits/vibe2026](https://github.com/25kkw06-commits/vibe2026) — `main` 푸시
- [x] `.gitignore` — 로컬 경로 `.flutter_sdk/` 제외
- [x] 커밋 메시지는 변경 요약만 두고 `Co-authored-by` 같은 trailer는 넣지 않음

---

## 완료

| 항목 | 설명 |
|------|------|
| Android 앱 ID | `com.time_gochi` — 다른 앱과 설치 충돌 방지 |
| MainActivity | 패키지 `com.time_gochi` |
| 릴리스 APK 복사 | `build/apk_named/time_gochi-release.apk` |
| 한도·병 규칙 | 앱별 한도 초과 시 **하루 1회** 집계, `sicknessCount`는 **하루 최대 +2** (`limitSickCountToday` 상한) |
| 치료제 | **어제** 추적한 모든 앱이 각 한도 **이하**일 때, 날짜가 바뀌는 처리에서 `medicineCount` **+1** |
| 일일 돌봄 점수 | 기록 탭에 **전날까지 누적** (순위가 아님) |
| 날짜·시각 | **기기 로컬** 달력/타임존 기준 (주석·로직 일치) |
| 릴리스 서명 | `android/key.properties` 있으면 release, 없으면 debug 서명 (`key.properties.example` 참고) |
| R8 매핑 | `build/app/outputs/mapping/release/mapping.txt` |

---

## 할 일 (선택 · 출시 전)

- [ ] **실기기 QA** — 자정 전후, 여러 앱 한도, 치료제, 기록 누적 한 사이클
- [ ] **스토어 배포** — keystore + `key.properties` 후 Play 등 업로드용 빌드
- [ ] **Gradle** — `kotlinOptions.jvmTarget` deprecation 경고 → `compilerOptions` DSL (동작만 보면 선택)
- [ ] **스토어 자료** — 스크린샷, 짧은 설명, 데이터(사용 통계·앱 목록) 안내 문구
- [ ] **품질** — `flutter analyze`, 위젯 테스트 정리 (선택)

---

## Android 릴리스 빌드

```text
# Flutter(권장): 프로젝트에 SDK 두었으면 예시
.flutter_sdk\flutter\bin\flutter.bat build apk --release
```

```text
# Android Studio JBR 권장 — Gradle만
cd android
gradlew.bat :app:assembleRelease --no-daemon
```

**산출물**

| 경로 | 용도 |
|------|------|
| `build/apk_named/time_gochi-release.apk` | 이름 고정본(Gradle이 복사) |
| `build/app/outputs/flutter-apk/app-release.apk` | `flutter build apk --release` 기본 출력 |
| `build/app/outputs/apk/release/app-release.apk` | `assembleRelease`만 쓸 때 Gradle 출력 |

`key.properties`가 없으면 **debug 서명**으로 나오는 release APK(베타용)입니다.

---

## 경로

프로젝트 루트 예: `c:\Users\giwon\Downloads\vibe2026`

자세한 설명은 루트의 [README.md](README.md)를 참고하세요.
