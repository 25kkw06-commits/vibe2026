# 타임고치 (vibe2026) — 진행 현황

코드·빌드 설정이랑 맞춘 메모. 구조 바꾸면 날짜만 갱신.

마지막 동기화: 2026-05-17

---

## 브랜치 `feature/admin-build`

- Android **productFlavors**: `prod` / `admin` (`com.time_gochi.admin`, 앱 이름 「타임고치 관리자」)
- **`--dart-define=ADMIN_MODE=true`**: 홈 AppBar **관리자 도구** — 출생일·평가일 조작, 랭킹 주입, 치료제·병, 스탯 (`lib/screens/admin/admin_panel_screen.dart`)
- 빌드·복사 경로: [BUILD.md](BUILD.md) (플레이버·APK 빌드 절차)

---

## 문서 읽는 순서 (빌드 포함)

1. **[BUILD.md](BUILD.md)** — APK·로컬 Flutter(`.flutter_sdk`)·Gradle·산출물 (**빌드 시 필독**)
2. [README.md](README.md) — 제품·`lib/` 구조·동작
3. 본 파일(`PROGRESS.md`) — 완료 이력·체크리스트

---

## 여기까지 (온보딩·UI·권한 — 2026-05-16)

- [x] 첫 실행 인트로 — PageView 3단. 상세는 「게임 규칙 자세히」 (`lib/screens/onboarding/setup_intro_screen.dart`)
- [x] 셋업 — 스크롤+하단 버튼, `SafeArea` (`lib/screens/onboarding/setup_screen.dart`)
- [x] 사용 정보 권한 — 제한 설정 안내 + `openAppSettings()` (`setup_screen.dart`)
- [x] 알 아바타 — 원형 링 여백 (`lib/widgets/tamagotchi_avatar.dart`, `stageIndex == 0`)
- [x] 한도 편집 — `SafeArea`로 저장 버튼 (`lib/screens/limits/limit_edit_screen.dart`)
- [x] 분석 — `setup_screen.dart` `use_build_context_synchronously` (`mounted` 확인)
- [x] 문서 — [BUILD.md](BUILD.md), [README.md](README.md), [앱_설명서.md](앱_설명서.md)

---

## 여기까지 (UI·규칙·APK — 2026-05-12)

- [x] **테마** — 라이트 / 다크 / 시스템(`SharedPreferences`), 인트로·셋업·홈·추적 관리 화면 AppBar에서 **초승달 아이콘** 팝업 메뉴(`Icons.nightlight_round`). `ThemeControllerScope` + `MaterialApp` `theme`·`darkTheme`·`themeMode`
- [x] **추적 앱 유동 변경** — 홈(`TamagotchiScreen`) AppBar **+** (`Icons.add`, 툴팁 추적 앱·한도) → `ManageLimitsScreen`: 앱 추가·삭제, **추적 on/off** 스위치, 한도 편집. 인트로/첫 셋업 문구를 “게임 후에도 변경 가능”으로 정리
- [x] **한도(분) 7일 잠금** — 그날 **처음** 한도 초과로 집계될 때 `StorageService.recordLimitExceededForEditLock` → 해당 패키지는 7일간 분 한도만 수정 불가(더 긴 잠금이 있으면 유지). 목록에서 앱 제거 시 잠금 데이터도 삭제. `LimitEditScreen`에서 슬라이더·입력 비활성 + 안내
- [x] **순환 import 정리** — `setup_screen` ↔ `tamagotchi_screen` ↔ `setup_intro` 방지: `main.dart`의 `MaterialApp.routes`에 `/setup_intro`, `/setup`, `/game` 등록 후 `pushNamed`·`pushNamedAndRemoveUntil` 사용
- [x] **릴리스 APK 빌드** — `flutter build apk --release` 성공(프로젝트 로컬 SDK: `.flutter_sdk/flutter/bin/flutter.bat` 등). 산출: `build/app/outputs/flutter-apk/app-release.apk`, Gradle 후처리: `build/apk_named/time_gochi-release.apk`
- [x] 빌드 직전 **누락 import** 복구(`StatBar`, `TamagotchiAvatar`, `LimitEditScreen`, `setup_screen` 등)

