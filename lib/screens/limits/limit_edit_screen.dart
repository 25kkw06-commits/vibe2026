import 'package:flutter/material.dart';

import '../../models/app_limit.dart';

class LimitEditScreen extends StatefulWidget {
  final String packageName;
  final String appName;
  final int initialMinutes;

  /// 저장 시 함께 반영할 추적 on/off (목록 스위치와 동기화).
  final bool initialEnabled;

  /// 비-null이고 아직 지나지 않았으면 `limitMinutes`만 수정 불가.
  final DateTime? limitEditLockedUntil;

  const LimitEditScreen({
    super.key,
    required this.packageName,
    required this.appName,
    this.initialMinutes = 60,
    this.initialEnabled = true,
    this.limitEditLockedUntil,
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

  bool get _locked {
    final u = widget.limitEditLockedUntil;
    return u != null && u.isAfter(DateTime.now());
  }

  void _setMinutes(int m) {
    if (_locked) return;
    if (m < 1) m = 1;
    if (m > 1440) m = 1440;
    setState(() {
      _minutes = m;
      _ctrl.text = m.toString();
    });
  }

  static String _fmtLock(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hours = _minutes ~/ 60;
    final mins = _minutes % 60;
    final pretty =
        hours > 0 ? '$hours시간 ${mins > 0 ? '$mins분' : ''}' : '$mins분';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.appName} 사용 제한')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_locked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '이 앱은 한도를 초과한 이력이 있어 '
                        '${_fmtLock(widget.limitEditLockedUntil!)} '
                        '까지 일일 한도(분)를 바꿀 수 없습니다.\n'
                        '목록에서 추적 on/off는 그대로 바꿀 수 있어요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              const Text(
                '하루 최대 사용 시간',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  pretty,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _locked ? cs.onSurfaceVariant : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AbsorbPointer(
                absorbing: _locked,
                child: Opacity(
                  opacity: _locked ? 0.45 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              onSubmitted: (v) =>
                                  _setMinutes(int.tryParse(v) ?? _minutes),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _locked
                                ? null
                                : () => _setMinutes(
                                      int.tryParse(_ctrl.text) ?? _minutes,
                                    ),
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
                              onPressed: _locked ? null : () => _setMinutes(p),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('저장'),
                onPressed: () {
                  final m = _locked ? widget.initialMinutes : _minutes;
                  Navigator.pop(
                    context,
                    AppLimit(
                      packageName: widget.packageName,
                      appName: widget.appName,
                      limitMinutes: m,
                      enabled: widget.initialEnabled,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
