# 타임고치 — 빌드 가이드

**APK를 만들거나 이 저장소에서 빌드를 재현하기 전에, 이 문서를 먼저 읽어 주세요.**  
전역 PATH에 `flutter`가 없는 Windows 환경을 포함해, **프로젝트 안에 두는 로컬 Flutter SDK**(`.flutter_sdk`)로 빌드하는 절차를 기준으로 설명합니다.

---

## 1. 저장소 루트

이하 명령의 현재 디렉터리는 **Git 루트**(예: `vibe2026`)입니다.

```text
cd c:\Users\giwon\Downloads\vibe2026
```

(경로만 본인 PC에 맞게 바꾸면 됩니다.)

---

## 2. 로컬 Flutter SDK (권장)

- 이 프로젝트는 `.gitignore`로 **`.flutter_sdk/`** 를 Git에 올리지 않습니다.
- Flutter **stable**을 받아 루트와 **같은 단계**에 두는 방식을 권장합니다.

```text
vibe2026\
  .flutter_sdk\flutter\bin\flutter.bat   ← Windows
  lib\
  android\
  pubspec.yaml
```

SDK가 없다면 [Flutter 공식 설치](https://docs.flutter.dev/get-started/install)에서 내려받은 뒤, 위 경로에 맞게 폴더를 두거나 **전역 `flutter`** 를 써도 됩니다. 아래에서는 로컬 `flutter.bat` 경로를 표준으로 적습니다.

**버전 확인**

```powershell
.\.flutter_sdk\flutter\bin\flutter.bat --version
```

---

## 3. 빌드 변종(flavor)

Android에는 **`prod`**(일반 사용자)와 **`admin`**(관리자·테스트용) 두 가지가 있습니다.

| flavor | applicationId | 표시 이름 | 특징 |
|--------|-----------------|-----------|------|
| **prod** | `com.time_gochi` | 타임고치 (`strings.xml`) | 스토어/배포용 |
| **admin** | `com.time_gochi.admin` | 타임고치 관리자 | **일반 앱과 동시 설치 가능**. **게임 규칙·코드 경로는 prod와 동일**하고, 홈 AppBar에만 **관리자 도구**(시뮬 일 진행, 스탯·병·기록 디버그)가 추가됩니다. |

**관리자 APK**는 반드시 **`--dart-define=ADMIN_MODE=true`** 와 함께 빌드해야 도구 메뉴가 켜집니다. (flavor만 admin이고 define 없으면 UI가 숨겨집니다.)

### 3.1 일반(prod) vs 관리자(admin) — 규칙 정본

- **플레이 규칙**(상점·재고·30일 기록 주기·합산 나의 점수·주기 완료 크레딧·날짜 마감마다 하루씩 감쇠 시뮬·**3일 연속** 심각 방치 사망·한도 병 3회 사망 등)은 **두 flavor가 같은 Dart 코드**를 쓰므로 **동일**합니다.
- 차이는 **앱 ID**(데이터 저장소 분리)와 **관리자 빌드만** `ADMIN_MODE`로 디버그 패널이 열리는 점뿐입니다.
- 사용자 관점 요약은 [앱_설명서.md](앱_설명서.md), 구현 요약은 [README.md](README.md)를 참고하세요.

---

## 4. 릴리스 APK — 일반(prod)

```powershell
cd c:\Users\giwon\Downloads\vibe2026
.\.flutter_sdk\flutter\bin\flutter.bat pub get
.\.flutter_sdk\flutter\bin\flutter.bat build apk --release --flavor prod
```

산출:

```text
build\app\outputs\flutter-apk\app-prod-release.apk
```

같은 조립이 끝나면 Gradle이 자동으로 **`build\apk_named\time_gochi-release.apk`** 로 복사합니다(`exportTimeGochiApk`).

---

## 5. 릴리스 APK — 관리자(admin)

```powershell
.\.flutter_sdk\flutter\bin\flutter.bat build apk --release --flavor admin --dart-define=ADMIN_MODE=true
```

산출:

```text
build\app\outputs\flutter-apk\app-admin-release.apk
```

복사본: **`build\apk_named\time_gochi-admin-release.apk`** (assemble 끝난 뒤, `exportTimeGochiAdminApk`)

---

## 6. 분석

```powershell
.\.flutter_sdk\flutter\bin\flutter.bat analyze
```

---

## 7. Gradle만으로 조립 (Flutter CLI 없을 때)

```powershell
cd c:\Users\giwon\Downloads\vibe2026\android
.\gradlew.bat :app:assembleProdRelease --no-daemon
.\gradlew.bat :app:assembleAdminRelease --no-daemon
```

(관리자 변형도 위와 같이 조립 가능. **ADMIN_MODE** 는 Flutter 컴파일 시점 define 이므로, Gradle만 쓰면 관리자 도구는 꺼진 채로 들어갈 수 있습니다. 관리자 UI가 필요하면 **항상 Flutter `build apk`** 로 admin flavor를 만드세요.)

---

## 8. 산출물 정리

| 경로 (루트 기준) | 설명 |
|------------------|------|
| `build\app\outputs\flutter-apk\app-prod-release.apk` | 일반 릴리스 |
| `build\app\outputs\flutter-apk\app-admin-release.apk` | 관리자 릴리스 (`ADMIN_MODE`와 함께 빌드) |
| `build\apk_named\time_gochi-release.apk` | prod 복사본 |
| `build\apk_named\time_gochi-admin-release.apk` | admin 복사본 |
| `build\app\outputs\mapping\release\mapping.txt` | R8 매핑(변종에 따라 경로 확인) |

---

## 9. 서명 (`key.properties`)

- Play 스토어·실배포용: `android/key.properties.example` 를 참고해 keystore와 `android/key.properties` 를 준비합니다.
- **`key.properties`가 없으면** release 빌드가 **디버그 키**로 서명되는 구성일 수 있습니다(내부 테스트용). 배포 전 반드시 용도를 확인하세요.

---

## 10. 자주 겪는 상황

| 문제 | 조치 |
|------|------|
| `'flutter'은(는) 내부 또는 외부 명령이 아닙니다` | 전역 PATH 대신 **`.\.flutter_sdk\flutter\bin\flutter.bat`** 전체 경로로 실행 |
| 의존성 오류 | 루트에서 `flutter.bat pub get` 재실행 |
| `flavor` / `assembleRelease` 오류 | 이 프로젝트는 **`--flavor prod`** 또는 **`admin`** 이 필요합니다 |
| Kotlin/Gradle 경고만 있고 빌드는 됨 | `PROGRESS.md` 할 일 — Gradle DSL 정리는 선택 |

---

## 11. 다른 문서와의 역할

| 파일 | 용도 |
|------|------|
| **BUILD.md** (본 문서) | 빌드·산출물·로컬 SDK — **빌드 시 1순위** |
| [README.md](README.md) | 제품 개요, `lib/` 구조, 동작 설명 |
| [PROGRESS.md](PROGRESS.md) | 완료 체크리스트, 출시 전 할 일, 히스토리 요약 |

---

**마지막 업데이트:** 2026-05-16
