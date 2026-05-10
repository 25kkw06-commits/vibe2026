import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/app_limit.dart';
import '../models/tamagotchi.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import 'app_picker_screen.dart';
import 'limit_edit_screen.dart';
import 'tamagotchi_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _usage = UsageService();
  final _storage = StorageService();
  final _nameCtrl = TextEditingController(text: '미미');

  bool _hasPermission = false;
  bool _loading = true;
  List<AppLimit> _limits = [];

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final perm = await _usage.hasPermission();
    final limits = await _storage.loadLimits();
    if (!mounted) return;
    setState(() {
      _hasPermission = perm;
      _limits = limits;
      _loading = false;
    });
  }

  Future<void> _add() async {
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
          packageName: picked.packageName ?? '',
          appName: picked.name ?? picked.packageName ?? '',
        ),
      ),
    );
    if (result == null) return;
    await _storage.upsertLimit(result);
    await _check();
  }

  Future<void> _edit(AppLimit l) async {
    final result = await Navigator.push<AppLimit>(
      context,
      MaterialPageRoute(
        builder: (_) => LimitEditScreen(
          packageName: l.packageName,
          appName: l.appName,
          initialMinutes: l.limitMinutes,
        ),
      ),
    );
    if (result == null) return;
    await _storage.upsertLimit(result);
    await _check();
  }

  Future<void> _remove(AppLimit l) async {
    await _storage.removeLimit(l.packageName);
    await _check();
  }

  Future<void> _startGame() async {
    if (_limits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개의 앱을 추가해야 합니다')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('정말 시작할까요?'),
        content: const Text(
          '게임이 시작되면 추적 앱과 시간을 변경할 수 없습니다.\n'
          '다마고치가 죽어야만 다시 설정할 수 있어요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('시작')),
        ],
      ),
    );
    if (ok != true) return;

    final name = _nameCtrl.text.trim().isEmpty ? '미미' : _nameCtrl.text.trim();
    final tama = Tamagotchi.newborn(name: name);
    await _storage.saveTamagotchi(tama);
    await _storage.setSetupComplete(true);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TamagotchiScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('초기 설정')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _permissionPrompt()
              : _setupBody(),
    );
  }

  Widget _permissionPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('사용 정보 접근 권한이 필요합니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            '안드로이드 시스템 설정 > 사용 정보 접근에서\n이 앱을 허용해 주세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await _usage.requestPermission();
            },
            icon: const Icon(Icons.settings),
            label: const Text('설정 열기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.refresh),
            label: const Text('권한 확인'),
          ),
        ],
      ),
    );
  }

  Widget _setupBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '다마고치 이름',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pets),
            ),
            maxLength: 12,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('추적할 앱과 시간',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: _limits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_chart,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('+ 버튼으로 앱을 추가하세요',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _limits.length,
                  itemBuilder: (_, i) {
                    final l = _limits[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(l.appName),
                        subtitle: Text('${l.limitMinutes}분 / 일'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _edit(l),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              onPressed: () => _remove(l),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('앱 추가'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _limits.isEmpty ? null : _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('게임 시작'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
