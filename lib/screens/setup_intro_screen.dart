import 'package:flutter/material.dart';
import 'setup_screen.dart';

class SetupIntroScreen extends StatefulWidget {
  const SetupIntroScreen({super.key});

  @override
  State<SetupIntroScreen> createState() => _SetupIntroScreenState();
}

class _SetupIntroScreenState extends State<SetupIntroScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시작하기')),
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
                    '한 번 정한 추적 앱과 시간 한도는 다마고치가 죽을 때까지 변경할 수 없습니다.',
              ),
              const _Rule(
                title: '병들기',
                desc: '추적 앱이 일일 한도를 넘으면 다마고치가 병에 걸립니다. 3회 누적되면 사망합니다.',
              ),
              const _Rule(
                title: '치료제',
                desc: '하루 동안 모든 앱을 한도의 절반 이하로 사용하면 다음 날 치료제 1개를 받습니다.',
              ),
              const _Rule(
                title: '돌보기',
                desc: '먹이·목욕·놀이로 다마고치를 돌볼 수 있습니다. 너무 자주 하면 받지 않습니다.',
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
                onPressed: _agreed
                    ? () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SetupScreen(),
                          ),
                        );
                      }
                    : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('시작'),
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
