import '../models/app_limit.dart';
import '../models/tamagotchi.dart';
import 'storage_service.dart';
import 'usage_service.dart';
import 'notification_service.dart';

/// 성공 시 tama, 실패 시 error.
class ActionResult {
  final Tamagotchi tama;
  final String? error;
  const ActionResult.ok(this.tama) : error = null;
  const ActionResult.fail(this.tama, this.error);
  bool get success => error == null;
}

/// 날짜·한도는 전부 기기 로컬.
class TamagotchiService {
  final StorageService _storage;
  final UsageService _usage;

  static const feedHungerMin = 22; // 이 미만이면 안 먹음
  static const batheCleanMax = 80; // 이 초과면 안 씻음
  static const playHappyMax = 85; // 이 초과면 안 놂

  /// 자정 마감 시 이 스탬프면 방치 일수 +1.
  static const severeNeglectMinHunger = 95;
  static const severeNeglectMaxCleanliness = 5;

  /// 이 일수 연속이면 방치 사망.
  static const severeNeglectDaysToDie = 3;

  static bool isSevereNeglectState(Tamagotchi t) {
    if (!t.isAlive) return false;
    return t.hunger >= severeNeglectMinHunger &&
        t.cleanliness <= severeNeglectMaxCleanliness;
  }

  // 알림 문구용 이름

  static const careItemFeed = '사료';
  static const careItemBathe = '비누';
  static const careItemPlay = '장난감';

  TamagotchiService({StorageService? storage, UsageService? usage})
      : _storage = storage ?? StorageService(),
        _usage = usage ?? UsageService();

  // 시간당 배고픔+7 청결-4, 행복은 배고픔/청결에 따라 더 깎임. 병 중 행복 0.
  Tamagotchi applyDecay(Tamagotchi t) => applyDecayUpTo(t, DateTime.now());

  /// 마감일 끝 시각까지 감쇠 (end > lastDecayAt).
  Tamagotchi applyDecayUpTo(Tamagotchi t, DateTime end) {
    if (!t.isAlive) return t;
    final hours = end.difference(t.lastDecayAt).inMinutes / 60.0;
    if (hours <= 0) return t;

    final hungerInc = (hours * 7).round();
    final cleanDec = (hours * 4).round();

    final newHunger = (t.hunger + hungerInc).clamp(0, 100);
    final newClean = (t.cleanliness - cleanDec).clamp(0, 100);

    final sick = t.isSick;
    // 포만·깨끗할수록 기본 우울 감쇠 완화 + 소폭 회복 (병 중에는 회복량만 조금 낮춤)
    final wellCared = newHunger <= 42 && newClean >= 58;
    final baseHappyDec = (hours * (wellCared ? 3.0 : 5.0)).round();
    final careBump = wellCared ? ((sick ? 1.5 : 2.5) * hours).round() : 0;

    final hn = newHunger / 100.0;
    final cn = (100 - newClean) / 100.0;
    var stressDec = ((hn * 6.0 + cn * 6.0) * hours).round();
    if (sick) {
      stressDec += (hours * 1.2).round();
    }

    var newHappy = t.happiness - baseHappyDec - stressDec + careBump;
    newHappy = newHappy.clamp(0, 100);

    return t.copyWith(
      hunger: newHunger,
      cleanliness: newClean,
      happiness: newHappy,
      lastDecayAt: end,
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
          happiness: 0,
          isAlive: newCount < 3,
          diedFromNeglect: false,
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

  /// 어제 하루 추적 앱 전부 한도 안 넘었으면 약 +1.
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

  (bool feed, bool bathe, bool play) actionButtonsEnabled(Tamagotchi t) =>
      careActionsEnabled(t);

  /// 재고 있어야 누름. 보급은 StorageService.processCareItemRegen.
  (bool feed, bool bathe, bool play) careActionsEnabled(
    Tamagotchi t, {
    int shopFeed = 0,
    int shopSoap = 0,
    int shopToy = 0,
  }) {
    if (!t.isAlive) return (false, false, false);
    return (
      shopFeed > 0 && t.hunger >= feedHungerMin,
      shopSoap > 0 && t.cleanliness <= batheCleanMax,
      shopToy > 0 && t.happiness <= playHappyMax,
    );
  }

  /// 액션 후 알림용 버튼 상태 스냅샷.
  Future<void> syncActionButtonSnapshot(
      StorageService storage, Tamagotchi t) async {
    final shop = await storage.loadShopCareStocks();
    final n = careActionsEnabled(
      t,
      shopFeed: shop.$1,
      shopSoap: shop.$2,
      shopToy: shop.$3,
    );
    await storage.saveActionEnabledSnap(n.$1, n.$2, n.$3);
  }

  /// 재고 생겨서 버튼 풀리면 알림.
  Future<void> checkNotifyActionButtonsAvailable(
    StorageService storage,
    Tamagotchi t,
  ) async {
    if (!t.isAlive) return;
    final shop = await storage.loadShopCareStocks();
    final prev = await storage.loadActionEnabledSnap();
    final now = careActionsEnabled(
      t,
      shopFeed: shop.$1,
      shopSoap: shop.$2,
      shopToy: shop.$3,
    );
    await storage.saveActionEnabledSnap(now.$1, now.$2, now.$3);
    if (prev == null) return;
    final (pf, pb, pp) = prev;
    if (!pf && now.$1) {
      await NotificationService.showActionReady(
        tamaName: t.name,
        label: careItemFeed,
        body: '사료 줄 수 있음',
      );
    }
    if (!pb && now.$2) {
      await NotificationService.showActionReady(
        tamaName: t.name,
        label: careItemBathe,
        body: '씻길 수 있음',
      );
    }
    if (!pp && now.$3) {
      await NotificationService.showActionReady(
        tamaName: t.name,
        label: careItemPlay,
        body: '놀아 줄 수 있음',
      );
    }
  }

  // ---------- 액션 ----------

  Future<ActionResult> tryFeed(Tamagotchi t) async {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (t.hunger < feedHungerMin) {
      return ActionResult.fail(t, '배가 안 고파요');
    }
    final ok = await _storage.tryConsumeShopFeedStock();
    if (!ok) return ActionResult.fail(t, '사료가 없어요');
    return ActionResult.ok(t.copyWith(
      hunger: t.hunger - 30,
      happiness: t.happiness + 5,
    ));
  }

  Future<ActionResult> tryBathe(Tamagotchi t) async {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (t.cleanliness > batheCleanMax) {
      return ActionResult.fail(t, '이미 깨끗해요');
    }
    final ok = await _storage.tryConsumeShopSoapStock();
    if (!ok) return ActionResult.fail(t, '비누가 없어요');
    return ActionResult.ok(t.copyWith(
      cleanliness: t.cleanliness + 40,
      happiness: t.happiness + 3,
    ));
  }

  Future<ActionResult> tryPlay(Tamagotchi t) async {
    if (!t.isAlive) return ActionResult.fail(t, '돌볼 수 없어요');
    if (t.happiness > playHappyMax) {
      return ActionResult.fail(t, '기분이 이미 좋아요');
    }
    final ok = await _storage.tryConsumeShopToyStock();
    if (!ok) return ActionResult.fail(t, '장난감이 없어요');
    return ActionResult.ok(t.copyWith(
      happiness: t.happiness + 35,
      hunger: t.hunger + 5,
      cleanliness: t.cleanliness - 5,
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
