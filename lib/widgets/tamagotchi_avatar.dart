import 'package:flutter/material.dart';
import '../models/tamagotchi.dart';

class TamagotchiAvatar extends StatefulWidget {
  final Tamagotchi tama;
  final double size;
  const TamagotchiAvatar({super.key, required this.tama, this.size = 140});

  @override
  State<TamagotchiAvatar> createState() => _TamagotchiAvatarState();
}

class _TamagotchiAvatarState extends State<TamagotchiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
      sprite = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.5, 0,
        ]),
        child: sprite,
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
              animation: _ctrl,
              builder: (_, child) {
                final dy = dead ? 0.0 : -4 * _ctrl.value;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              child: sprite,
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
