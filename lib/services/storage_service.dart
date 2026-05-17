import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_limit.dart';
import '../models/tamagotchi.dart';

/// 주기 끝난 직후, 초기화 전 팝업용 값.
class CycleCompletePending {
  final int cycleSum;
  final int creditsGranted;

  const CycleCompletePending({
    required this.cycleSum,
    required this.creditsGranted,
  });
}

/// 일별 점수 맵 등. 날짜 키는 Tamagotchi.todayStamp()랑 같은 식(로컬).
class StorageService {
  static const _limitsKey = 'app_limits';
  static const _setupKey = 'setup_complete';
  static const _tamaKey = 'tamagotchi_state';
  static const _growthTutorialKey = 'growth_tutorial_shown';
  static const _actionSnapKey = 'action_buttons_enabled_snap';
  static const _notifRationaleKey = 'notification_rationale_done';
  static const _dailyScoresKey = 'daily_happiness_scores';
  static const _cumulativeCareKey = 'cumulative_care_score';
  static const _lastFinalizedCareDayKey = 'last_finalized_care_day';
  static const _themeModeKey = 'ui_theme_mode';

  /// 패키지명 → ISO8601. 그때까지 분 한도 수정 불가.
  static const _limitEditLocksKey = 'limit_edit_locked_until';
  static const _adminSimDayKey = 'admin_sim_day_index';

  /// 상점 돌봄템 가격(크레딧)
  static const shopFeedPrice = 12;
  static const shopSoapPrice = 12;
  static const shopToyPrice = 15;

  static const careRegenIntervalMinutes = 60;
  static const careRegenMaxPerTypePerDay = 8;

  /// 자동 보급만 적용. 상점 구매는 제한 없음.
  static const careInventorySoftCap = 99;
  static const _creditsKey = 'shop_credits';
  static const _shopFeedStockKey = 'shop_stock_feed';
  static const _shopSoapStockKey = 'shop_stock_soap';
  static const _shopToyStockKey = 'shop_stock_toy';

  /// 평가 돌 때마다: 간격마다 종류별 +1, 종류당 하루 상한은 careRegenMaxPerTypePerDay(자동분만).
  static const _careRegenLastAtKey = 'care_regen_last_at';
  static const _careRegenDayKey = 'care_regen_grant_day';
  static const _careRegenGrantedFeedKey = 'care_regen_granted_feed';
  static const _careRegenGrantedSoapKey = 'care_regen_granted_soap';
  static const _careRegenGrantedToyKey = 'care_regen_granted_toy';
  static const _lastDailyScoreClosedDayKey = 'last_daily_score_closed_day';
  static const _rankingCycleScoresKey = 'ranking_cycle_30_scores';

  /// 30일 마지막 마감 직후: 리셋·팝업 대기. null이면 없음.
  static const _pendingCycleFullResetKey = 'pending_cycle_full_reset_v1';

