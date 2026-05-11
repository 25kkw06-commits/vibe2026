import 'package:flutter/material.dart';

import 'screens/setup_intro_screen.dart';
import 'screens/tamagotchi_screen.dart';
import 'services/background_worker.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  try {
    await registerPeriodicCheck();
  } catch (_) {}
  runApp(const UsageTrackerApp());
}

class UsageTrackerApp extends StatelessWidget {
  const UsageTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '타임고치',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      home: const _RootDispatcher(),
    );
  }
}

/// 셋업 완료 여부와 다마고치 생존 여부를 보고
/// 셋업 인트로 / 다마고치 화면으로 분기한다.
class _RootDispatcher extends StatefulWidget {
  const _RootDispatcher();

  @override
  State<_RootDispatcher> createState() => _RootDispatcherState();
}

class _RootDispatcherState extends State<_RootDispatcher> {
  final _storage = StorageService();
  Widget? _next;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final setup = await _storage.isSetupComplete();
    final tama = await _storage.loadTamagotchi();

    Widget next;
    if (!setup || tama == null) {
      next = const SetupIntroScreen();
    } else {
      next = const TamagotchiScreen();
    }
    if (!mounted) return;
    setState(() => _next = next);
  }

  @override
  Widget build(BuildContext context) {
    return _next ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
