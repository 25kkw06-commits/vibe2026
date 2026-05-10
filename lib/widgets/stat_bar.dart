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
    final v = value.clamp(0, 100);
    final bad = reverseGood ? v >= 70 : v <= 30;
    final color = bad ? Colors.red.shade400 : Colors.grey.shade800;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: v / 100,
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$v',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
