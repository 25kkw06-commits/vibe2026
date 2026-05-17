import '../models/tamagotchi.dart';
import 'storage_service.dart';
import 'tamagotchi_service.dart';

/// 하루 점수(0~100) = 그날 마감 때 행복도. 직접 입력은 없음.
/// 날짜가 비었으면 첫 평가 때 하루씩 감쇠 돌려서 채우고 30일 리스트에 붙임.
/// 30일 찼으면 주기 완주(크레딧·초기화 예약), 그날은 더 안 이어감.
class DailyScoreService {
  DailyScoreService._();

  static int scoreFor(Tamagotchi t) {
    if (!t.isAlive) return 0;
    return t.happiness.clamp(0, 100);
  }

  static String _calendarStamp(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 마감 안 된 날은 자정까지 감쇠·로그 찍고, 마지막에 지금까지 한 번 더.
  /// 앱 안 켠 날도 같은 식으로 마감 행복도가 남음.
  static Future<Tamagotchi> advanceThroughClosedDaysAndDecayToNow(
    TamagotchiService tamSvc,
    StorageService storage,
    Tamagotchi loaded,
  ) async {
    await storage.ensureDailyScoreCursorInitialized();
    final today = Tamagotchi.todayStamp();
    final yesterday = _calendarStamp(
      DateTime.parse(today).subtract(const Duration(days: 1)),
    );
    final lastClosed = await storage.loadLastDailyScoreClosedDay();
    if (lastClosed == null) {
      return tamSvc.applyDecay(loaded);
    }
    if (lastClosed.compareTo(yesterday) >= 0) {
      return tamSvc.applyDecay(loaded);
    }

    await storage.finalizePastDaysIntoCumulative();

    var work = loaded;
    var cursor = _calendarStamp(
      DateTime.parse(lastClosed).add(const Duration(days: 1)),
    );

    while (cursor.compareTo(yesterday) <= 0 && work.isAlive) {
      final dayStart = DateTime.parse(cursor);
      final endOfDay = DateTime(dayStart.year, dayStart.month, dayStart.day)
          .add(const Duration(days: 1));

      work = tamSvc.applyDecayUpTo(work, endOfDay);

      final v = scoreFor(work);
      await storage.mergeDailyMinScore(cursor, v);
      final cycleJustCompleted = await storage.appendRankingCycleDayScore(v);

      var streak = work.severeNeglectStreakDays;
      if (TamagotchiService.isSevereNeglectState(work)) {
        streak++;
      } else {
        streak = 0;
      }

      if (streak >= TamagotchiService.severeNeglectDaysToDie) {
        work = work.copyWith(
          isAlive: false,
          happiness: 0,
          severeNeglectStreakDays: 0,
          diedFromNeglect: true,
        );
      } else {
        work = work.copyWith(severeNeglectStreakDays: streak);
      }

      await storage.setLastDailyScoreClosedDay(cursor);

      if (!work.isAlive) {
        return work;
      }

      if (cycleJustCompleted) {
        return tamSvc.applyDecay(work);
      }

      cursor = _calendarStamp(
        DateTime.parse(cursor).add(const Duration(days: 1)),
      );
    }

    if (!work.isAlive) return work;
    return tamSvc.applyDecay(work);
  }
}
