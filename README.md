# 다마고치 · 앱 사용시간 추적기 (Flutter / Android)

추적 앱의 사용 시간이 한도를 넘으면 다마고치가 병들고, 절약하면 치료제를 받는
**다마고치 게임**이 결합된 안드로이드 앱입니다.

## 게임 규칙
- **잠금**: 추적할 앱과 시간 한도는 *처음 한 번만* 정할 수 있습니다.
  다마고치가 죽기 전까지 변경 불가.
- **병들기**: 추적 앱 중 하나라도 일일 한도를 넘으면 다마고치가 병에 걸립니다.
  같은 앱은 하루 1번만 카운트.
- **사망**: 누적 3회 병들면 다마고치가 죽습니다. 죽으면 전체 셋업이 초기화되고
  새로 설정할 수 있어요.
- **치료제**: 추적 앱을 모두 한도의 절반 이하로 사용하면 다음 날 치료제 1개 지급.
  병중일 때 사용해 회복.
- **돌보기**: 진짜 다마고치처럼 먹이/목욕/놀기 액션으로 직접 케어.
  방치하면 배고프고 더러워지고 우울해져요.

## 주요 기능
- 설치된 앱 중에서 추적할 앱 선택 (검색 가능)
- 앱별 일일 한도(분) 설정 — 슬라이더 + 직접 입력 + 프리셋
- 다마고치 캐릭터: 알 → 신생아 → 아기 → 청소년 → 어른 단계
- 스탯(배고픔/청결/행복) 시간 자연 감쇠
- 한도 초과 시 즉시 알림 + 다마고치 병들기
- 15분 주기 백그라운드 평가 (workmanager)

## 화면 흐름
```
[셋업 인트로] (경고 + 동의)
       ↓
[셋업 화면] (앱/시간 등록 → 게임 시작)
       ↓
[다마고치 메인] ←─── 평소
       ↓ (3회 병들면)
[사망 화면] (새로 시작)
       ↓
[셋업 인트로]
```

## 프로젝트 구조
```
app_usage_tracker/
├── pubspec.yaml
├── android/app/src/main/AndroidManifest.xml
└── lib/
    ├── main.dart                       진입 + 라우팅 분기
    ├── models/
    │   ├── app_limit.dart
    │   └── tamagotchi.dart             다마고치 상태/단계/이모지
    ├── services/
    │   ├── usage_service.dart          UsageStatsManager 호출
    │   ├── storage_service.dart        SharedPreferences 영속화
    │   ├── notification_service.dart   로컬 알림
    │   ├── tamagotchi_service.dart     스탯 감쇠/평가/액션 로직
    │   └── background_worker.dart      workmanager 콜백
    ├── screens/
    │   ├── setup_intro_screen.dart     경고/규칙 안내
    │   ├── setup_screen.dart           앱+시간 등록 → 게임 시작
    │   ├── app_picker_screen.dart      설치된 앱 목록
    │   ├── limit_edit_screen.dart      시간 한도 설정
    │   └── tamagotchi_screen.dart      메인 게임 + 사망 화면
    └── widgets/
        ├── stat_bar.dart               배고픔/청결/행복 게이지
        └── tamagotchi_avatar.dart      이모지 + 부드러운 둥둥 애니메이션
```

## 사용 기술
- Flutter 3.10+ / Dart 3.0+
- `usage_stats` — 안드로이드 UsageStatsManager 접근
- `installed_apps` — 설치된 앱 목록 조회
- `flutter_local_notifications` — 로컬 알림
- `workmanager` — 백그라운드 주기 평가
- `shared_preferences` — 로컬 저장
- `permission_handler` — 알림 권한 처리

## Android Studio에서 실행하는 방법

### 1. Flutter 프로젝트 부트스트랩 생성
이 디렉터리는 `lib/`, `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`만 포함합니다.
Flutter가 요구하는 나머지 파일(`gradle`, `MainActivity.kt`, `.metadata` 등)을 자동 생성해야 합니다.

```bash
cd app_usage_tracker
flutter create . --org com.example --project-name app_usage_tracker --platforms=android
```

> ⚠️ `flutter create .`가 `android/app/src/main/AndroidManifest.xml`을 덮어씁니다.
> 명령 실행 후 우리가 작성한 매니페스트 내용으로 다시 덮어써 주세요.
> (그래야 `PACKAGE_USAGE_STATS`, `QUERY_ALL_PACKAGES` 등 권한이 유지됩니다.)

### 2. 의존성 설치
```bash
flutter pub get
```

### 3. Android Studio에서 열기
- Android Studio 실행 → **File → Open** → `app_usage_tracker` 폴더 선택
- Flutter / Dart 플러그인 필요 (Settings → Plugins)
- Gradle 동기화 대기

### 4. 실행
- 안드로이드 기기 USB 디버깅 또는 에뮬레이터
- 상단 툴바에서 **Run 'main.dart'** 또는 `flutter run`

### 5. 첫 실행 시 권한 부여 (필수)
- 셋업 화면에서 **「설정 열기」** → **사용 정보 접근**에서 본 앱 허용
- 알림 권한 다이얼로그 허용 (Android 13+)
- 설정 → 한도 등록 → **게임 시작**으로 다마고치 부화

## 빌드 설정
`android/app/build.gradle` (Flutter 자동 생성 후 수정):
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

## 다마고치 동작 원리

### 스탯 감쇠 (`TamagotchiService.applyDecay`)
- 1시간당: 배고픔 +5, 청결 -3, 행복 -4
- 메인 화면 진입/새로고침/백그라운드 워커마다 자동 갱신

### 사용량 평가 (`TamagotchiService.evaluateUsage`)
- 새 날짜로 넘어가면 어제 데이터 점검 → 모두 한도 절반 이하면 치료제 +1
- 오늘 사용량 점검 → 한도 초과 시 sickness +1, isSick=true
- 같은 앱은 `exceededTodayPackages`로 하루 1회만 처리
- sicknessCount ≥ 3 이면 사망 처리

### 액션
| 액션 | 효과 |
|------|------|
| 🍙 먹이 | 배고픔 -30, 행복 +5 |
| 🛁 목욕 | 청결 +40, 행복 +3 |
| 🎮 놀기 | 행복 +35, 배고픔 +5, 청결 -5 |
| 💊 치료 | 병중일 때만, 치료제 -1, 회복 |

## 한계 / 참고
- `PACKAGE_USAGE_STATS`는 사용자가 시스템 설정에서 직접 켜야 하는 특수 권한.
- 본 앱은 알림과 다마고치 페널티로 사용자에게 *알리는* 것만 수행합니다.
  실제로 앱 실행을 차단하려면 `AccessibilityService` 또는 `DeviceAdmin`이 필요합니다.
- `Workmanager` 최소 주기는 15분(OS 제한). 도즈 모드/제조사 절전 정책에 따라
  실행이 지연될 수 있습니다.
- 단일 디바이스 로컬 저장(`SharedPreferences`)이므로 앱을 삭제하면 다마고치도 사라집니다.
