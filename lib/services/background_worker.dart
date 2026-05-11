import 'package:workmanager/workmanager.dart';
import 'daily_score_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'tamagotchi_service.dart';

const String kUsageCheckTask = 'usage_check_task';

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kUsageCheckTask) return true;
    try {
      await runEvaluationCycle();
    } catch (_) {}
    return true;
  });
}

/// 백그라운드/포그라운드 어디서든 호출 가능한 평가 사이클.
/// 다마고치 상태를 불러와 평가 → 저장한다. 시각·일자는 기기 로컬 기준.
Future<void> runEvaluationCycle() async {
  final storage = StorageService();
  final svc = TamagotchiService(storage: storage);

  final t = await storage.loadTamagotchi();
  if (t == null || !t.isAlive) return;

  var next = svc.applyDecay(t);
  await NotificationService.notifyCareTransition(t, next);
  final prev = next;
  next = await svc.evaluateUsage(next);
  await NotificationService.notifyCareTransition(prev, next);
  if (next.isAlive) {
    await svc.checkNotifyActionButtonsAvailable(storage, next);
  } else {
    await storage.saveActionEnabledSnap(false, false, false);
  }
  await storage.saveTamagotchi(next);
  await DailyScoreService.recordSnapshot(storage, next);
}

Future<void> registerPeriodicCheck() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    'usage-check-periodic',
    kUsageCheckTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}
