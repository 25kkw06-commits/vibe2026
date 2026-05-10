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
    // 1분마다 쿨다운 카운트다운/자연 감쇠 반영
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

  Future<void> _doAction(ActionResult Function(Tamagotchi) action) async {
    if (_tama == null) return;
    final result = action(_tama!);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error!),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _storage.saveTamagotchi(result.tama);
    setState(() => _tama = result.tama);
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('새로 시작'),
        content: const Text('현재 다마고치와 모든 설정이 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
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
    if (!t.isAlive) return _buildDeath(t);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusLine(t),
              const SizedBox(height: 16),
              Center(child: TamagotchiAvatar(tama: t)),
              const SizedBox(height: 16),
              Center(child: _moodLabel(t)),
              const SizedBox(height: 24),
              _statsCard(t),
              const SizedBox(height: 12),
              _actionsRow(t),
              const SizedBox(height: 24),
              _usagePanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLine(Tamagotchi t) {
    final divider = Container(
      width: 1,
      height: 10,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
    final base = TextStyle(fontSize: 12, color: Colors.grey.shade600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${t.stageLabel} · ${t.ageDays}일', style: base),
        divider,
        Text(
          t.isSick ? '병중 ${t.sicknessCount}/3' : '건강 ${t.sicknessCount}/3',
          style: base.copyWith(
            color: t.isSick ? Colors.red.shade600 : Colors.grey.shade700,
            fontWeight: t.isSick ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        divider,
        Text('치료제 ${t.medicineCount}', style: base),
      ],
    );
  }

  Widget _moodLabel(Tamagotchi t) {
    String text;
    if (t.isSick) {
      text = '아파해요';
    } else if (t.hunger > 80) {
      text = '배고파해요';
    } else if (t.cleanliness < 25) {
      text = '더러워요';
    } else if (t.happiness < 25) {
      text = '심심해요';
    } else if (t.overallMood > 80) {
      text = '아주 좋아 보여요';
    } else {
      text = '평온해요';
    }
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
    );
  }

  Widget _statsCard(Tamagotchi t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          StatBar(
            icon: Icons.restaurant,
            label: '배고픔',
            value: t.hunger,
            reverseGood: true,
          ),
          StatBar(
            icon: Icons.shower,
            label: '청결',
            value: t.cleanliness,
          ),
          StatBar(
            icon: Icons.mood,
            label: '행복',
            value: t.happiness,
          ),
        ],
      ),
    );
  }

  Widget _actionsRow(Tamagotchi t) {
    final feedCool =
        _svc.cooldownRemaining(t.lastFedAt, TamagotchiService.feedCooldownMin);
    final batheCool = _svc.cooldownRemaining(
        t.lastBathedAt, TamagotchiService.batheCooldownMin);
    final playCool = _svc.cooldownRemaining(
        t.lastPlayedAt, TamagotchiService.playCooldownMin);

    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.restaurant,
            label: '먹이',
            cooldownMin: feedCool,
            onTap: () => _doAction(_svc.feed),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.shower,
            label: '목욕',
            cooldownMin: batheCool,
            onTap: () => _doAction(_svc.bathe),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.sports_esports,
            label: '놀기',
            cooldownMin: playCool,
            onTap: () => _doAction(_svc.play),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.medication_outlined,
            label: '치료',
            badge: t.medicineCount > 0 ? '${t.medicineCount}' : null,
            enabled: t.isSick && t.medicineCount > 0,
            onTap: () => _doAction(_svc.useMedicine),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int cooldownMin = 0,
    bool enabled = true,
    String? badge,
  }) {
    final cooling = cooldownMin > 0;
    final disabled = cooling || !enabled;
    final fg = disabled ? Colors.grey.shade400 : Colors.black87;

    return Stack(
      children: [
        OutlinedButton(
          onPressed: disabled ? null : onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.grey.shade300),
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 6),
              Text(
                cooling ? '${cooldownMin}분' : label,
                style: TextStyle(
                  fontSize: 12,
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _usagePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 사용량',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          if (_limits.isEmpty)
            Text(
              '추적 중인 앱이 없습니다',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            )
          else
            ..._limits.map((l) {
              final used = _usageMap[l.packageName] ?? 0;
              final ratio = (used / l.limitMinutes).clamp(0.0, 1.0);
              final exceeded = used >= l.limitMinutes;
              final near = !exceeded && used >= l.limitMinutes * 0.8;
              final color = exceeded
                  ? Colors.red.shade400
                  : near
                      ? Colors.orange.shade600
                      : Colors.grey.shade700;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.appName,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$used / ${l.limitMinutes}분',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${t.ageDays}일 동안 함께했습니다',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '한도 초과 3회로 사망했습니다.\n새로 설정을 시작할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _restart,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('새로 시작'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
