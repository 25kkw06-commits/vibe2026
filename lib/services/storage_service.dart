import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_limit.dart';
import '../models/tamagotchi.dart';

class StorageService {
  static const _limitsKey = 'app_limits';
  static const _setupKey = 'setup_complete';
  static const _tamaKey = 'tamagotchi_state';

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
}
