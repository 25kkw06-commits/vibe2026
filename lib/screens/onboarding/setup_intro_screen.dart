import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/theme_mode_menu_button.dart';

class SetupIntroScreen extends StatefulWidget {
  const SetupIntroScreen({super.key});

  @override
  State<SetupIntroScreen> createState() => _SetupIntroScreenState();
}

class _SetupIntroScreenState extends State<SetupIntroScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _agreed = false;
  bool _busy = false;

  static const int _pageCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showRulesDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게임 규칙'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Rule(
                title: '추적 앱 · 한도',
                desc: '게임 중에도 홈의 「추적 앱 · 사용 제한」에서 앱을 바꿀 수 있습니다. '
                    '단, 어떤 앱이든 그날 일일 한도를 초과한 적이 있으면 그 앱의 한도(분)는 7일 동안 고정됩니다. '
                    '추적 on/off는 그대로 바꿀 수 있어요.',
              ),
              _Rule(
                title: '병들기',
                desc: '설정한 앱마다 그날 한도를 넘기면 병이 하나씩 쌓입니다. 앱을 여러 개 두면 각각 따로 봅니다. '
                    '하루에 이렇게 오르는 병은 최대 2번입니다. 병 3번 누적이면 죽습니다.',
              ),
              _Rule(
                title: '치료제',
                desc:
                    '어제 하루 동안 설정한 모든 앱이 각 한도를 넘지 않았으면, 날이 바뀌는 처리 때 기록과 함께 치료제 1개를 받습니다.',
              ),
              _Rule(
                title: '돌보기 · 방치',
                desc: '돌봄은 사료·비누·장난감 개수로 해요. 스탯이 맞을 때만 쓸 수 있어요. '
                    '시간이 지나면(앱이 꺼져 있어도) 개수가 조금씩 다시 늘어나요(종류마다 하루 상한 있음). '
                    '시간이 지나면 배고픔은 늘고 청결은 떨어집니다. 배고픔이 크고(매우 배고픔) 더러우면 행복도가 크게 떨어지고, '
                    '배부르고 깨끗하면 행복이 잘 유지돼요. '
                    '배고픔·청결이 너무 나쁜 상태가 3일 연속(날짜가 바뀔 때마다 셈)이면 타임고치가 죽을 수 있어요. '
                    '(앱 한도 병이 세 번 쌓여 죽는 경우와는 달라요.)',
              ),
              _Rule(
                title: '기록 · 나의 점수 (30일 주기)',
                desc: '「기록」에 나의 점수가 보여요. 자정이 지난 뒤 첫 평가마다 그날 마감 점수가 '
                    '1일차→30일차 순으로 하나씩 쌓이고, 그 합이 나의 점수예요. 앱을 안 켠 날도 그날까지 스탯이 진행된 뒤의 행복도로 마감돼요(대개 낮아져요). '
                    '「내 정보」에서 일차별 로그를 볼 수 있어요. '
                    '30일 주기가 끝나면 축하 안내 후 처음처럼 다시 시작해요. 타임 크레딧 보상은 새로 이어질 수 있어요. '
                    '그때 막 끝난 주기 점수 합에 따라 타임 크레딧이 들어와요.',
              ),
              _Rule(
                title: '상점 · 크레딧',
                desc: '상점에서 사료·비누·장난감을 크레딧으로 살 수 있어요(보유 개수에 더해짐). '
                    '나머지 카테고리는 아직 비어 있어요. '
                    '타임 크레딧은 30일 기록 주기를 한 번 채울 때마다 점수 합에 비례해 들어와요.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _onStart() async {
    if (!_agreed || _busy) return;
    setState(() => _busy = true);
    try {
      final storage = StorageService();
      if (!await storage.wasNotificationRationaleShown() && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('알림 안내'),
            content: const Text(
              '돌봄·한도 알림을 받으려면 알림을 허용해 주세요.\n\n'
              '이어서 뜨는 시스템 창에서 허용을 눌러 주세요.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        await storage.setNotificationRationaleShown();
      }
      if (!mounted) return;
      await NotificationService.init();
      await Permission.notification.request();
      await NotificationService.requestAndroidPostNotificationPermission();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/setup');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goNext() {
    if (_pageIndex < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goPrev() {
    if (_pageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _pageIndex == _pageCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('타임고치'),
        actions: const [ThemeModeMenuButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '시작하기',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '짧게 살펴본 뒤 셋업으로 넘어가요.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (i) {
                  final on = i == _pageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: on ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: on ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  children: [
                    _TutorialPage(
                      icon: Icons.pets_rounded,
                      iconColor: cs.primary,
                      title: '타임고치',
                      body: '지정한 앱 사용 시간을 지키면 타임고치 성장이 진행됩니다. '
                          '이름·종류를 고른 뒤, 추적할 앱과 하루 한도를 정합니다.',
                    ),
                    _TutorialPage(
                      icon: Icons.analytics_outlined,
                      iconColor: cs.tertiary,
                      title: '사용 시간 추적',
                      body: '오늘 각 앱 사용 시간을 시스템 사용 기록으로 읽어 한도와 비교합니다. '
                          '「사용 정보 접근」 권한이 필요합니다. 셋업에서 요청합니다.',
                    ),
                    _TutorialPage(
                      icon: Icons.favorite_outline,
                      iconColor: cs.error,
                      title: '건강과 돌보기',
                      body: '한도를 넘기면 병이 누적돼요. 홈 상단의 「누적 병 n/3」은 지금까지 아팠던 횟수예요. '
                          '3이 되면 타임고치가 떠나요. 병에 걸리는 순간 기분은 바닥이지만, 사료·비누·장난감으로 돌보면 '
                          '행복이 서서히 돌아와요. 배고픔이 낮고(포만에 가깝고) 청결이 높을수록 행복이 잘 유지되고, '
                          '배고프거나 더러우면 행복도가 크게 떨어져요. '
                          '배고픔·청결이 너무 나쁜 상태가 3일 연속이면, 병과는 별개로 지쳐서 떠날 수 있어요.',
                    ),
                    _TutorialPage(
                      icon: Icons.bar_chart_rounded,
                      iconColor: cs.primary,
                      title: '기록 탭 · 나의 점수',
                      body: '「기록」에서 나의 점수(1~30일차 합)를 봐요. 자정 넘긴 뒤 첫 평가마다 하루치가 '
                          '1일차부터 한 칸씩 쌓여요. 앱을 안 열어도 그날까지 스탯이 진행된 뒤의 행복도로 마감돼요. '
                          '「내 정보」로 일별 로그를 볼 수 있어요. '
                          '30일이 끝나면 안내를 보고 셋업부터 다시 시작해요. 그때까지의 크레딧 보상은 이어져요.',
                    ),
                    _TutorialPage(
                      icon: Icons.storefront_outlined,
                      iconColor: cs.tertiary,
                      title: '상점 · 크레딧',
                      body: '상점에서 돌봄템을 살 수 있어요. '
                          '크레딧은 30일 기록 주기를 한 번 채울 때마다 점수 합에 비례해 쌓여요.',
                      extra: TextButton(
                        onPressed: _showRulesDialog,
                        child: const Text('게임 규칙 자세히 보기'),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) ...[
                Row(
                  children: [
                    if (_pageIndex > 0)
                      TextButton(
                        onPressed: _busy ? null : _goPrev,
                        child: const Text('이전'),
                      )
                    else
                      const SizedBox(width: 64),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _goNext,
                        child: const Text('다음'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                CheckboxListTile(
                  value: _agreed,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _agreed = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    '안내를 확인했어요',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: (_agreed && !_busy) ? _onStart : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_busy ? '준비 중…' : '셋업으로'),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _goPrev,
                  child: const Text('이전 단계'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? extra;

  const _TutorialPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Icon(icon, size: 56, color: iconColor),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 8),
                  Center(child: extra),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  final String title;
  final String desc;
  const _Rule({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              color: muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
