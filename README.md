# 타임고치 (Time Gochi)

Flutter로 만든 **안드로이드 전용** 앱입니다. 사용자가 지정한 앱들의 **일일 사용 시간 한도**를 추적하고, 그 결과가 **다마고치(펫)의 건강·기분**에 반영됩니다. 목표는 과도한 스크린 타임을 시각적·게임적으로 알기 쉽게 보여 주는 것입니다.

> pubspec의 패키지 이름은 `app_usage_tracker`이고, 스토어/패키지 표시 이름은 **타임고치**입니다. Android 애플리케이션 ID는 **`com.time_gochi`** 입니다.

---

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

- **앱 선택 및 한도 설정** — 추적할 앱과 일일 사용 시간(분) 한도를 지정합니다.
- **사용량 평가** — 안드로이드 Usage Stats API로 오늘 사용 분을 읽어 한도와 비교합니다.
- **다마고치 상태** — 배고픔·청결·행복·병 등 스탯이 시간에 따라 감쇠하고, 한도 초과 시 부정적 효과가 있습니다.
- **알림** — 한도 도달, 돌봄 가능 시점 등 로컬 알림을 사용할 수 있습니다.
- **백그라운드 평가** — Workmanager로 주기적으로 평가 사이클을 돌립니다(기기/OS 정책에 따라 간격은 달라질 수 있음).
- **일일 돌봄 점수** — 그날 펫 상태를 0~100으로 환산해 기록하며, 날이 바뀌면 **누적 점수**에 반영됩니다.
- **기록 / 순위 UI** — 기록은 누적 점수 중심이며, 순위 보드 등 화면은 앱 내 탭으로 제공됩니다.

---

## 시스템 요구 사항

- **Flutter** `>=3.10.0`, **Dart SDK** `>=3.0.0 <4.0.0` (`pubspec.yaml` 기준)
- **Android** — Usage Stats, 알림, 백그라운드 작업에 맞는 OS/제조사 설정이 필요할 수 있습니다.

---

## 프로젝트 구조 (`lib/`)

| 경로 | 역할 |
|------|------|
| `main.dart` | 앱 진입점, 알림·Workmanager 초기화, 셋업 완료 여부에 따른 화면 분기 |
| `models/tamagotchi.dart` | 펫 데이터 모델, 날짜 스탬프, 성장 단계, 스프라이트 경로 |
| `models/app_limit.dart` | 앱 패키지명·표시 이름·한도(분)·활성 여부 |
| `screens/` | 셋업 인트로/설정, 앱 피커, 한도 편집, 메인 다마고치 화면, 기록/순위 등 |
| `widgets/` | 아바타, 스탯 바 등 UI 조각 |
| `services/storage_service.dart` | SharedPreferences 기반 저장(펫, 한도, 누적 점수 등) |
| `services/usage_service.dart` | Usage Stats 권한·오늘 사용 분 조회 |
| `services/tamagotchi_service.dart` | 감쇠, 한도 평가, 밥·씻기·놀기·약 액션, 치료제 규칙 |
| `services/daily_score_service.dart` | 하루 스냅샷 점수 계산 및 일자별 최소값 병합, 누적 반영 트리거 |
| `services/notification_service.dart` | 로컬 알림 초기화 및 표시 |
| `services/background_worker.dart` | Workmanager 콜백, `runEvaluationCycle()` — 감쇠 → 사용량 평가 → 저장 → 일일 점수 기록 |

코드 안 주석에는 **“모든 날짜·한도 판정은 기기 로컬 시각(타임존)”** 이라는 전제가 반복해 적혀 있습니다. UTC로 강제 변환하지 않으므로, 사용자가 기기에서 바꾼 날짜/시간대와 일치합니다.

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

- 일정 시간마다 배고픔↑, 청결↓, 행복↓ 같은 **감쇠**가 적용됩니다.
- 밥·씻기·놀이는 **쿨다운**과 스탯 임계값(너무 배부르면 안 먹음 등)이 있습니다.

### 4. 일일 돌봄 점수 (`DailyScoreService`)

- 매 평가 후(백그라운드 사이클 포함) 스냅샷을 남깁니다.
- 그날 여러 번 측정되면 **그날 최소값(가장 나쁜 순간)** 을 유지하는 방식으로 병합해, “하루 최악의 컨디션”이 기록에 남도록 합니다.
- 사망·아픔 등은 점수 0에 가깝게 반영됩니다.
- 날짜가 바뀌면 `StorageService.finalizePastDaysIntoCumulative` 경로로 **전날까지 누적**에 합산됩니다.

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
flutter run
```

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

1. **서명** — `android/key.properties.example`을 참고해 `key.properties`와 keystore를 준비합니다. 없으면 디버그 키로 release APK가 나올 수 있습니다.
2. **Gradle** — `PROGRESS.md`에 적힌 대로 `android` 폴더에서 `assembleRelease`를 실행합니다.
3. **출력** — `build/apk_named/time_gochi-release.apk` 및 기본 `app-release.apk` 경로를 확인합니다.
4. **난독화 매핑** — 릴리스 시 `build/app/outputs/mapping/release/mapping.txt`를 보관해 두면 크래시 역추적에 유리합니다.

---

## 진행 현황 체크리스트

출시 전 할 일·완료 항목은 [PROGRESS.md](PROGRESS.md)를 기준으로 유지합니다. README는 **제품·구조 설명**에 두고, 빌드 명령·체크박스는 PROGRESS에 두는 편이 관리하기 쉽습니다.

---

## 라이선스·기여

저장소에 명시된 라이선스가 없다면, 내부/개인용으로만 사용한다고 가정하고 배포 시 의존성 라이선스를 각 패키지 정책에 맞게 확인하세요.
