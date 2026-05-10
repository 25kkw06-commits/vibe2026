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
      duration: const Duration(milliseconds: 1400),
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
    final bg = !t.isAlive
        ? Colors.grey.shade300
        : t.isSick
            ? Colors.red.shade50
            : Colors.indigo.shade50;

    return Container(
      width: widget.size + 40,
      height: widget.size + 40,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final dy = t.isAlive ? -6 * _ctrl.value : 0.0;
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
