import 'package:flutter/material.dart';

class StatBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value; // 0~100
  final bool reverseGood; // true이면 낮을수록 좋음 (예: 배고픔)

  const StatBar({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.reverseGood = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value.clamp(0, 100);
    final bad = reverseGood ? v >= 70 : v <= 30;
    final barColor = bad ? cs.error : cs.primary;
    final labelColor = cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: labelColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurface),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: v / 100,
                minHeight: 5,
                backgroundColor: cs.surfaceVariant.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$v',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: labelColor),
            ),
          ),
        ],
      ),
    );
  }
}
