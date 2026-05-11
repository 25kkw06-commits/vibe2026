import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'setup_screen.dart';

class SetupIntroScreen extends StatefulWidget {
  const SetupIntroScreen({super.key});

  @override
  State<SetupIntroScreen> createState() => _SetupIntroScreenState();
}

class _SetupIntroScreenState extends State<SetupIntroScreen> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _onStart() async {
    if (!_agreed || _busy) return;
    setState(() => _busy = true);
    try {
      final storage = StorageService();
      if (!await storage.wasNotificationRationaleShown() && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('알림 안내'),
            content: const Text(
              '배고픔·청결·행복, 먹이·목욕·놀이를 할 수 있게 되었을 때, '
              '그리고 앱 사용 시간 제한 등의 알림을 받으려면 알림을 허용해 주세요.\n\n'
              '다음에 시스템 권한 창이 뜨면 허용을 눌러 주세요.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        await storage.setNotificationRationaleShown();
      }
      if (!mounted) return;
      await NotificationService.init();
      await Permission.notification.request();
      await NotificationService.requestAndroidPostNotificationPermission();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('타임고치')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '규칙',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '시작 전에 한 번만 읽어 주세요.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              const _Rule(
                title: '잠금',
                desc:
                    '한 번 정한 추적 앱과 시간 한도는 타임고치가 죽을 때까지 변경할 수 없습니다.',
              ),
              const _Rule(
                title: '병들기',
                desc:
                    '설정한 앱마다 그날 한도를 넘기면 병이 하나씩 쌓입니다. 앱을 여러 개 두면 각각 따로 봅니다. 하루에 이렇게 오르는 병은 최대 2번입니다. 병 3번 누적이면 죽습니다.',
              ),
              const _Rule(
                title: '치료제',
                desc:
                    '어제 하루 동안 설정한 모든 앱이 각 한도를 넘지 않았으면, 날이 바뀌는 처리 때 기록과 함께 치료제 1개를 받습니다.',
              ),
              const _Rule(
                title: '돌보기',
                desc: '먹이·목욕·놀이로 타임고치를 돌볼 수 있습니다. 너무 자주 하면 받지 않습니다.',
              ),
              const Spacer(),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: const Text(
                  '규칙을 이해했습니다',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (_agreed && !_busy) ? _onStart : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_busy ? '준비 중…' : '시작'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final String title;
  final String desc;
  const _Rule({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
