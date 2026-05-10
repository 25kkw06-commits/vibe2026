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
        title: const Text('시작할까요?'),
        content: const Text(
          '게임이 시작되면 추적 앱과 시간을 변경할 수 없습니다.\n'
          '다마고치가 죽어야 다시 설정할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('시작'),
          ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '사용 정보 접근 권한이 필요합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '시스템 설정 > 사용 정보 접근에서 본 앱을 허용해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await _usage.requestPermission();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('설정 열기'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _check,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              foregroundColor: Colors.black87,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('권한 확인'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '다마고치 이름',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            maxLength: 12,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '추적할 앱과 시간',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
        Expanded(
          child: _limits.isEmpty
              ? Center(
                  child: Text(
                    '아래 + 버튼으로 앱을 추가하세요',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _limits.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, i) {
                    final l = _limits[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.appName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${l.limitMinutes}분 / 일',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: Colors.grey.shade700,
                            onPressed: () => _edit(l),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: Colors.grey.shade500,
                            onPressed: () => _remove(l),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('앱 추가'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    foregroundColor: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _limits.isEmpty ? null : _startGame,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('게임 시작'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
