import 'package:flutter/material.dart';

import '../theme_controller_scope.dart';

class ThemeModeMenuButton extends StatelessWidget {
  const ThemeModeMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ThemeControllerScope.of(context);
    final raw = scope.themeModeRaw;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.nightlight_round),
      tooltip: '화면 테마',
      onSelected: scope.setThemeModeRaw,
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem(
          value: 'system',
          checked: raw == 'system',
          child: const Text('시스템'),
        ),
        CheckedPopupMenuItem(
          value: 'light',
          checked: raw == 'light',
          child: const Text('라이트'),
        ),
        CheckedPopupMenuItem(
          value: 'dark',
          checked: raw == 'dark',
          child: const Text('다크'),
        ),
      ],
    );
  }
}
