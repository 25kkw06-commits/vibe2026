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
    return Container(
      width: widget.size + 40,
      height: widget.size + 40,
      decoration: BoxDecoration(
        color: t.isAlive ? Colors.grey.shade50 : Colors.grey.shade100,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final dy = t.isAlive ? -4 * _ctrl.value : 0.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Text(
                t.displayEmoji,
                style: TextStyle(fontSize: widget.size),
              ),
            );
          },
        ),
      ),
    );
  }
}
