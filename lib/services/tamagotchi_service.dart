import '../models/app_limit.dart';
import '../models/tamagotchi.dart';
import 'storage_service.dart';
import 'usage_service.dart';
import 'notification_service.dart';

/// 액션 결과. 성공이면 새 다마고치, 실패면 사유와 기존 다마고치.
class ActionResult {
  final Tamagotchi tama;
  final String? error;
  const ActionResult.ok(this.tama) : error = null;
  const ActionResult.fail(this.tama, this.error);
  bool get success => error == null;
}

class TamagotchiService {
  final StorageService _storage;
  final UsageService _usage;

  // 돌보기 액션 제한치
  static const feedCooldownMin = 20;
  static const batheCooldownMin = 30;
  static const playCooldownMin = 20;
  static const feedHungerMin = 25;   // 이 미만이면 안 먹음
  static const batheCleanMax = 80;   // 이 초과면 안 씻음
  static const playHappyMax = 85;    // 이 초과면 안 놂

  TamagotchiService({StorageService? storage, UsageService? usage})
      : _storage = storage ?? StorageService(),
        _usage = usage ?? UsageService();

  /// 시간 경과에 따른 스탯 자연 감쇠.
  /// 1시간당: 배고픔 +5, 청결 -3, 행복 -4
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

  Future<Tamagotchi> evaluateUsage(Tamagotchi t) async {
    if (!t.isAlive) return t;

    final hasPerm = await _usage.hasPermission();
    if (!hasPerm) return t;

    final limits = await _storage.loadLimits();
    if (limits.isEmpty) return t;

    final today = Tamagotchi.todayStamp();
    var current = t;

    if (current.lastEvaluatedDate != today) {
      final granted = await _settleYesterday(limits);
      current = current.copyWith(
        medicineCount: current.medicineCount + (granted ? 1 : 0),
        lastEvaluatedDate: today,
        exceededTodayPackages: const [],
      );
    }

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

        try {
          await NotificationService.showLimitReached(
            appName: l.appName,
            limitMinutes: l.limitMinutes,
            usedMinutes: used,
          );
        } catch (_) {}

        if (newCount >= 3) break;
      }
    }

    return current;
  }

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

  // ---------- 쿨다운 헬퍼 ----------
  int cooldownRemaining(DateTime? last, int cooldownMin) {
    if (last == null) return 0;
    final passed = DateTime.now().difference(last).inMinutes;
    return passed >= cooldownMin ? 0 : cooldownMin - passed;
  }

  // ---------- 액션 ----------

  ActionResult feed(Tamagotchi t) {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (t.hunger < feedHungerMin) {
      return ActionResult.fail(t, '아직 배고프지 않아요');
    }
    final cool = cooldownRemaining(t.lastFedAt, feedCooldownMin);
    if (cool > 0) return ActionResult.fail(t, '$cool분 뒤 다시 줄 수 있어요');
    return ActionResult.ok(t.copyWith(
      hunger: t.hunger - 30,
      happiness: t.happiness + 5,
      lastFedAt: DateTime.now(),
    ));
  }

  ActionResult bathe(Tamagotchi t) {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (t.cleanliness > batheCleanMax) {
      return ActionResult.fail(t, '이미 깨끗해요');
    }
    final cool = cooldownRemaining(t.lastBathedAt, batheCooldownMin);
    if (cool > 0) return ActionResult.fail(t, '$cool분 뒤 다시 씻길 수 있어요');
    return ActionResult.ok(t.copyWith(
      cleanliness: t.cleanliness + 40,
      happiness: t.happiness + 3,
      lastBathedAt: DateTime.now(),
    ));
  }

  ActionResult play(Tamagotchi t) {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (t.happiness > playHappyMax) {
      return ActionResult.fail(t, '이미 충분히 즐거워요');
    }
    final cool = cooldownRemaining(t.lastPlayedAt, playCooldownMin);
    if (cool > 0) return ActionResult.fail(t, '$cool분 뒤 다시 놀 수 있어요');
    return ActionResult.ok(t.copyWith(
      happiness: t.happiness + 35,
      hunger: t.hunger + 5,
      cleanliness: t.cleanliness - 5,
      lastPlayedAt: DateTime.now(),
    ));
  }

  ActionResult useMedicine(Tamagotchi t) {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (!t.isSick) return ActionResult.fail(t, '병에 걸리지 않았어요');
    if (t.medicineCount <= 0) return ActionResult.fail(t, '치료제가 없어요');
    return ActionResult.ok(t.copyWith(
      isSick: false,
      medicineCount: t.medicineCount - 1,
      happiness: t.happiness + 10,
    ));
  }
}