---

## 여기까지 (빌드·Git·기여자 — 2026-05-13)

- [x] **APK** — 전역 PATH에 `flutter` 없을 때 프로젝트 로컬 `\.flutter_sdk\flutter\bin\flutter.bat build apk --release` 로 재빌드
- [x] **커밋 & Co-authored-by** — 일부 환경에서 PowerShell의 `git` 래퍼가 `commit-tree`·`commit --amend` 등을 `git commit --trailer "Co-authored-by: Cursor …"` 로 바꿔 넣을 수 있음. 우회: `C:\Program Files\Git\bin\git.exe` 직접 실행(Process·cmd) 또는 Git Bash; 메시지만 갈아끼울 때는 동일 트리로 `commit-tree` 후 `reset --hard`
- [x] **GitHub Contributors** — `phantom9679@gmail.com` 으로 올라간 초기 3커밋을 `git filter-branch` `--env-filter` 로 `kkw <25kkw06@gmail.com>` 에 맞춘 뒤 `main` 을 `push --force-with-lease`. 로컬 `git shortlog -sne main` 은 1명만 나와야 함. 웹/API **Contributors** 집계는 커밋 목록보다 늦게 갱신될 수 있음

---

## 여기까지 (문서·저장소)

- [x] [README.md](README.md) — 프로젝트 설명·구조·규칙 상세 정리
- [x] [BUILD.md](BUILD.md) — **빌드 정본**(로컬 SDK·명령·산출물). README 상단·본 문서에서 필독 안내
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
| 기록 탭 「나의 점수」 | 30일 주기 1~30일차 행복도 합(주기 끝나면 리스트·저장 초기화, 크레딧만 남을 수 있음) |
| 날짜·시각 | **기기 로컬** 달력/타임존 기준 (주석·로직 일치) |
| 릴리스 서명 | `android/key.properties` 있으면 release, 없으면 debug 서명 (`key.properties.example` 참고) |
| R8 매핑 | `build/app/outputs/mapping/release/mapping.txt` |
| Git `main` 히스토리 | 2026-05-13 기준 author 통일·force-push 적용됨. 다른 클론은 `fetch` 후 `reset --hard origin/main` 으로 맞출 것 |

---

## 할 일 (선택 · 출시 전)

- [ ] **실기기 QA** — 자정 전후, 여러 앱 한도, 치료제, 기록 누적 한 사이클
- [ ] **스토어 배포** — keystore + `key.properties` 후 Play 등 업로드용 빌드
- [ ] **Gradle** — `kotlinOptions.jvmTarget` deprecation 경고 → `compilerOptions` DSL (동작만 보면 선택)
- [ ] **스토어 자료** — 스크린샷, 짧은 설명, 데이터(사용 통계·앱 목록) 안내 문구
- [ ] **품질** — `flutter analyze`, 위젯 테스트 정리 (선택)

---

## Android 릴리스 빌드

**상세·표준 명령·문제 해결은 [BUILD.md](BUILD.md)를 따르세요.**  
아래는 PROGRESS에 남겨 둔 최소 예시입니다.

```text
.flutter_sdk\flutter\bin\flutter.bat build apk --release
```

```text
cd android
gradlew.bat :app:assembleRelease --no-daemon
```

**산출물** — 경로 표는 [BUILD.md](BUILD.md) 참고.

---

## 경로

프로젝트 루트 예: `c:\Users\giwon\Downloads\vibe2026`

자세한 빌드 절차는 루트의 **[BUILD.md](BUILD.md)** 를 참고하세요.

---

## Git 푸시 전 (로컬)

- `.flutter_sdk\flutter\bin\dart.bat analyze` — 방금 기준 이상 없음
- 포맷 맞추려면: `dart.bat format lib`
- `git add`할 때: 삭제된 예전 `lib/screens/*.dart`·`lib/theme_controller_scope.dart`와 새 `lib/core/`, `lib/screens/*/`·`BUILD.md`·`앱_설명서.md`·`android/.../strings.xml` 같이 묶어서 스테이징한 뒤 `git status`로 한 번 더 확인
