import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/app_limit.dart';
import '../models/tamagotchi.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import 'app_picker_screen.dart';
import 'limit_edit_screen.dart';
import '../widgets/theme_mode_menu_button.dart';

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
  Species _species = Species.dog;

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
          packageName: picked.packageName,
          appName: picked.name,
        ),
      ),
    );
    if (result == null) return;
    await _storage.upsertLimit(result);
    await _check();
  }

  Future<void> _edit(AppLimit l) async {
    final until = await _storage.limitEditLockedUntil(l.packageName);
    final result = await Navigator.push<AppLimit>(
      context,
      MaterialPageRoute(
        builder: (_) => LimitEditScreen(
          packageName: l.packageName,
          appName: l.appName,
          initialMinutes: l.limitMinutes,
          initialEnabled: l.enabled,
          limitEditLockedUntil: until,
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
          '게임이 시작되면 홈의 「추적 앱 · 사용 제한」에서 '
          '앱을 추가·삭제하고 추적 on/off를 바꿀 수 있습니다.\n\n'
          '다만 어떤 앱이든 일일 한도를 초과한 날이 있으면, '
          '그 앱의 한도(분)는 7일 동안 바꿀 수 없습니다.',
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

    if (!await _storage.wasGrowthTutorialShown()) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _GrowthTutorialDialog(
          petName: name,
          species: _species,
        ),
      );
      await _storage.setGrowthTutorialShown();
    }

    if (!mounted) return;

    final tama = Tamagotchi.newborn(name: name, species: _species);
    await _storage.saveTamagotchi(tama);
    await _storage.setSetupComplete(true);

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/game', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타임고치'),
        actions: const [ThemeModeMenuButton()],
      ),
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('이름'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  maxLength: 12,
                ),
                const SizedBox(height: 4),
                _sectionLabel('종류'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final s in Species.values) ...[
                      Expanded(
                        child: _SpeciesCard(
                          species: s,
                          selected: _species == s,
                          onTap: () => setState(() => _species = s),
                        ),
                      ),
                      if (s != Species.values.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel('추적할 앱과 시간'),
                const SizedBox(height: 8),
                if (_limits.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '아래 + 버튼으로 앱을 추가하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _limits.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                          ListTile(
                            dense: true,
                            title: Text(
                              _limits[i].appName,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              '${_limits[i].limitMinutes}분 / 일',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  color: Colors.grey.shade700,
                                  onPressed: () => _edit(_limits[i]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  color: Colors.grey.shade500,
                                  onPressed: () => _remove(_limits[i]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      );
}

class _GrowthTutorialDialog extends StatelessWidget {
  final String petName;
  final Species species;

  const _GrowthTutorialDialog({
    required this.petName,
    required this.species,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('성장 안내'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '사용시간을 지키면 $petName이(가) 점점 성장해요!',
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  _evoThumb('assets/sprites/${species.name}/0.png'),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.grey.shade500),
                  _evoThumb('assets/sprites/${species.name}/1.png'),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.grey.shade500),
                  _mysteryThumb(),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.grey.shade500),
                  _mysteryThumb(),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    );
  }

  Widget _evoThumb(String asset) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }

  Widget _mysteryThumb() {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        '?',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final Species species;
  final bool selected;
  final VoidCallback onTap;
  const _SpeciesCard({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.black87 : Colors.grey.shade300;
    final bg = selected ? Colors.grey.shade50 : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: borderColor,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/sprites/${species.name}/0.png',
              width: 56,
              height: 56,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(height: 6),
            Text(
              species.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.black87 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
