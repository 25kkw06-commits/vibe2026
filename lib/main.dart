import 'package:flutter/material.dart';

import 'theme_controller_scope.dart';
import 'screens/setup_intro_screen.dart';
import 'screens/setup_screen.dart';
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

class UsageTrackerApp extends StatefulWidget {
  const UsageTrackerApp({super.key});

  @override
  State<UsageTrackerApp> createState() => _UsageTrackerAppState();
}

class _UsageTrackerAppState extends State<UsageTrackerApp> {
  final _storage = StorageService();
  String _themeRaw = 'system';

  @override
  void initState() {
    super.initState();
    _hydrateTheme();
  }

  Future<void> _hydrateTheme() async {
    final s = await _storage.loadThemeModeRaw();
    if (mounted) setState(() => _themeRaw = s);
  }

  Future<void> _applyThemeRaw(String mode) async {
    await _storage.saveThemeModeRaw(mode);
    if (mounted) setState(() => _themeRaw = mode);
  }

  ThemeMode get _flutterThemeMode {
    switch (_themeRaw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static ThemeData _lightTheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData _darkTheme() {
    final cs = ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      themeModeRaw: _themeRaw,
      setThemeModeRaw: _applyThemeRaw,
      child: MaterialApp(
        title: '타임고치',
        debugShowCheckedModeBanner: false,
        themeMode: _flutterThemeMode,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        home: const _RootDispatcher(),
        routes: {
          '/setup_intro': (_) => const SetupIntroScreen(),
          '/setup': (_) => const SetupScreen(),
          '/game': (_) => const TamagotchiScreen(),
        },
      ),
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
