# 타임고치 (vibe2026) — 진행 현황

코드·빌드 설정과 맞춰 둔 체크리스트입니다. 내용을 바꿀 때 **업데이트 날짜**만 적어 두면 됩니다.

**마지막 동기화:** _(여기에 날짜)_

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
# Android Studio 번들 JBR 사용 권장
cd android
gradlew.bat :app:assembleRelease --no-daemon
```

**산출물**

| 경로 | 용도 |
|------|------|
| `build/apk_named/time_gochi-release.apk` | 이름 고정본 |
| `build/app/outputs/apk/release/app-release.apk` | Gradle 기본 출력 |

`key.properties`가 없으면 **debug 서명**으로 나오는 release APK(베타용)입니다.

---

## 경로

프로젝트 루트 예: `c:\Users\giwon\Downloads\vibe2026`

자세한 설명은 루트의 [README.md](README.md)를 참고하세요.
