import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/app_limit.dart';
import '../../models/tamagotchi.dart';
import '../../services/daily_score_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../services/tamagotchi_service.dart';
import '../../services/usage_service.dart';
import '../../widgets/stat_bar.dart';
import '../../widgets/tamagotchi_avatar.dart';
import '../../widgets/theme_mode_menu_button.dart';
import '../../core/admin_config.dart';
import '../admin/admin_panel_screen.dart';
import '../limits/manage_limits_screen.dart';
import '../record/ranking_board_page.dart';
import '../shop/shop_screen.dart';

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
  int _avatarInteractTick = 0;
  int _tabIndex = 0;
  int _rankingKey = 0;
  int _shopFeed = 0;
  int _shopSoap = 0;
  int _shopToy = 0;

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
    await _storage.processCareItemRegen();
    var t = await _storage.loadTamagotchi();
    if (t == null) return;
    final before = t;
    t = await DailyScoreService.advanceThroughClosedDaysAndDecayToNow(
      _svc,
      _storage,
      t,
    );
    await NotificationService.notifyCareTransition(before, t);
    final cyclePending = await _storage.loadPendingCycleComplete();
    if (cyclePending != null && t.isAlive && mounted) {
      await _on30DayCycleComplete(cyclePending);
      return;
    }

    final beforeEval = t;
    t = await _svc.evaluateUsage(t);
    await NotificationService.notifyCareTransition(beforeEval, t);
    if (t.isAlive) {
      await _svc.checkNotifyActionButtonsAvailable(_storage, t);
    } else {
      await _storage.saveActionEnabledSnap(false, false, false);
    }
    await _storage.saveTamagotchi(t);

    final limits = await _storage.loadLimits();
    Map<String, int> usage = {};
    if (await _usage.hasPermission()) {
      usage = await _usage.getTodayUsageMinutes();
    }
    final shop = await _storage.loadShopCareStocks();

    if (!mounted) return;
    setState(() {
      _tama = t;
      _limits = limits;
      _usageMap = usage;
      _shopFeed = shop.$1;
      _shopSoap = shop.$2;
      _shopToy = shop.$3;
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
    await _svc.syncActionButtonSnapshot(_storage, result.tama);
    final shop = await _storage.loadShopCareStocks();
    if (!mounted) return;
    setState(() {
      _tama = result.tama;
      _shopFeed = shop.$1;
      _shopSoap = shop.$2;
      _shopToy = shop.$3;
      _avatarInteractTick++;
    });
  }

  Future<void> _doTryFeed() async {
    if (_tama == null) return;
    final result = await _svc.tryFeed(_tama!);
    if (!result.success) {
      if (!mounted) return;
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
    await _svc.syncActionButtonSnapshot(_storage, result.tama);
    final shop = await _storage.loadShopCareStocks();
    if (!mounted) return;
    setState(() {
      _tama = result.tama;
      _shopFeed = shop.$1;
      _shopSoap = shop.$2;
      _shopToy = shop.$3;
      _avatarInteractTick++;
    });
  }

  Future<void> _doTryBathe() async {
    if (_tama == null) return;
    final result = await _svc.tryBathe(_tama!);
    if (!result.success) {
      if (!mounted) return;
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
    await _svc.syncActionButtonSnapshot(_storage, result.tama);
    final shop = await _storage.loadShopCareStocks();
    if (!mounted) return;
    setState(() {
      _tama = result.tama;
      _shopFeed = shop.$1;
      _shopSoap = shop.$2;
      _shopToy = shop.$3;
      _avatarInteractTick++;
    });
  }

  Future<void> _doTryPlay() async {
    if (_tama == null) return;
    final result = await _svc.tryPlay(_tama!);
    if (!result.success) {
      if (!mounted) return;
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
    await _svc.syncActionButtonSnapshot(_storage, result.tama);
    final shop = await _storage.loadShopCareStocks();
    if (!mounted) return;
    setState(() {
      _tama = result.tama;
      _shopFeed = shop.$1;
      _shopSoap = shop.$2;
      _shopToy = shop.$3;
      _avatarInteractTick++;
    });
  }

  Future<void> _on30DayCycleComplete(CycleCompletePending pending) async {
    await _showCycleCompleteDialog(pending);
    await NotificationService.cancelAllNotifications();
    await _storage.resetAll(preserveShopCredits: true);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/setup_intro',
      (route) => false,
    );
  }

  Future<void> _showCycleCompleteDialog(CycleCompletePending pending) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('30일 주기 끝'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '한 달 치 다 채웠어요. 확인 누르면 저장 없애고 처음 셋업부터예요.',
                style: TextStyle(height: 1.4),
              ),
              if (pending.creditsGranted > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '주기 보상 크레딧 ${pending.creditsGranted}은(는) 이미 반영돼 있어요.',
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('새로 시작'),
        content: const Text('현재 타임고치와 모든 설정이 사라집니다.'),
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
    await NotificationService.cancelAllNotifications();
    await _storage.resetAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/setup_intro',
      (route) => false,
    );
  }

  String _appBarTitleForTab(Tamagotchi t) {
    switch (_tabIndex) {
      case 1:
        return '상점';
      case 2:
        return '기록';
      default:
        return t.name;
    }
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
        title: Text(_appBarTitleForTab(t)),
        actions: [
          if (AdminConfig.enabled)
            IconButton(
              icon: const Icon(Icons.build_circle_outlined),
              tooltip: '관리자 도구',
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminPanelScreen(
                      storage: _storage,
                      tamagotchiService: _svc,
                      onChanged: _refresh,
                    ),
                  ),
                );
                if (mounted) _refresh();
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '추적 앱 · 사용 제한',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageLimitsScreen(),
                ),
              );
              if (mounted) _refresh();
            },
          ),
          const ThemeModeMenuButton(),
          if (_tabIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: '새로고침',
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusLine(t),
                  const SizedBox(height: 16),
                  Center(
                    child: TamagotchiAvatar(
                      tama: t,
                      interactTick: _avatarInteractTick,
                    ),
                  ),
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
            ShopScreen(
              storage: _storage,
              onBought: () {
                _refresh();
              },
            ),
            RankingBoardPage(
              key: ValueKey(_rankingKey),
              storage: _storage,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() {
            _tabIndex = i;
            if (i == 2) _rankingKey++;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 20),
            selectedIcon: Icon(Icons.home, size: 20),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined, size: 20),
            selectedIcon: Icon(Icons.storefront, size: 20),
            label: '상점',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, size: 20),
            selectedIcon: Icon(Icons.bar_chart, size: 20),
            label: '기록',
          ),
        ],
      ),
    );
  }

  Widget _statusLine(Tamagotchi t) {
    final cs = Theme.of(context).colorScheme;
    final divider = Container(
      width: 1,
      height: 10,
      color: cs.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ) ??
        TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${t.stageLabel} · ${t.ageDays}일', style: base),
        divider,
        Text(
          t.isSick
              ? '병중 (누적 ${t.sicknessCount}/3)'
              : '누적 병 ${t.sicknessCount}/3 (3이면 사망)',
          style: base.copyWith(
            color: t.isSick ? cs.error : cs.onSurface,
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
      text = '배고픔';
    } else if (t.cleanliness < 25) {
      text = '더러움';
    } else if (t.happiness < 25) {
      text = '저조';
    } else if (t.overallMood > 80) {
      text = '양호';
    } else {
      text = '보통';
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _statsCard(Tamagotchi t) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
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
    final (feedOk, batheOk, playOk) = _svc.careActionsEnabled(
      t,
      shopFeed: _shopFeed,
      shopSoap: _shopSoap,
      shopToy: _shopToy,
    );

    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.restaurant,
            label: TamagotchiService.careItemFeed,
            actionEnabled: feedOk,
            countLine: '$_shopFeed',
            onTap: _doTryFeed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.soap,
            label: TamagotchiService.careItemBathe,
            actionEnabled: batheOk,
            countLine: '$_shopSoap',
            onTap: _doTryBathe,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.toys,
            label: TamagotchiService.careItemPlay,
            actionEnabled: playOk,
            countLine: '$_shopToy',
            onTap: _doTryPlay,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionBtn(
            icon: Icons.medication_outlined,
            label: '치료',
            actionEnabled: t.isSick && t.medicineCount > 0,
            countLine: t.medicineCount > 0 ? '${t.medicineCount}' : null,
            onTap: () => _doAction(_svc.useMedicine),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
    bool actionEnabled = true,
    String? countLine,
  }) {
    final cs = Theme.of(context).colorScheme;
    final disabled = !actionEnabled;
    final fg = disabled ? cs.onSurface.withValues(alpha: 0.38) : cs.onSurface;

    return OutlinedButton(
      onPressed: disabled ? null : () => onTap(),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: cs.outlineVariant),
        foregroundColor: cs.onSurface,
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
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          if (countLine != null) ...[
            const SizedBox(height: 2),
            Text(
              countLine,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _usagePanel() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
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
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (_limits.isEmpty)
            Text(
              '추적 중인 앱이 없습니다',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            )
          else
            ..._limits.map((l) {
              final used = _usageMap[l.packageName] ?? 0;
              final ratio = (used / l.limitMinutes).clamp(0.0, 1.0);
              final exceeded = used >= l.limitMinutes;
              final near = !exceeded && used >= l.limitMinutes * 0.8;
              final color = exceeded
                  ? cs.error
                  : near
                      ? cs.tertiary
                      : cs.onSurfaceVariant;
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
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
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
                        backgroundColor:
                            cs.surfaceContainerHighest.withValues(alpha: 0.5),
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

  String _deathMessage(Tamagotchi t) {
    if (t.diedFromNeglect) {
      return '${t.name}에게 꾸준한 돌봄이 닿지 못한 날이 사흘 이어졌어요. '
          '많이 지쳤을 텐데, 그 시간도 함께한 기록이에요.\n\n'
          '괜찮아요. 언제든 천천히, 다시 시작해 볼 수 있습니다.';
    }
    return '추적 앱의 한도를 넘기며 병이 세 번 쌓였고, '
        '더 이상 함께할 수 없게 되었어요.\n\n'
        '새로 설정을 시작할 수 있습니다.';
  }

  Widget _buildDeath(Tamagotchi t) {
    final cs = Theme.of(context).colorScheme;
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${t.ageDays}일 동안 함께했습니다',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _deathMessage(t),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: cs.onSurface,
                  ),
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
