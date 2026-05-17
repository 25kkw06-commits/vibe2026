import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

/// 자정마다 1~30일차에 점수 하나씩. 합이 내 점수.
/// 30일 채우면 다음 마감에 주기 끝 → 팝업 후 셋업부터 다시(크레딧만 남을 수 있음).
class RankingBoardPage extends StatefulWidget {
  final StorageService storage;

  const RankingBoardPage({
    super.key,
    required this.storage,
  });

  @override
  State<RankingBoardPage> createState() => _RankingBoardPageState();
}

class _RankingBoardPageState extends State<RankingBoardPage> {
  String _petName = '';
  List<int> _cycleScores = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tama = await widget.storage.loadTamagotchi();
    final cycle = await widget.storage.loadRankingCycleScores();
    if (mounted) {
      setState(() {
        _petName = tama?.name ?? '';
        _cycleScores = cycle;
        _loading = false;
      });
    }
  }

  int get _myScore => _cycleScores.fold<int>(0, (sum, e) => sum + e);

  Future<void> _showMyLogDialog() async {
    final name = _petName.isEmpty ? '타임고치' : _petName;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name · 1~30일차 로그'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 30,
            itemBuilder: (_, i) {
              final day = i + 1;
              final has = i < _cycleScores.length;
              final score = has ? _cycleScores[i] : null;
              return ListTile(
                dense: true,
                title: Text('$day일차'),
                trailing: Text(
                  has ? '$score' : '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: has
                        ? Theme.of(ctx).colorScheme.onSurface
                        : Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final cs = Theme.of(context).colorScheme;
    final n = _cycleScores.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '나의 점수 $_myScore',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${n.clamp(0, 30)}/30일차 · 자정(날짜가 바뀐 뒤 첫 평가)마다 하루치가 쌓여요',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '30일을 다 채우면, 그다음 마감 때 주기가 끝나요. '
            '축하 메시지를 본 뒤 셋업처럼 처음부터 다시 시작해요. '
            '(이번 주기에 받은 타임 크레딧은 새로 이어질 수 있어요.)',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: _showMyLogDialog,
            child: const Text('내 정보 · 1~30일차 보기'),
          ),
          const SizedBox(height: 24),
          Text(
            '안내',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• 각 일차 = 그날 마감 시점 행복도(0~100). 앱을 안 켠 날도 하루씩 감쇠된 뒤 같은 방식으로 찍힘(대체로 낮음).\n'
            '• 위 합이 기록 탭의 「나의 점수」.\n'
            '• 30일 마지막 마감이 되면 주기 보상 크레딧(상한 있음)과 함께 앱이 처음 상태로 돌아가요(크레딧만 유지).',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
