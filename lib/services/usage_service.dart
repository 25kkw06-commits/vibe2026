import 'package:usage_stats/usage_stats.dart';

/// 오늘·구간 집계: [DateTime]이 기기 로컬 자정 경계와 맞춤(시스템 타임존).
class UsageService {
  Future<bool> hasPermission() async {
    return (await UsageStats.checkUsagePermission()) ?? false;
  }

  Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  Future<Map<String, int>> getTodayUsageMinutes() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return getUsageMinutesInRange(start, now);
  }

  Future<Map<String, int>> getUsageMinutesInRange(
      DateTime start, DateTime end) async {
    final stats = await UsageStats.queryUsageStats(start, end);
    final Map<String, int> result = {};
    for (final s in stats) {
      final pkg = s.packageName;
      final ms = int.tryParse(s.totalTimeInForeground ?? '0') ?? 0;
      if (pkg == null || ms <= 0) continue;
      final minutes = (ms / 60000).round();
      result[pkg] = (result[pkg] ?? 0) + minutes;
    }
    return result;
  }

  Future<int> getUsageMinutesFor(String packageName) async {
    final all = await getTodayUsageMinutes();
    return all[packageName] ?? 0;
  }
}
