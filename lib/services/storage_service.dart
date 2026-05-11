import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_limit.dart';
import '../models/tamagotchi.dart';

/// 일일 점수·누적 마감: 날짜 키는 [Tamagotchi.todayStamp]와 같이 기기 로컬 기준.
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

  /// 다마고치가 죽고 새 게임을 시작할 때 모든 셋업을 초기화
  Future<void> resetAll() async {
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

  /// (먹이, 목욕, 놀기) 버튼 활성 스냅샷 — 알림 중복 방지용.
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

  /// 날짜(yyyy-MM-dd) → 그날 기록된 최저 점수.
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

  /// 지난날(어제까지) 일일 점수를 총 누적에 더한다. 여러 번 호출해도 하루는 한 번만 반영된다.
  Future<void> finalizePastDaysIntoCumulative() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = Tamagotchi.todayStamp();
    final yesterday = DateTime.parse(todayStr).subtract(const Duration(days: 1));
    final yesterdayStr = _dateStamp(yesterday);

    final scores = await loadDailyScores();
    var cumulative = prefs.getInt(_cumulativeCareKey) ?? 0;
    final lastStr = prefs.getString(_lastFinalizedCareDayKey);

    String nextStr;
    if (lastStr == null) {
      final pastKeys = scores.keys.where((k) => k.compareTo(todayStr) < 0).toList()
        ..sort();
      nextStr = pastKeys.isEmpty ? yesterdayStr : pastKeys.first;
    } else {
      if (lastStr.compareTo(yesterdayStr) >= 0) return;
      nextStr = _dateStamp(DateTime.parse(lastStr).add(const Duration(days: 1)));
    }

    while (nextStr.compareTo(yesterdayStr) <= 0) {
      cumulative += scores[nextStr] ?? 0;
      nextStr = _dateStamp(DateTime.parse(nextStr).add(const Duration(days: 1)));
    }

    await prefs.setInt(_cumulativeCareKey, cumulative);
    await prefs.setString(_lastFinalizedCareDayKey, yesterdayStr);
  }

  Future<int> loadCumulativeCareScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cumulativeCareKey) ?? 0;
  }

  /// 같은 날 여러 번 호출 시 [score]와 기존 값 중 더 작은 수만 남긴다.
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
}

String _dateStamp(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
