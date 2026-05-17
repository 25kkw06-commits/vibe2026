import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../../models/app_limit.dart';
import '../../services/storage_service.dart';
import '../../services/usage_service.dart';
import 'app_picker_screen.dart';
import 'limit_edit_screen.dart';
import '../../widgets/theme_mode_menu_button.dart';

/// 추적 앱·한도. 넘긴 적 있으면 그 앱 한도 7일 잠금.
class ManageLimitsScreen extends StatefulWidget {
  const ManageLimitsScreen({super.key});

  @override
  State<ManageLimitsScreen> createState() => _ManageLimitsScreenState();
}

class _ManageLimitsScreenState extends State<ManageLimitsScreen> {
  final _storage = StorageService();
  final _usage = UsageService();
  List<AppLimit> _limits = [];
  Map<String, DateTime> _locks = {};
  bool _loading = true;
  bool _hasPerm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final perm = await _usage.hasPermission();
    final limits = await _storage.loadLimits();
    final locks = await _storage.loadActiveLimitEditLocks();
    if (!mounted) return;
    setState(() {
      _hasPerm = perm;
      _limits = limits;
      _locks = locks;
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (!_hasPerm) {
      await _usage.requestPermission();
      await _load();
      return;
    }
    final picked = await Navigator.push<AppInfo>(
      context,
      MaterialPageRoute(builder: (_) => const AppPickerScreen()),
    );
    if (picked == null || !mounted) return;
    if (_limits.any((e) => e.packageName == picked.packageName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 추가된 앱입니다')),
      );
      return;
    }
    final result = await Navigator.push<AppLimit>(
      context,
      MaterialPageRoute(
        builder: (_) => LimitEditScreen(
          packageName: picked.packageName,
          appName: picked.name,
        ),
      ),
    );
    if (result == null) return;
    await _storage.upsertLimit(result);
    await _load();
  }

  Future<void> _edit(AppLimit l) async {
    final until = await _storage.limitEditLockedUntil(l.packageName);
    if (!mounted) return;
    final result = await Navigator.push<AppLimit>(
      context,
      MaterialPageRoute(
        builder: (_) => LimitEditScreen(
          packageName: l.packageName,
          appName: l.appName,
          initialMinutes: l.limitMinutes,
          limitEditLockedUntil: until,
          initialEnabled: l.enabled,
        ),
      ),
    );
    if (result == null) return;
    await _storage.upsertLimit(result);
    await _load();
  }

  Future<void> _toggle(AppLimit l, bool enabled) async {
    await _storage.upsertLimit(l.copyWith(enabled: enabled));
    await _load();
  }

  Future<void> _remove(AppLimit l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('목록에서 제거'),
        content: Text('${l.appName} 추적을 제거할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _storage.removeLimit(l.packageName);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('추적 앱 · 사용 제한'),
        actions: const [ThemeModeMenuButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_hasPerm)
                  Material(
                    color: cs.errorContainer.withValues(alpha: 0.35),
                    child: ListTile(
                      dense: true,
                      title: const Text('사용 정보 접근 권한이 필요합니다'),
                      subtitle: const Text('설정에서 허용 후 아래를 새로고침 해 주세요.'),
                      trailing: TextButton(
                        onPressed: () async {
                          await _usage.requestPermission();
                          await _load();
                        },
                        child: const Text('설정'),
                      ),
                    ),
                  ),
                Expanded(
                  child: _limits.isEmpty
                      ? Center(
                          child: Text(
                            '추적할 앱이 없습니다.\n아래 버튼으로 추가하세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: _limits.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: cs.outlineVariant),
                          itemBuilder: (ctx, i) {
                            final l = _limits[i];
                            final lock = _locks[l.packageName];
                            final locked = lock != null;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                              title: Text(
                                l.appName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: l.enabled
                                      ? null
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l.limitMinutes}분 / 일 · '
                                    '${l.enabled ? '추적 중' : '일시 정지'}',
                                  ),
                                  if (locked)
                                    Text(
                                      '한도 변경 잠금 ~ ${_fmtDate(lock)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: l.enabled,
                                    onChanged: (v) => _toggle(l, v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: locked
                                        ? '한도 잠금 중 (추적 on/off만 가능)'
                                        : '한도 편집',
                                    onPressed: () => _edit(l),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _remove(l),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('앱 추가'),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
