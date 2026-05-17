# 타임고치

안드로이드만. 추적 앱에 일일 사용 한도(분) 걸어 두고 Usage Stats로 오늘 분을 비교한다. 넘기면 펫에 병, 돌봄으로 상태 조절. pubspec 패키지명은 `app_usage_tracker`, 앱 표시는 타임고치, applicationId는 `com.time_gochi`.

## 빌드·APK

prod랑 admin은 Dart 한 벌이다. admin은 `--dart-define=ADMIN_MODE` 켜면 홈에 디버그 메뉴만 생김. 자세한 건 [BUILD.md](BUILD.md). 한글 요약은 [앱_설명서.md](앱_설명서.md).

## 목차

1. [주요 기능](#주요-기능)
2. [시스템 요구 사항](#시스템-요구-사항)
3. [프로젝트 구조](#프로젝트-구조-lib)
4. [핵심 동작 설명](#핵심-동작-설명)
5. [권한](#권한)
6. [실행 및 개발](#실행-및-개발)
7. [릴리스 빌드](#릴리스-빌드)
8. [진행 현황 체크리스트](#진행-현황-체크리스트)

---

## 주요 기능

- 앱·한도 — 추적 앱이랑 하루 분 한도.
- 사용량 — Usage Stats로 오늘 분 비교.
- 펫 — 스탯 감쇠, 한도/방치로 죽을 수 있음.
- 알림 — 한도·돌봄 로컬.
- 백그라운드 — Workmanager 평가(간격은 기기마다 다름).
- 상점 — 크레딧으로 돌봄템. 자동 소량 충전도 있음(일·보유 상한).
- 30일 기록 — 자정 넘긴 뒤 평가마다 행복도가 1~30일차에 쌓임. 앱 안 켠 날도 비슷하게 메움. 30일 끝나면 팝업 후 초기화(크레딧만 남길 수 있음).
- 기록 탭 — 점수·일차.

---

## 시스템 요구 사항

- **Flutter** `>=3.10.0`, **Dart SDK** `>=3.0.0 <4.0.0` (`pubspec.yaml` 기준)
- **Android** — Usage Stats, 알림, 백그라운드 작업에 맞는 OS/제조사 설정이 필요할 수 있습니다.

---

## 프로젝트 구조 (`lib/`)

| 경로 | 역할 |
|------|------|
| `main.dart` | 앱 진입점, 알림·Workmanager 초기화, 셋업 완료 여부에 따른 화면 분기 |
| `core/` | `AdminConfig`, `ThemeControllerScope` (앱 전역 설정·테마) |
| `models/tamagotchi.dart` | 펫 데이터 모델, 날짜 스탬프, 성장 단계, 스프라이트 경로 |
| `models/app_limit.dart` | 앱 패키지명·표시 이름·한도(분)·활성 여부 |
| `screens/home/` | 메인 다마고치 탭 |
| `screens/onboarding/` | 첫 실행 인트로, 셋업(이름·종·한도) |
| `screens/limits/` | 추적 앱·한도 관리, 앱 피커, 한도 편집 |
| `screens/shop/` | 상점 |
| `screens/record/` | 기록 탭(30일 랭킹 보드) |
| `screens/admin/` | 관리자 전용 디버그 패널 (`ADMIN_MODE`) |
| `widgets/` | 아바타, 스탯 바 등 UI 조각 |
| `services/storage_service.dart` | SharedPreferences(펫, 한도, 일별 맵, 30일 랭킹 리스트 등) |
| `services/usage_service.dart` | Usage Stats 권한·오늘 사용 분 조회 |
| `services/tamagotchi_service.dart` | 감쇠, 한도 평가, 밥·씻기·놀기·약 액션, 치료제 규칙 |
| `services/daily_score_service.dart` | 마감일마다 하루씩 감쇠 시뮬·30일 랭킹 append·방치 연속일 |
| `services/notification_service.dart` | 로컬 알림 초기화 및 표시 |
| `services/background_worker.dart` | Workmanager 콜백, `runEvaluationCycle()` — 마감 시뮬·감쇠 → 사용량 평가 → 저장 |

날짜·한도 판단은 전부 기기 로컬 시각 기준(UTC 강제 없음).

---

## 핵심 동작 설명

### 1. 날짜 전환 (`lastEvaluatedDate` / `Tamagotchi.todayStamp()`)

새로운 **로컬 달력 날**이 되면:

- “오늘 한도 초과로 올린 병 카운트” 등 **일일 플래그가 리셋**됩니다.
- **치료제(약 개수)** 조건을 만족하면 `medicineCount`가 증가합니다.  
  **조건 요약:** *어제* 설정된 추적 앱 전부가, 각각의 한도 **이하**로 사용되었을 때(구체적 로직은 `TamagotchiService`의 `_medicineEligibleFromYesterday` 참고).

### 2. 앱 한도 초과와 병 (`sicknessCount`, `limitSickCountToday`)

- 추적 목록의 앱이 **오늘 사용 분 ≥ 한도**가 되면, 그 앱은 “오늘 한도 초과 처리된 목록”에 들어갑니다.
- **같은 앱**에 대해 그날 **여러 번** 초과해도, 병 카운트는 **앱당 하루 한 번**만 반영하는 쪽으로 설계되어 있습니다.
- 하루 동안 “한도 때문에 올라가는 병”은 **`limitSickCountToday`로 상한(예: 2)** 이 걸려 있습니다.  
- `sicknessCount`가 일정 이상이면 사망 처리 등 규칙이 이어집니다(상세는 `tamagotchi_service.dart`).

### 3. 자연 감쇠와 돌봄 액션

- 일정 시간마다 배고픔↑, 청결↓가 적용되고, **행복도는 배고픔·청결 상태에 따라** 함께 떨어지거나(고통·스트레스) 잘 돌보면 덜 떨어지고 조금 회복되기도 합니다.
- 밥·씻기·놀이는 **보유 개수**와 스탯 임계값(너무 배부르면 안 먹음 등)이 있습니다. 시간이 지나면 개수가 자동으로 조금씩 늘어납니다.

### 4. 일일 돌봄 점수 · 30일 랭킹 (`DailyScoreService` / `StorageService`)

- 로컬 달력이 바뀐 뒤 **`advanceThroughClosedDaysAndDecayToNow`**(`evaluateUsage` **직전**에 호출)에서, 마지막 마감 다음 날부터 **어제**까지 **하루씩 자정까지 감쇠**를 적용한 뒤 그날 **행복도**를 일별 맵·**30일 랭킹 리스트**에 기록합니다. 이어서 **현재 시각**까지 한 번 더 감쇠합니다.
- 30일 리스트가 가득 찬 뒤 **다음 마감**에서 주기가 끝나면, **주기 점수 합**에 비례해 **타임 크레딧**을 먼저 지급한 뒤(`StorageService.creditsForCompletedRankingCycle`) 새로 시작 플로우(저장 초기화·크레딧 유지)로 이어집니다.
- **배고픔·청결이 심각한** 상태가 **3일 연속** 달력 마감에서 이어지면 **방치 사망**합니다(`Tamagotchi.diedFromNeglect`).
- `finalizePastDaysIntoCumulative`는 (구)달력 맵 기반 누적용으로 남아 있을 수 있습니다.

### 5. 에셋

`pubspec.yaml`에 선언된 스프라이트:

- `assets/sprites/dog/`, `cat/`, `chicken/` — 성장 단계별 PNG.

---

## 권한

앱이 정상 동작하려면 대략 다음이 필요합니다(실제 매니페스트·런타임 요청은 프로젝트의 `AndroidManifest.xml` 및 `permission_handler` 사용처를 따릅니다).

- **PACKAGE_USAGE_STATS** — 다른 앱 사용 시간 읽기(사용자가 설정에서 수동 허용하는 형태인 경우가 많음).
- **POST_NOTIFICATIONS** (Android 13+) — 알림 표시.
- 백그라운드 작업·배터리 최적화 예외 등은 기기마다 추가 안내가 필요할 수 있습니다.

---

## 실행 및 개발

저장소 루트에서:

```bash
flutter pub get
# 일반 사용자 빌드(스토어/배포와 동일 규칙)
flutter run --flavor prod
# 관리자·테스트용 — 같은 게임 로직 + 홈의 관리자 도구
flutter run --flavor admin --dart-define=ADMIN_MODE=true
```

릴리스 APK·명령 전체는 **[BUILD.md](BUILD.md)** (`--flavor prod` / `admin`, 관리자는 `ADMIN_MODE` 필수).

분석만 할 때:

```bash
flutter analyze
```

테스트:

```bash
flutter test
```

---

## 릴리스 빌드

**절차·명령·산출물·로컬 SDK 전부 [BUILD.md](BUILD.md)에 모아 두었습니다. 빌드할 때는 해당 문서를 따르세요.**

요약만 필요하면:

1. **서명** — `android/key.properties.example` 참고. 없으면 디버그 서명으로 나올 수 있음.
2. **출력** — `flutter build apk --release --flavor prod|admin` 등. 변종별 경로는 **[BUILD.md](BUILD.md)** 표가 정본입니다.
3. **매핑** — `build/app/outputs/mapping/release/mapping.txt` 보관 권장.

---

## 진행 현황 체크리스트

할 일·완료 항목은 [PROGRESS.md](PROGRESS.md)를 기준으로 합니다. **빌드 명령과 산출물은 [BUILD.md](BUILD.md)가 정본입니다.**

---

## 라이선스·기여

저장소에 명시된 라이선스가 없다면, 내부/개인용으로만 사용한다고 가정하고 배포 시 의존성 라이선스를 각 패키지 정책에 맞게 확인하세요.
