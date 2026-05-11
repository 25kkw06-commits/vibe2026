import 'package:flutter/material.dart';

import '../models/tamagotchi.dart';
import '../services/storage_service.dart';

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
  int _total = 0;
  List<(String date, int score)> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.storage.finalizePastDaysIntoCumulative();
    final total = await widget.storage.loadCumulativeCareScore();
    final m = await widget.storage.loadDailyScores();
    final list = m.entries.map((e) => (e.key, e.value)).toList();
    list.sort((a, b) => b.$1.compareTo(a.$1));
    if (mounted) {
      setState(() {
        _total = total;
        _rows = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final today = Tamagotchi.todayStamp();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '누적 $_total',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '전날까지의 일일 점수를 더한 값. 오늘은 아래에만 보이고, 날이 바뀌면 누적에 들어감.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '같은 날 여러 번이면 그중 가장 낮은 점수만 씀. 아파 있으면 그때 측정은 0.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '일별 기록 없음',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            )
          else
            ..._rows.map((row) {
              final (date, score) = row;
              final isToday = date == today;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isToday ? '$date (오늘)' : date,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
}
