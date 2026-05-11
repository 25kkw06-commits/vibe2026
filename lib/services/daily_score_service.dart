import '../models/tamagotchi.dart';
import 'storage_service.dart';

/// 하루 동안의 '돌봄 점수'(0~100). 그날 측정값 중 가장 낮은 것만 저장한다.
/// 날짜가 바뀌면 전날 점수가 [StorageService.finalizePastDaysIntoCumulative]로 누적된다.
/// 스냅샷 일자는 [Tamagotchi.todayStamp] = 기기 로컬 날짜.
class DailyScoreService {
  DailyScoreService._();

  /// 아픔·사망 → 0. 배고픔·청결·행복이 기준을 넘기면 감점(누적).
  static int scoreFor(Tamagotchi t) {
    if (!t.isAlive) return 0;
    if (t.isSick) return 0;
    var s = 100;
    if (t.hunger >= 85) {
      s -= 45;
    } else if (t.hunger >= 75) {
      s -= 32;
    } else if (t.hunger >= 65) {
      s -= 20;
    } else if (t.hunger >= 55) {
      s -= 10;
    }
    if (t.cleanliness <= 20) {
      s -= 45;
    } else if (t.cleanliness <= 35) {
      s -= 32;
    } else if (t.cleanliness <= 50) {
      s -= 18;
    } else if (t.cleanliness <= 62) {
      s -= 8;
    }
    if (t.happiness <= 20) {
      s -= 45;
    } else if (t.happiness <= 38) {
      s -= 30;
    } else if (t.happiness <= 52) {
      s -= 16;
    } else if (t.happiness <= 62) {
      s -= 7;
    }
    return s.clamp(0, 100);
  }

  static Future<void> recordSnapshot(StorageService storage, Tamagotchi t) async {
    await storage.finalizePastDaysIntoCumulative();
    final day = Tamagotchi.todayStamp();
    final v = scoreFor(t);
    await storage.mergeDailyMinScore(day, v);
  }
}
