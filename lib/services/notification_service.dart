import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  static Future<void> showLimitReached({
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
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      appName.hashCode,
      '⏰ $appName 사용 제한 도달',
      '제한 ${limitMinutes}분 / 오늘 사용 ${usedMinutes}분',
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
      ('warn_$appName').hashCode,
      '⚠️ $appName 사용시간 ${remainingMinutes}분 남음',
      '곧 제한 시간에 도달합니다',
      details,
    );
  }
}
