import 'package:flutter/material.dart';

/// [UsageTrackerApp]이 제공. 자식에서 테마 변경 시
/// `ThemeControllerScope.of(context).setThemeModeRaw('dark')`
/// (`system` | `light` | `dark`)
class ThemeControllerScope extends InheritedWidget {
  const ThemeControllerScope({
    super.key,
    required this.themeModeRaw,
    required this.setThemeModeRaw,
    required super.child,
  });

  final String themeModeRaw;
  final Future<void> Function(String mode) setThemeModeRaw;

  static ThemeControllerScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeControllerScope oldWidget) {
    return oldWidget.themeModeRaw != themeModeRaw;
  }
}
