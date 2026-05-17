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

/// 백·포그 같은 평가 한 바퀴. 로드→평가→저장. 시각은 로컬.
Future<void> runEvaluationCycle() async {
  final storage = StorageService();
  await storage.processCareItemRegen();
  final svc = TamagotchiService(storage: storage);

  final t = await storage.loadTamagotchi();
  if (t == null || !t.isAlive) return;

  var next = await DailyScoreService.advanceThroughClosedDaysAndDecayToNow(
      svc, storage, t);
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
