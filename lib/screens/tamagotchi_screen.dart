import 'dart:async';
import 'package:flutter/material.dart';

import '../models/app_limit.dart';
import '../models/tamagotchi.dart';
import '../services/storage_service.dart';
import '../services/tamagotchi_service.dart';
import '../services/usage_service.dart';
import '../widgets/stat_bar.dart';
import '../widgets/tamagotchi_avatar.dart';
import 'setup_intro_screen.dart';

class TamagotchiScreen extends StatefulWidget {
  const TamagotchiScreen({super.key});

  @override
  State<TamagotchiScreen> createState() => _TamagotchiScreenState();
}

class _TamagotchiScreenState extends State<TamagotchiScreen>
    with WidgetsBindingObserver {
  final _storage = StorageService();
  final _usage = UsageService();
  late final TamagotchiService _svc =
      TamagotchiService(storage: _storage, usage: _usage);

  Tamagotchi? _tama;
  List<AppLimit> _limits = [];
  Map<String, int> _usageMap = {};
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _bootstrap() async {
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    var t = await _storage.loadTamagotchi();
    if (t == null) return;
    t = _svc.applyDecay(t);
    t = await _svc.evaluateUsage(t);
    await _storage.saveTamagotchi(t);

    final limits = await _storage.loadLimits();
    Map<String, int> usage = {};
    if (await _usage.hasPermission()) {
      usage = await _usage.getTodayUsageMinutes();
    }

    if (!mounted) return;
    setState(() {
      _tama = t;
      _limits = limits;
      _usageMap = usage;
    });
  }

  Future<void> _apply(Tamagotchi Function(Tamagotchi) fn) async {
    if (_tama == null) return;
    final next = fn(_tama!);
    await _storage.saveTamagotchi(next);
    setState(() => _tama = next);
  }

  Future<void> _useMedicine() async {
    if (_tama == null) return;
    if (!_tama!.isSick) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금은 병에 걸리지 않았어요')),
      );
      return;
    }
    if (_tama!.medicineCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('치료제가 없어요. 한도 절반 이하로 사용하면 받을 수 있어요')),
      );
      return;
    }
    await _apply(_svc.useMedicine);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('치료제를 사용했어요 💊')),
    );
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('새로 시작'),
        content: const Text(
          '현재 다마고치와 모든 설정이 사라집니다.\n앱과 시간 한도를 다시 설정해야 합니다.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새로 시작')),
        ],
      ),
    );
    if (ok != true) return;
    await _storage.resetAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SetupIntroScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tama == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = _tama!;

    if (!t.isAlive) {
      return _buildDeath(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${t.name} (${t.stageLabel} · ${t.ageDays}일)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatusBadges(t),
              const SizedBox(height: 16),
              TamagotchiAvatar(tama: t),
              const SizedBox(height: 16),
              _moodLabel(t),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    StatBar(
                        icon: '🍙',
                        label: '배고픔',
                        value: t.hunger,
                        color: Colors.orange,
                        reverseGood: true),
                    StatBar(
                        icon: '🛁',
                        label: '청결',
                        value: t.cleanliness,
                        color: Colors.lightBlue),
                    StatBar(
                        icon: '😊',
                        label: '행복',
                        value: t.happiness,
                        color: Colors.pink),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _actionGrid(t),
              const SizedBox(height: 20),
              _usagePanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadges(Tamagotchi t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _badge(
          icon: t.isSick ? '🤒' : '❤️',
          label: t.isSick ? '병중' : '건강',
          subLabel: '병 ${t.sicknessCount}/3',
          color: t.isSick ? Colors.red : Colors.green,
        ),
        _badge(
          icon: '💊',
          label: '치료제',
          subLabel: '${t.medicineCount}개',
          color: Colors.purple,
        ),
        _badge(
          icon: '🎂',
          label: '나이',
          subLabel: '${t.ageDays}일',
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _badge({
    required String icon,
    required String label,
    required String subLabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          Text(subLabel, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _moodLabel(Tamagotchi t) {
    String text;
    if (t.isSick) {
      text = '${t.name}이(가) 아파해요... 치료제를 사용해 주세요';
    } else if (t.hunger > 80) {
      text = '${t.name}이(가) 배고파해요!';
    } else if (t.cleanliness < 25) {
      text = '${t.name}이(가) 더러워요. 목욕시켜 주세요';
    } else if (t.happiness < 25) {
      text = '${t.name}이(가) 심심해요. 같이 놀아주세요';
    } else if (t.overallMood > 80) {
      text = '${t.name}이(가) 아주 행복해해요 ✨';
    } else {
      text = '${t.name}이(가) 잘 지내고 있어요';
    }
    return Text(text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500));
  }

  Widget _actionGrid(Tamagotchi t) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        _actionTile('🍙', '먹이', () => _apply(_svc.feed)),
        _actionTile('🛁', '목욕', () => _apply(_svc.bathe)),
        _actionTile('🎮', '놀기', () => _apply(_svc.play)),
        _actionTile(
          '💊',
          '치료',
          _useMedicine,
          badge: t.medicineCount > 0 ? '${t.medicineCount}' : null,
          enabled: t.isSick && t.medicineCount > 0,
        ),
      ],
    );
  }

  Widget _actionTile(
    String icon,
    String label,
    VoidCallback onTap, {
    String? badge,
    bool enabled = true,
  }) {
    return Material(
      color: enabled ? Colors.indigo.shade50 : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _usagePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, size: 18),
              SizedBox(width: 6),
              Text('오늘의 사용량',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          if (_limits.isEmpty)
            const Text('추적 중인 앱이 없습니다',
                style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ..._limits.map((l) {
              final used = _usageMap[l.packageName] ?? 0;
              final ratio = (used / l.limitMinutes).clamp(0.0, 1.0);
              final exceeded = used >= l.limitMinutes;
              final halfOrLess = used <= l.limitMinutes / 2;
              final color = exceeded
                  ? Colors.red
                  : halfOrLess
                      ? Colors.green
                      : Colors.orange;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l.appName,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text('$used / ${l.limitMinutes}분',
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDeath(Tamagotchi t) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💀', style: TextStyle(fontSize: 120)),
              const SizedBox(height: 20),
              const Text('다마고치가 하늘나라로 떠났어요',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('${t.name} · ${t.ageDays}일 동안 함께했어요',
                  style:
                      const TextStyle(fontSize: 15, color: Colors.black54)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '한도 초과 3회로 인해 사망했습니다.\n이제 새로운 다마고치와 함께 다시 시작할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('새로 시작하기'),
                  onPressed: _restart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
