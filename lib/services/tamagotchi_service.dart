import '../models/app_limit.dart';
import '../models/tamagotchi.dart';
import 'storage_service.dart';
import 'usage_service.dart';
import 'notification_service.dart';

/// 다마고치 게임 로직.
///
/// 규칙:
///  - 추적 중인 앱이 일일 한도를 초과하면 → 다마고치가 병든다 (sickness +1, isSick=true)
///    같은 앱은 하루 한 번만 카운트 (exceededTodayPackages로 중복 방지)
///  - 누적 sicknessCount >= 3 → 사망
///  - 자정이 넘은 시점에 평가하여, 어제 모든 앱이 한도의 절반 이하로 사용됐으면 치료제 +1
///  - 시간이 지나면 배고픔↑, 청결도↓, 행복도↓ (자연 감쇠)
///  - 액션:
///      feed (먹이) — 배고픔 -30
///      bathe (목욕) — 청결도 +40
///      play (놀이) — 행복도 +35, 배고픔 +5
///      useMedicine (치료제) — isSick=false (sicknessCount는 유지)
class TamagotchiService {
  final StorageService _storage;
  final UsageService _usage;

  TamagotchiService({StorageService? storage, UsageService? usage})
      : _storage = storage ?? StorageService(),
        _usage = usage ?? UsageService();

  /// 시간 경과에 따른 스탯 자연 감쇠를 적용한다.
  /// (배고픔: 1시간당 +5, 청결도: 1시간당 -3, 행복도: 1시간당 -4)
  Tamagotchi applyDecay(Tamagotchi t) {
    if (!t.isAlive) return t;
    final now = DateTime.now();
    final hours = now.difference(t.lastDecayAt).inMinutes / 60.0;
    if (hours <= 0) return t;
    final hungerInc = (hours * 5).round();
    final cleanDec = (hours * 3).round();
    final happyDec = (hours * 4).round();
    return t.copyWith(
      hunger: t.hunger + hungerInc,
      cleanliness: t.cleanliness - cleanDec,
      happiness: t.happiness - happyDec,
      lastDecayAt: now,
    );
  }

  /// 사용량을 평가하여 병/치료제/사망 여부를 갱신.
  /// 메인 진입, 새로고침, 백그라운드 워커에서 호출된다.
  Future<Tamagotchi> evaluateUsage(Tamagotchi t) async {
    if (!t.isAlive) return t;

    final hasPerm = await _usage.hasPermission();
    if (!hasPerm) return t;

    final limits = await _storage.loadLimits();
    if (limits.isEmpty) return t;

    final today = Tamagotchi.todayStamp();
    var current = t;

    // 날짜가 바뀐 경우: 어제 결과를 확정해 치료제 지급 여부 판정
    if (current.lastEvaluatedDate != today) {
      final granted = await _settleYesterday(limits);
      current = current.copyWith(
        medicineCount: current.medicineCount + (granted ? 1 : 0),
        lastEvaluatedDate: today,
        exceededTodayPackages: const [], // 새 날짜이므로 초기화
      );
    }

    // 오늘 사용량 점검 — 한도 초과 시 1회만 sickness 적용
    final usageMap = await _usage.getTodayUsageMinutes();
    final alreadyExceeded = current.exceededTodayPackages.toSet();

    for (final l in limits) {
      if (!l.enabled) continue;
      final used = usageMap[l.packageName] ?? 0;
      if (used >= l.limitMinutes && !alreadyExceeded.contains(l.packageName)) {
        alreadyExceeded.add(l.packageName);
        final newCount = current.sicknessCount + 1;
        current = current.copyWith(
          sicknessCount: newCount,
          isSick: true,
          happiness: current.happiness - 15,
          isAlive: newCount < 3,
          exceededTodayPackages: alreadyExceeded.toList(),
        );

        // 알림으로 사용자에게 통지
        try {
          await NotificationService.showLimitReached(
            appName: l.appName,
            limitMinutes: l.limitMinutes,
            usedMinutes: used,
          );
        } catch (_) {}

        if (newCount >= 3) {
          break; // 사망 — 더 처리할 의미 없음
        }
      }
    }

    return current;
  }

  /// 어제 사용량을 점검 — 모든 앱이 한도 절반 이하면 true
  Future<bool> _settleYesterday(List<AppLimit> limits) async {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));
    try {
      final yesterdayMap =
          await _usage.getUsageMinutesInRange(startYesterday, startToday);
      for (final l in limits) {
        if (!l.enabled) continue;
        final used = yesterdayMap[l.packageName] ?? 0;
        if (used > l.limitMinutes ~/ 2) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- 액션 ----------

  Tamagotchi feed(Tamagotchi t) {
    if (!t.isAlive) return t;
    return t.copyWith(
      hunger: t.hunger - 30,
      happiness: t.happiness + 5,
    );
  }

  Tamagotchi bathe(Tamagotchi t) {
    if (!t.isAlive) return t;
    return t.copyWith(
      cleanliness: t.cleanliness + 40,
      happiness: t.happiness + 3,
    );
  }

  Tamagotchi play(Tamagotchi t) {
    if (!t.isAlive) return t;
    return t.copyWith(
      happiness: t.happiness + 35,
      hunger: t.hunger + 5,
      cleanliness: t.cleanliness - 5,
    );
  }

  /// 치료제 사용 — 병이 들었을 때만 효과
  Tamagotchi useMedicine(Tamagotchi t) {
    if (!t.isAlive) return t;
    if (!t.isSick) return t;
    if (t.medicineCount <= 0) return t;
    return t.copyWith(
      isSick: false,
      medicineCount: t.medicineCount - 1,
      happiness: t.happiness + 10,
    );
  }
}
