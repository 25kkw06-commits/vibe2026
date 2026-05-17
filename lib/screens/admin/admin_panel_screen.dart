import 'package:flutter/material.dart';

import '../../core/admin_config.dart';
import '../../models/tamagotchi.dart';
import '../../services/daily_score_service.dart';
import '../../services/storage_service.dart';
import '../../services/tamagotchi_service.dart';

/// ADMIN_MODE 한정 디버그 패널.
class AdminPanelScreen extends StatelessWidget {
  final StorageService storage;
  final TamagotchiService tamagotchiService;
  final Future<void> Function() onChanged;

  const AdminPanelScreen({
    super.key,
    required this.storage,
    required this.tamagotchiService,
    required this.onChanged,
  });

  static String _yesterdayStamp() {
    final t = DateTime.now();
    final y =
        DateTime(t.year, t.month, t.day).subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-'
        '${y.month.toString().padLeft(2, '0')}-'
        '${y.day.toString().padLeft(2, '0')}';
  }

  Future<void> _advanceSimulatedDay(BuildContext context) async {
    var t = await storage.loadTamagotchi();
    if (t == null || !context.mounted) return;

    final score = DailyScoreService.scoreFor(t);

    // 일반 플레이의 시간 감쇠와 달리, 관리자 일 진행만 스탯은 건드리지 않음(랭킹 일차·나이만 진행).
    // lastDecayAt 은 24h만 밀어 두어 이후 실제 감쇠가 중복으로 몰리지 않게 맞춤.
    t = t.copyWith(
      lastDecayAt: t.lastDecayAt.add(const Duration(hours: 24)),
    );

    final cycleDone = await storage.appendRankingCycleDayScore(score);

    var streak = t.severeNeglectStreakDays;
    if (TamagotchiService.isSevereNeglectState(t)) {
      streak++;
    } else {
      streak = 0;
    }
    if (streak >= TamagotchiService.severeNeglectDaysToDie) {
      t = t.copyWith(
        isAlive: false,
        happiness: 0,
        severeNeglectStreakDays: 0,
        diedFromNeglect: true,
      );
    } else {
      t = t.copyWith(severeNeglectStreakDays: streak);
    }

    if (t.isAlive) {
      t = await tamagotchiService.evaluateUsage(t);
    }

    t = t.copyWith(bornAt: t.bornAt.subtract(const Duration(days: 1)));

    if (t.isAlive) {
      await tamagotchiService.checkNotifyActionButtonsAvailable(storage, t);
    } else {
      await storage.saveActionEnabledSnap(false, false, false);
    }
    await storage.saveTamagotchi(t);
    await onChanged();

    final n = (await storage.loadRankingCycleScores()).length;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cycleDone
                ? '30일 주기 완주 처리됨. 홈으로 가면 새로 시작 안내가 뜹니다. ($score점 반영)'
                : '$n일차 기록 $score점 · 나이 +1(출생일)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAndRefresh(Tamagotchi t, BuildContext context) async {
    await storage.saveTamagotchi(t);
    await tamagotchiService.syncActionButtonSnapshot(storage, t);
    await onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('반영했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(AdminConfig.enabled);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 도구'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '내부 테스트용. 출시 빌드에는 없음.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          _section(context, '성장(출생일)'),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(bornAt: t.bornAt.subtract(const Duration(days: 1))),
                context,
              );
            },
            child: const Text('출생일 −1일 (나이·스프라이트)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await storage.adminClearRankingCycle();
              await storage.adminResetSimDayIndex();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('30일 일차 기록 비움'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('30일 일차 기록 초기화'),
          ),
          const SizedBox(height: 20),
          _section(context, '시뮬 하루'),
          Text(
            '달력 말고 30일 일차만 한 칸 진행. 지금 스탯으로 점수 기록(배고픔·청결·행복 감소 없음). 출생일 하루 당김(나이). 일반 화면·백그라운드의 시간 감쇠는 그대로.',
            style: TextStyle(
                fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _advanceSimulatedDay(context),
            child: const Text('1일차 진행'),
          ),
          const SizedBox(height: 20),
          _section(context, '크레딧'),
          FilledButton.tonal(
            onPressed: () async {
              await storage.addCredits(100);
              await onChanged();
              if (!context.mounted) return;
              final c = await storage.loadCredits();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('크레딧 $c'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('크레딧 +100'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              await storage.addCredits(500);
              await onChanged();
              if (!context.mounted) return;
              final c = await storage.loadCredits();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('크레딧 $c'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('크레딧 +500'),
          ),
          const SizedBox(height: 20),
          _section(context, '병·치료제'),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(medicineCount: 999),
                context,
              );
            },
            child: const Text('치료제 999'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              final n = t.sicknessCount + 1;
              await _saveAndRefresh(
                t.copyWith(
                  sicknessCount: n.clamp(0, 99),
                  isSick: true,
                  isAlive: n < 3,
                  happiness: 0,
                  diedFromNeglect: false,
                ),
                context,
              );
            },
            child: const Text('병 +1 (한도 초과와 비슷하게)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(
                  isSick: false,
                  limitSickCountToday: 0,
                  exceededTodayPackages: const [],
                ),
                context,
              );
            },
            child: const Text('아픔만 해제 · 오늘 한도집계 리셋'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(
                  sicknessCount: 0,
                  isSick: false,
                  isAlive: true,
                  diedFromNeglect: false,
                  limitSickCountToday: 0,
                  exceededTodayPackages: const [],
                ),
                context,
              );
            },
            child: const Text('병 카운트 0 · 부활 포함'),
          ),
          const SizedBox(height: 20),
          _section(context, '스탯·쿨다운'),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(
                  hunger: 92,
                  cleanliness: 8,
                  happiness: 8,
                ),
                context,
              );
            },
            child: const Text('스탯 최악(배지 확인)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(
                  hunger: 25,
                  cleanliness: 88,
                  happiness: 82,
                ),
                context,
              );
            },
            child: const Text('스탯 쾌적'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final t = await storage.loadTamagotchi();
              if (t == null || !context.mounted) return;
              await _saveAndRefresh(
                t.copyWith(
                  hunger: (t.hunger < TamagotchiService.feedHungerMin)
                      ? TamagotchiService.feedHungerMin
                      : t.hunger,
                  cleanliness: (t.cleanliness > TamagotchiService.batheCleanMax)
                      ? 60
                      : t.cleanliness,
                  happiness: (t.happiness > TamagotchiService.playHappyMax)
                      ? 50
                      : t.happiness,
                ),
                context,
              );
            },
            child: const Text('스탯만 돌봄 버튼 켜지게 맞추기'),
          ),
          const SizedBox(height: 20),
          _section(context, '기록 · 랭킹 보드'),
          Text(
            '누적·일별 행은 기록 탭에서 확인합니다.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              await storage.adminAddCumulativeCareScore(50);
              await onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('누적 점수 +50'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('누적 돌봄 점수 +50'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              final y = _yesterdayStamp();
              await storage.mergeDailyMinScore(y, 40);
              await onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('어제($y) 일일점수 40 주입'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('어제 일일 점수 40 주입'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () async {
              await storage.mergeDailyMinScore(Tamagotchi.todayStamp(), 25);
              await onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('오늘 일일 점수 25 주입'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('오늘 일일 점수 25 주입'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await storage.adminRemoveDailyScore(Tamagotchi.todayStamp());
              await onChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('오늘 일일 점수 행 삭제'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('오늘 일일 점수 행 삭제'),
          ),
          const SizedBox(height: 20),
          _section(context, '메모'),
          Text(
            '• 「1일차 진행」은 실제 자정과 별개로 일차 슬롯만 밀어요.\n'
            '• 방치: 배고픔≥${TamagotchiService.severeNeglectMinHunger}, 청결≤${TamagotchiService.severeNeglectMaxCleanliness}가 ${TamagotchiService.severeNeglectDaysToDie}일 연속 마감.\n'
            '• 30칸 찬 뒤 리셋 때 크레딧은 합산 점수 비율.\n'
            '• 한도 병은 Usage가 있어야 함. `com.time_gochi.admin` 저장은 일반앱과 분리.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
