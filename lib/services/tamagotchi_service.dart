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

/// 한도·치료제·날짜 갱신: [DateTime.now]·[Tamagotchi.todayStamp] = 기기 로컬 달력 기준.
class TamagotchiService {
  final StorageService _storage;
  final UsageService _usage;

  // 돌보기 액션 제한치 (쿨타임 동안 자연 감쇠가 체감되도록 길게)
  static const feedCooldownMin = 180; // 3시간 · 배고픔 약 +21
  static const batheCooldownMin = 240; // 4시간
  static const playCooldownMin = 180; // 3시간
  static const feedHungerMin = 22; // 이 미만이면 안 먹음
  static const batheCleanMax = 80; // 이 초과면 안 씻음
  static const playHappyMax = 85; // 이 초과면 안 놂

  TamagotchiService({StorageService? storage, UsageService? usage})
      : _storage = storage ?? StorageService(),
        _usage = usage ?? UsageService();

  /// 시간 경과에 따른 스탯 자연 감쇠.
  /// 1시간당: 배고픔 +7, 청결 -4, 행복 -5 (3h 쿨타임 시 배고픔 +21 전후)
  Tamagotchi applyDecay(Tamagotchi t) {
    if (!t.isAlive) return t;
    final now = DateTime.now();
    final hours = now.difference(t.lastDecayAt).inMinutes / 60.0;
    if (hours <= 0) return t;
    final hungerInc = (hours * 7).round();
    final cleanDec = (hours * 4).round();
    final happyDec = (hours * 5).round();
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
      final granted = await _medicineEligibleFromYesterday(limits);
      current = current.copyWith(
        medicineCount: current.medicineCount + (granted ? 1 : 0),
        lastEvaluatedDate: today,
        exceededTodayPackages: const [],
        limitSickCountToday: 0,
      );
    }

    final usageMap = await _usage.getTodayUsageMinutes();
    var alreadyExceeded = current.exceededTodayPackages.toSet();
    var limitSickToday = current.limitSickCountToday;

    for (final l in limits) {
      if (!l.enabled || l.limitMinutes <= 0) continue;
      final used = usageMap[l.packageName] ?? 0;
      if (used < l.limitMinutes) continue;
      if (alreadyExceeded.contains(l.packageName)) continue;
      alreadyExceeded = {...alreadyExceeded, l.packageName};
      await _storage.recordLimitExceededForEditLock(l.packageName);

      if (limitSickToday < 2) {
        limitSickToday++;
        final newCount = current.sicknessCount + 1;
        current = current.copyWith(
          limitSickCountToday: limitSickToday,
          sicknessCount: newCount,
          isSick: true,
          happiness: current.happiness - 15,
          isAlive: newCount < 3,
          exceededTodayPackages: alreadyExceeded.toList(),
        );
        try {
          await NotificationService.showLimitReached(
            tamaName: current.name,
            appName: l.appName,
            limitMinutes: l.limitMinutes,
            usedMinutes: used,
          );
        } catch (_) {}
        if (newCount >= 3) return current;
      } else {
        current = current.copyWith(
          exceededTodayPackages: alreadyExceeded.toList(),
        );
        try {
          await NotificationService.showLimitReachedDayCapped(
            appName: l.appName,
            limitMinutes: l.limitMinutes,
            usedMinutes: used,
          );
        } catch (_) {}
      }
    }

    return current;
  }

  /// 어제(자정~자정) 동안 켜 둔 **모든** 추적 앱이 각 한도를 넘기지 않았으면 치료제 1개.
  Future<bool> _medicineEligibleFromYesterday(List<AppLimit> limits) async {
    final tracked =
        limits.where((l) => l.enabled && l.limitMinutes > 0).toList();
    if (tracked.isEmpty) return false;

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));
    try {
      final yesterdayMap =
          await _usage.getUsageMinutesInRange(startYesterday, startToday);
      for (final l in tracked) {
        final used = yesterdayMap[l.packageName] ?? 0;
        if (used > l.limitMinutes) return false;
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

  /// 메인 화면 버튼과 동일 기준으로 활성 여부 (먹이·목욕·놀기).
  (bool feed, bool bathe, bool play) actionButtonsEnabled(Tamagotchi t) {
    if (!t.isAlive) return (false, false, false);
    final feedCool = cooldownRemaining(t.lastFedAt, feedCooldownMin) > 0;
    final batheCool = cooldownRemaining(t.lastBathedAt, batheCooldownMin) > 0;
    final playCool = cooldownRemaining(t.lastPlayedAt, playCooldownMin) > 0;
    return (
      !feedCool && t.hunger >= feedHungerMin,
      !batheCool && t.cleanliness <= batheCleanMax,
      !playCool && t.happiness <= playHappyMax,
    );
  }

  /// 사용자 액션 직후 스냅샷만 맞춤 (잘못된 '방금 활성화' 알림 방지).
  Future<void> syncActionButtonSnapshot(StorageService storage, Tamagotchi t) async {
    final n = actionButtonsEnabled(t);
    await storage.saveActionEnabledSnap(n.$1, n.$2, n.$3);
  }

  /// 이전 스냅샷 대비 버튼이 막 풀렸을 때 알림.
  Future<void> checkNotifyActionButtonsAvailable(
    StorageService storage,
    Tamagotchi t,
  ) async {
    if (!t.isAlive) return;
    final prev = await storage.loadActionEnabledSnap();
    final now = actionButtonsEnabled(t);
    await storage.saveActionEnabledSnap(now.$1, now.$2, now.$3);
    if (prev == null) return;
    final (pf, pb, pp) = prev;
    if (!pf && now.$1) {
      await NotificationService.showActionReady(
        tamaName: t.name,
        label: '먹이',
        body: '먹이를 줄 수 있어요',
      );
    }
    if (!pb && now.$2) {
      await NotificationService.showActionReady(
        tamaName: t.name,
        label: '목욕',
        body: '목욕을 시킬 수 있어요',
      );
    }
    if (!pp && now.$3) {
      await NotificationService.showActionReady(
        tamaName: t.name,
        label: '놀기',
        body: '같이 놀아 줄 수 있어요',
      );
    }
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
