import 'package:workmanager/workmanager.dart';
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
/// 다마고치 상태를 불러와 평가 → 저장한다.
Future<void> runEvaluationCycle() async {
  final storage = StorageService();
  final svc = TamagotchiService(storage: storage);

  final t = await storage.loadTamagotchi();
  if (t == null || !t.isAlive) return;

  final updated = await svc.evaluateUsage(svc.applyDecay(t));
  await storage.saveTamagotchi(updated);
}

Future<void> registerPeriodicCheck() async {
  await Workmanager().initialize(backgroundDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'usage-check-periodic',
    kUsageCheckTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
