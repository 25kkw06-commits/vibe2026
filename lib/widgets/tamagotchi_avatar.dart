import 'package:flutter/material.dart';
import '../models/tamagotchi.dart';

class TamagotchiAvatar extends StatefulWidget {
  final Tamagotchi tama;
  final double size;
  /// 부모가 상호작용 성공 시마다 증가시키면 짧은 좌우 흔들림이 재생됩니다.
  final int interactTick;
  const TamagotchiAvatar({
    super.key,
    required this.tama,
    this.size = 140,
    this.interactTick = 0,
  });

  @override
  State<TamagotchiAvatar> createState() => _TamagotchiAvatarState();
}

class _TamagotchiAvatarState extends State<TamagotchiAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _bobCtrl;
  late final AnimationController _wiggleCtrl;
  late final AnimationController _tapBounceCtrl;
  late final Animation<double> _wiggleX;
  late final Animation<double> _tapBounceY;

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.tama.isAlive) {
      _bobCtrl.repeat(reverse: true);
    }

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _wiggleX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 7), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 7, end: -6), weight: 22),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 20),
    ]).animate(CurvedAnimation(parent: _wiggleCtrl, curve: Curves.linear));

    _tapBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _tapBounceY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -13), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -13, end: 4), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 32),
    ]).animate(CurvedAnimation(parent: _tapBounceCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(TamagotchiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tama.isAlive != oldWidget.tama.isAlive) {
      if (widget.tama.isAlive) {
        _bobCtrl.repeat(reverse: true);
      } else {
        _bobCtrl.stop();
        _bobCtrl.reset();
        _wiggleCtrl.stop();
        _wiggleCtrl.reset();
        _tapBounceCtrl.stop();
        _tapBounceCtrl.reset();
      }
    }
    if (widget.tama.isAlive &&
        widget.interactTick != oldWidget.interactTick) {
      _wiggleCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _wiggleCtrl.dispose();
    _tapBounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tama;
    final dead = !t.isAlive;
    final box = widget.size + 40;

    Widget sprite = Image.asset(
      t.spriteAsset,
      width: widget.size,
      height: widget.size,
      filterQuality: FilterQuality.none, // 픽셀 아트라 보간 끔
    );

    if (dead) {
      sprite = Opacity(
        opacity: 0.68,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.38, 0,
          ]),
          child: sprite,
        ),
      );
    }

    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: dead ? Colors.grey.shade100 : Colors.grey.shade50,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_bobCtrl, _wiggleCtrl, _tapBounceCtrl]),
              builder: (_, child) {
                final idleDy = dead ? 0.0 : -4 * _bobCtrl.value;
                final dx = dead ? 0.0 : _wiggleX.value;
                final tapDy = dead ? 0.0 : _tapBounceY.value;
                return Transform.translate(
                  offset: Offset(dx, idleDy + tapDy),
                  child: child,
                );
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dead
                    ? null
                    : () => _tapBounceCtrl.forward(from: 0),
                child: sprite,
              ),
            ),
          ),
          if (t.statusBadge != null)
            Positioned(
              top: 6,
              right: 6,
              child: _StatusBadge(kind: t.statusBadge!),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String kind;
  const _StatusBadge({required this.kind});

  (IconData, Color) _spec() {
    switch (kind) {
      case 'sick':
        return (Icons.healing, Colors.red.shade400);
      case 'hungry':
        return (Icons.restaurant, Colors.orange.shade600);
      case 'dirty':
        return (Icons.shower, Colors.brown.shade400);
      case 'sad':
        return (Icons.sentiment_dissatisfied, Colors.blueGrey.shade400);
    }
    return (Icons.info_outline, Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _spec();
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
