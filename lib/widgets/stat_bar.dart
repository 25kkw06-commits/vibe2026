import 'package:flutter/material.dart';

class StatBar extends StatelessWidget {
  final String icon;
  final String label;
  final int value; // 0~100
  final Color color;
  final bool reverseGood; // true이면 낮을수록 좋음 (예: 배고픔)

  const StatBar({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.reverseGood = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    final bad = reverseGood ? v >= 70 : v <= 30;
    final barColor = bad ? Colors.red : color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v / 100,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text('$v',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
