import 'package:flutter/material.dart';
import '../models/app_limit.dart';

class LimitEditScreen extends StatefulWidget {
  final String packageName;
  final String appName;
  final int initialMinutes;

  const LimitEditScreen({
    super.key,
    required this.packageName,
    required this.appName,
    this.initialMinutes = 60,
  });

  @override
  State<LimitEditScreen> createState() => _LimitEditScreenState();
}

class _LimitEditScreenState extends State<LimitEditScreen> {
  late int _minutes;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _ctrl = TextEditingController(text: _minutes.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setMinutes(int m) {
    if (m < 1) m = 1;
    if (m > 1440) m = 1440;
    setState(() {
      _minutes = m;
      _ctrl.text = m.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _minutes ~/ 60;
    final mins = _minutes % 60;
    final pretty =
        hours > 0 ? '$hours시간 ${mins > 0 ? '$mins분' : ''}' : '$mins분';

    return Scaffold(
      appBar: AppBar(title: Text('${widget.appName} 사용 제한')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('하루 최대 사용 시간',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Center(
              child: Text(pretty,
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            Slider(
              min: 5,
              max: 480,
              divisions: 95,
              value: _minutes.clamp(5, 480).toDouble(),
              label: '$_minutes분',
              onChanged: (v) => _setMinutes(v.round()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '직접 입력 (분)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) => _setMinutes(int.tryParse(v) ?? _minutes),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _setMinutes(int.tryParse(_ctrl.text) ?? _minutes),
                  child: const Text('적용'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final p in [15, 30, 60, 90, 120, 180])
                  ActionChip(
                    label: Text('$p분'),
                    onPressed: () => _setMinutes(p),
                  ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('저장'),
              onPressed: () {
                Navigator.pop(
                  context,
                  AppLimit(
                    packageName: widget.packageName,
                    appName: widget.appName,
                    limitMinutes: _minutes,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