  // ---------- 앱 제한 ----------
  Future<List<AppLimit>> loadLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_limitsKey) ?? [];
    return raw.map(AppLimit.fromJson).toList();
  }

  Future<void> saveLimits(List<AppLimit> limits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _limitsKey,
      limits.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> upsertLimit(AppLimit limit) async {
    final limits = await loadLimits();
    final idx = limits.indexWhere((e) => e.packageName == limit.packageName);
    if (idx >= 0) {
      limits[idx] = limit;
    } else {
      limits.add(limit);
    }
    await saveLimits(limits);
  }

  Future<void> removeLimit(String packageName) async {
    final limits = await loadLimits();
    limits.removeWhere((e) => e.packageName == packageName);
    await saveLimits(limits);
    await clearLimitEditLock(packageName);
  }

  /// `system` | `light` | `dark`
  Future<String> loadThemeModeRaw() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> saveThemeModeRaw(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    const allowed = {'system', 'light', 'dark'};
    await prefs.setString(
      _themeModeKey,
      allowed.contains(mode) ? mode : 'system',
    );
  }

  // ---------- 한도 수정 잠금 (한도 초과 감지 시 7일) ----------
  Future<Map<String, DateTime>> _loadLimitEditLocks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_limitEditLocksKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final out = <String, DateTime>{};
      map.forEach((k, v) {
        final d = DateTime.tryParse(v as String? ?? '');
        if (d != null) out[k] = d;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLimitEditLocks(Map<String, DateTime> m) async {
    final prefs = await SharedPreferences.getInstance();
    final enc = m.map((k, v) => MapEntry(k, v.toIso8601String()));
    await prefs.setString(_limitEditLocksKey, json.encode(enc));
  }

  /// 처음 한도 넘긴 걸로 잡힐 때. 그 앱 분 한도 7일 고정.
  Future<void> recordLimitExceededForEditLock(String packageName) async {
    final now = DateTime.now();
    final proposedEnd = now.add(const Duration(days: 7));
    final locks = await _loadLimitEditLocks();
    final prev = locks[packageName];
    if (prev != null && prev.isAfter(proposedEnd)) return;
    locks[packageName] = proposedEnd;
    await _saveLimitEditLocks(locks);
  }

  /// 유효하면 잠금 끝나는 시각. 아니면 null.
  Future<DateTime?> limitEditLockedUntil(String packageName) async {
    final locks = await _loadLimitEditLocks();
    final end = locks[packageName];
    if (end == null || !end.isAfter(DateTime.now())) return null;
    return end;
  }

  /// 아직 안 끝난 잠금만. 리스트 UI용.
  Future<Map<String, DateTime>> loadActiveLimitEditLocks() async {
    final all = await _loadLimitEditLocks();
    final now = DateTime.now();
    return Map.fromEntries(
      all.entries.where((e) => e.value.isAfter(now)),
    );
  }

  Future<void> clearLimitEditLock(String packageName) async {
    final locks = await _loadLimitEditLocks();
    if (!locks.containsKey(packageName)) return;
    locks.remove(packageName);
    await _saveLimitEditLocks(locks);
  }

  // ---------- 셋업 잠금 ----------
  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupKey) ?? false;
  }

  Future<void> setSetupComplete(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, v);
  }

  /// preserveShopCredits면 타임 크레딧만 남김(30일 끝나고 다시 시작할 때).
  Future<void> resetAll({bool preserveShopCredits = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_limitsKey);
    await prefs.remove(_setupKey);
    await prefs.remove(_tamaKey);
    await prefs.remove(_growthTutorialKey);
    await prefs.remove(_actionSnapKey);
    await prefs.remove(_notifRationaleKey);
    await prefs.remove(_dailyScoresKey);
    await prefs.remove(_cumulativeCareKey);
    await prefs.remove(_lastFinalizedCareDayKey);
    await prefs.remove(_limitEditLocksKey);
    await prefs.remove(_adminSimDayKey);
    if (!preserveShopCredits) {
      await prefs.remove(_creditsKey);
    }
    await prefs.remove(_shopFeedStockKey);
    await prefs.remove(_shopSoapStockKey);
    await prefs.remove(_shopToyStockKey);
    await prefs.remove(_careRegenLastAtKey);
    await prefs.remove(_careRegenDayKey);
    await prefs.remove(_careRegenGrantedFeedKey);
    await prefs.remove(_careRegenGrantedSoapKey);
    await prefs.remove(_careRegenGrantedToyKey);
    await prefs.remove(_lastDailyScoreClosedDayKey);
    await prefs.remove(_rankingCycleScoresKey);
    await prefs.remove(_pendingCycleFullResetKey);
  }

  /// 주기 완주 안내 잠깐 저장. 없으면 null.
  Future<CycleCompletePending?> loadPendingCycleComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingCycleFullResetKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return CycleCompletePending(
        cycleSum: (m['cycleSum'] as num).toInt(),
        creditsGranted: (m['creditsGranted'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------- 다마고치 상태 ----------
  Future<Tamagotchi?> loadTamagotchi() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tamaKey);
    if (raw == null) return null;
    try {
      return Tamagotchi.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTamagotchi(Tamagotchi t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tamaKey, t.toJson());
  }

  Future<bool> wasGrowthTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_growthTutorialKey) ?? false;
  }

  Future<void> setGrowthTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_growthTutorialKey, true);
  }

  /// 돌봄 버튼 켜진 스냅샷. 막 열렸을 때 알림 한 번만.
  Future<(bool feed, bool bathe, bool play)?> loadActionEnabledSnap() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_actionSnapKey);
    if (s == null) return null;
    final parts = s.split(',');
    if (parts.length != 3) return null;
    return (parts[0] == '1', parts[1] == '1', parts[2] == '1');
  }

  Future<void> saveActionEnabledSnap(bool feed, bool bathe, bool play) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _actionSnapKey,
      '${feed ? 1 : 0},${bathe ? 1 : 0},${play ? 1 : 0}',
    );
  }

  Future<bool> wasNotificationRationaleShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifRationaleKey) ?? false;
  }

  Future<void> setNotificationRationaleShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifRationaleKey, true);
  }

  /// yyyy-MM-dd → 그날 기록한 최저 점수.
  Future<Map<String, int>> loadDailyScores() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dailyScoresKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// 옛날 일별 점수를 누적에 더함. 하루는 한 번만.
  Future<void> finalizePastDaysIntoCumulative() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = Tamagotchi.todayStamp();
    final yesterday =
        DateTime.parse(todayStr).subtract(const Duration(days: 1));
    final yesterdayStr = _dateStamp(yesterday);

    final lastStr = prefs.getString(_lastFinalizedCareDayKey);
    if (lastStr != null && lastStr.compareTo(yesterdayStr) >= 0) return;

    final scores = await loadDailyScores();
    var cumulative = prefs.getInt(_cumulativeCareKey) ?? 0;

    final toAdd = scores.keys.where((k) {
      if (k.compareTo(todayStr) >= 0) return false;
      if (k.compareTo(yesterdayStr) > 0) return false;
      if (lastStr != null && k.compareTo(lastStr) <= 0) return false;
      return true;
    });

    for (final k in toAdd) {
      cumulative += scores[k] ?? 0;
    }

    await prefs.setInt(_cumulativeCareKey, cumulative);
    await prefs.setString(_lastFinalizedCareDayKey, yesterdayStr);
  }

  Future<int> loadCumulativeCareScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cumulativeCareKey) ?? 0;
  }

  /// 같은 날 여러 번이면 score랑 기존값 중 작은 쪽만.
  Future<void> mergeDailyMinScore(String dateStamp, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadDailyScores();
    final prev = existing[dateStamp];
    if (prev == null) {
      existing[dateStamp] = score;
    } else {
      existing[dateStamp] = prev < score ? prev : score;
    }
    const maxDays = 120;
    if (existing.length > maxDays) {
      final keys = existing.keys.toList()..sort();
      for (var i = 0; i < keys.length - maxDays; i++) {
        existing.remove(keys[i]);
      }
    }
    await prefs.setString(_dailyScoresKey, json.encode(existing));
  }

  /// 일별 마감 커서 없으면 만들기. 맵 있으면 마지막 날, 없으면 어제부터.
  Future<void> ensureDailyScoreCursorInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastDailyScoreClosedDayKey) != null) return;
    final existing = await loadDailyScores();
    if (existing.isNotEmpty) {
      final sorted = existing.keys.toList()..sort();
      await prefs.setString(_lastDailyScoreClosedDayKey, sorted.last);
      return;
    }
    final n = DateTime.now();
    final y =
        DateTime(n.year, n.month, n.day).subtract(const Duration(days: 1));
    await prefs.setString(_lastDailyScoreClosedDayKey, _dateStamp(y));
  }

  Future<String?> loadLastDailyScoreClosedDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDailyScoreClosedDayKey);
  }

  Future<void> setLastDailyScoreClosedDay(String yyyyMmDd) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDailyScoreClosedDayKey, yyyyMmDd);
  }

  // ---------- 30일 랭킹(1~30일차) ----------

  /// 30일 합(최대 3000) 비례해서 크레딧.
  static int creditsForCompletedRankingCycle(int cycleSum) {
    return ((cycleSum * 5) ~/ 100).clamp(0, 150);
  }

  Future<List<int>> loadRankingCycleScores() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rankingCycleScoresKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRankingCycleScores(List<int> scores) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rankingCycleScoresKey, json.encode(scores));
  }

  /// 하루치 30일 리스트에 추가. 이미 30개면 주기 끝 → 크레딧·비우기·초기화 예약.
  /// 그날 점수는 새 주기에 안 넣음.
  /// true면 이번 평가 루프에서 더 마감일 진행 말 것.
  Future<bool> appendRankingCycleDayScore(int score) async {
    var list = await loadRankingCycleScores();
    if (list.length >= 30) {
      final sum = list.fold<int>(0, (a, b) => a + b);
      final add = StorageService.creditsForCompletedRankingCycle(sum);
      if (add > 0) await addCredits(add);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingCycleFullResetKey,
        json.encode({
          'cycleSum': sum,
          'creditsGranted': add,
        }),
      );
      list = [];
      await _saveRankingCycleScores(list);
      return true;
    }
    list.add(score.clamp(0, 100));
    await _saveRankingCycleScores(list);
    return false;
  }

  // ---------- 상점(돌봄템 재고) ----------

  /// 살아 있을 때만. 평가 돌 때마다 자동 보급 타이머 진행(개수 증가).
  Future<void> processCareItemRegen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tamaKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final t = Tamagotchi.fromJson(raw);
      if (!t.isAlive) return;
    } catch (_) {
      return;
    }

    final now = DateTime.now();
    final today = Tamagotchi.todayStamp();
    final lastStr = prefs.getString(_careRegenLastAtKey);

    if (lastStr == null) {
      var feed = prefs.getInt(_shopFeedStockKey) ?? 0;
      var soap = prefs.getInt(_shopSoapStockKey) ?? 0;
      var toy = prefs.getInt(_shopToyStockKey) ?? 0;
      if (feed + soap + toy == 0) {
        feed = 2;
        soap = 2;
        toy = 2;
      }
      await prefs.setInt(_shopFeedStockKey, feed);
      await prefs.setInt(_shopSoapStockKey, soap);
      await prefs.setInt(_shopToyStockKey, toy);
      await prefs.setString(_careRegenLastAtKey, now.toIso8601String());
      await prefs.setString(_careRegenDayKey, today);
      await prefs.setInt(_careRegenGrantedFeedKey, 0);
      await prefs.setInt(_careRegenGrantedSoapKey, 0);
      await prefs.setInt(_careRegenGrantedToyKey, 0);
      return;
    }

    var last = DateTime.parse(lastStr);
    var grantDay = prefs.getString(_careRegenDayKey) ?? today;
    var gFeed = prefs.getInt(_careRegenGrantedFeedKey) ?? 0;
    var gSoap = prefs.getInt(_careRegenGrantedSoapKey) ?? 0;
    var gToy = prefs.getInt(_careRegenGrantedToyKey) ?? 0;

    var feed = prefs.getInt(_shopFeedStockKey) ?? 0;
    var soap = prefs.getInt(_shopSoapStockKey) ?? 0;
    var toy = prefs.getInt(_shopToyStockKey) ?? 0;

    const step = Duration(minutes: careRegenIntervalMinutes);
    var guard = 0;
    while (!last.add(step).isAfter(now)) {
      if (guard++ > 2000) break;
      last = last.add(step);
      final stamp = _dateStamp(last);
      if (stamp != grantDay) {
        grantDay = stamp;
        gFeed = 0;
        gSoap = 0;
        gToy = 0;
      }
      if (gFeed < careRegenMaxPerTypePerDay && feed < careInventorySoftCap) {
        feed++;
        gFeed++;
      }
      if (gSoap < careRegenMaxPerTypePerDay && soap < careInventorySoftCap) {
        soap++;
        gSoap++;
      }
      if (gToy < careRegenMaxPerTypePerDay && toy < careInventorySoftCap) {
        toy++;
        gToy++;
      }
    }

    await prefs.setString(_careRegenLastAtKey, last.toIso8601String());
    await prefs.setString(_careRegenDayKey, grantDay);
    await prefs.setInt(_careRegenGrantedFeedKey, gFeed);
    await prefs.setInt(_careRegenGrantedSoapKey, gSoap);
    await prefs.setInt(_careRegenGrantedToyKey, gToy);
    await prefs.setInt(_shopFeedStockKey, feed);
    await prefs.setInt(_shopSoapStockKey, soap);
    await prefs.setInt(_shopToyStockKey, toy);
  }

  Future<(int feed, int soap, int toy)> loadShopCareStocks() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getInt(_shopFeedStockKey) ?? 0,
      prefs.getInt(_shopSoapStockKey) ?? 0,
      prefs.getInt(_shopToyStockKey) ?? 0,
    );
  }

  Future<bool> _tryConsumeStockKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getInt(key) ?? 0;
    if (n <= 0) return false;
    await prefs.setInt(key, n - 1);
    return true;
  }

  Future<bool> tryConsumeShopFeedStock() =>
      _tryConsumeStockKey(_shopFeedStockKey);

  Future<bool> tryConsumeShopSoapStock() =>
      _tryConsumeStockKey(_shopSoapStockKey);

  Future<bool> tryConsumeShopToyStock() =>
      _tryConsumeStockKey(_shopToyStockKey);

  Future<bool> _purchaseOne(String stockKey, int price) async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getInt(_creditsKey) ?? 0;
    if (c < price) return false;
    final stock = prefs.getInt(stockKey) ?? 0;
    await prefs.setInt(_creditsKey, c - price);
    await prefs.setInt(stockKey, stock + 1);
    return true;
  }

  Future<bool> purchaseShopFeed() =>
      _purchaseOne(_shopFeedStockKey, shopFeedPrice);

  Future<bool> purchaseShopSoap() =>
      _purchaseOne(_shopSoapStockKey, shopSoapPrice);

  Future<bool> purchaseShopToy() =>
      _purchaseOne(_shopToyStockKey, shopToyPrice);

  // ---------- 관리자 빌드(ADMIN_MODE) 디버깅용 — 일반 앱에는 진입 UI 없음 ----------

  /// 30일 칸만 비움. 마감 커서는 안 건드림(admin).
  Future<void> adminClearRankingCycle() async {
    await _saveRankingCycleScores([]);
  }

  /// 누적 돌봄 점수에 delta 더하기. 확인용.
  Future<void> adminAddCumulativeCareScore(int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_cumulativeCareKey) ?? 0) + delta;
    await prefs.setInt(_cumulativeCareKey, v);
  }

  /// 일별 맵에서 한 줄 지우기. 테스트 정리.
  Future<void> adminRemoveDailyScore(String dateStamp) async {
    final existing = await loadDailyScores();
    if (!existing.containsKey(dateStamp)) return;
    existing.remove(dateStamp);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyScoresKey, json.encode(existing));
  }

  /// admin 「하루」 시뮬용. 2020-01-01부터 순서 배정.
  Future<String> adminAllocNextSimDayStamp() async {
    final prefs = await SharedPreferences.getInstance();
    var i = prefs.getInt(_adminSimDayKey) ?? 0;
    final stamp = _dateStamp(DateTime(2020, 1, 1).add(Duration(days: i)));
    i++;
    await prefs.setInt(_adminSimDayKey, i);
    return stamp;
  }

  Future<void> adminResetSimDayIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_adminSimDayKey);
  }

  Future<int> loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_creditsKey) ?? 0;
  }

  Future<void> addCredits(int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_creditsKey) ?? 0) + delta;
    await prefs.setInt(_creditsKey, v.clamp(0, 1 << 30));
  }
}

String _dateStamp(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
