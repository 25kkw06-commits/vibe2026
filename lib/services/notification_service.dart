import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/tamagotchi.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android =
        AndroidInitializationSettings('@drawable/ic_launcher_timegotchi');
    await _plugin.initialize(const InitializationSettings(android: android));
    _initialized = true;
  }

  /// 인트로 지나서 알림 권한 한 번 요청할 때.
  static Future<void> requestAndroidPostNotificationPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 스탯 나빠짐·병 등. 전환당 알림 한 번.
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
        '${after.name}에게 사료를 주세요',
        details,
      );
    }
    if (after.cleanliness < 20 && before.cleanliness >= 20) {
      await _plugin.show(
        91003,
        '더러워졌어요',
        '${after.name}에게 비누로 씻겨 주세요',
        details,
      );
    }
    if (after.happiness < 20 && before.happiness >= 20) {
      await _plugin.show(
        91004,
        '우울해요',
        '${after.name}와 장난감으로 놀아 주세요',
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
      '$appName 한도 도달',
      '제한 $limitMinutes분 / 오늘 $usedMinutes분\n'
          '$tamaName 한도 초과 병',
      details,
    );
  }

  /// 오늘 한도 병은 이미 2번까지 반영된 뒤.
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
      '$appName 한도 초과',
      '제한 $limitMinutes분 / 오늘 $usedMinutes분\n'
          '오늘 병 카운트는 최대 2번',
      details,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await init();
    await _plugin.cancelAll();
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
        channelDescription: '사료·비누·장난감이 준비됐을 때 알림',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    final id = switch (label) {
      '사료' => 92011,
      '비누' => 92012,
      '장난감' => 92013,
      _ => 92019,
    };
    await _plugin.show(
      id,
      '$tamaName · $label',
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
      '$appName · $remainingMinutes분 남음',
      '한도 임박',
      details,
    );
  }
}
