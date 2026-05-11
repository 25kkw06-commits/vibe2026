import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/tamagotchi.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@drawable/ic_launcher_timegotchi');
    await _plugin.initialize(const InitializationSettings(android: android));
    _initialized = true;
  }

  /// 앱 시작·인트로 이후 한 번 호출해 알림 권한을 요청할 때 사용.
  static Future<void> requestAndroidPostNotificationPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 스탯 악화·병 등 (연속 알림 방지: 한 전환에서 한 번씩)
  static Future<void> notifyCareTransition(
    Tamagotchi before,
    Tamagotchi after,
  ) async {
    if (!after.isAlive) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'care_channel',
        '타임고치 돌봄',
        channelDescription: '배고픔·청결·행복 상태 알림',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    if (after.hunger > 85 && before.hunger <= 85) {
      await _plugin.show(
        91002,
        '배고파해요',
        '${after.name}에게 먹이를 주세요',
        details,
      );
    }
    if (after.cleanliness < 20 && before.cleanliness >= 20) {
      await _plugin.show(
        91003,
        '더러워졌어요',
        '${after.name}에게 목욕을 시켜 주세요',
        details,
      );
    }
    if (after.happiness < 20 && before.happiness >= 20) {
      await _plugin.show(
        91004,
        '우울해요',
        '${after.name}와 놀아 주세요',
        details,
      );
    }
  }

  static Future<void> showLimitReached({
    required String tamaName,
    required String appName,
    required int limitMinutes,
    required int usedMinutes,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'limit_channel',
        '사용시간 제한 알림',
        channelDescription: '설정한 앱 사용 시간을 초과했을 때 알림',
        importance: Importance.max,
        priority: Priority.max,
      ),
    );
    await _plugin.show(
      appName.hashCode & 0x7fffffff,
      '⏰ $appName 사용 제한 도달',
      '제한 $limitMinutes분 / 오늘 $usedMinutes분 사용\n'
          '$tamaName이(가) 한도 초과로 병에 걸렸어요',
      details,
    );
  }

  /// 한도 초과이나 오늘 병(누적 카운트)은 이미 2번까지 반영됨.
  static Future<void> showLimitReachedDayCapped({
    required String appName,
    required int limitMinutes,
    required int usedMinutes,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'limit_channel',
        '사용시간 제한 알림',
        channelDescription: '설정한 앱 사용 시간을 초과했을 때 알림',
        importance: Importance.max,
        priority: Priority.max,
      ),
    );
    await _plugin.show(
      ('cap_$appName').hashCode & 0x7fffffff,
      '⏰ $appName 한도 초과',
      '제한 $limitMinutes분 / 오늘 $usedMinutes분\n'
          '오늘 이 한도로 쌓이는 병은 최대 2번까지예요',
      details,
    );
  }

  static Future<void> showActionReady({
    required String tamaName,
    required String label,
    required String body,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'action_ready_channel',
        '돌봄 행동 가능',
        channelDescription: '먹이·목욕·놀이를 할 수 있을 때',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    final id = switch (label) {
      '먹이' => 92011,
      '목욕' => 92012,
      '놀기' => 92013,
      _ => 92019,
    };
    await _plugin.show(
      id,
      '$label 가능 · $tamaName',
      body,
      details,
    );
  }

  static Future<void> showWarning({
    required String appName,
    required int remainingMinutes,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'warn_channel',
        '사용시간 경고',
        channelDescription: '제한 시간이 가까워졌을 때 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      ('warn_$appName').hashCode & 0x7fffffff,
      '⚠️ $appName 사용시간 $remainingMinutes분 남음',
      '곧 제한 시간에 도달합니다',
      details,
    );
  }
}
