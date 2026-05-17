import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../../services/tamagotchi_service.dart';

/// 돌봄템만 팜. 나머지 슬롯은 비움.
class ShopScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onBought;

  const ShopScreen({
    super.key,
    required this.storage,
    required this.onBought,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _credits = 0;
  (int, int, int) _stock = (0, 0, 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await widget.storage.loadCredits();
    final s = await widget.storage.loadShopCareStocks();
    if (mounted) {
      setState(() {
        _credits = c;
        _stock = s;
        _loading = false;
      });
    }
  }

  Future<void> _buy(Future<bool> Function() fn, String label) async {
    final ok = await fn();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label: 크레딧 부족'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _load();
    widget.onBought();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final cs = Theme.of(context).colorScheme;
    final (sf, ss, st) = _stock;

    Widget row({
      required String name,
      required String detail,
      required int price,
      required int owned,
      required VoidCallback onBuy,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '보유 $owned · $price 크레딧',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onBuy,
              child: Text('$price'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            '크레딧 $_credits',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          row(
            name: TamagotchiService.careItemFeed,
            detail:
                '보유 개수가 있으면 바로 사용. ${StorageService.careRegenIntervalMinutes}분마다 자동 보급(종류당 하루 최대 ${StorageService.careRegenMaxPerTypePerDay}·보유 ${StorageService.careInventorySoftCap}까지).',
            price: StorageService.shopFeedPrice,
            owned: sf,
            onBuy: () => _buy(
              widget.storage.purchaseShopFeed,
              TamagotchiService.careItemFeed,
            ),
          ),
          row(
            name: TamagotchiService.careItemBathe,
            detail: '보유 개수가 있으면 바로 사용. 자동 보급·상한은 사료와 같음.',
            price: StorageService.shopSoapPrice,
            owned: ss,
            onBuy: () => _buy(
              widget.storage.purchaseShopSoap,
              TamagotchiService.careItemBathe,
            ),
          ),
          row(
            name: TamagotchiService.careItemPlay,
            detail: '보유 개수가 있으면 바로 사용. 자동 보급·상한은 사료와 같음.',
            price: StorageService.shopToyPrice,
            owned: st,
            onBuy: () => _buy(
              widget.storage.purchaseShopToy,
              TamagotchiService.careItemPlay,
            ),
          ),
          const Divider(height: 32),
          Text(
            '다른 물건',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아직 없음. 나머지는 준비 중.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
