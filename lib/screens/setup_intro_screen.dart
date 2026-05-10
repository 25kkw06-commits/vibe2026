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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('🐣',
                  style: TextStyle(fontSize: 96), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text(
                '다마고치를 키워보세요',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '핸드폰을 적게 쓰면 다마고치가 건강하게 자라요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 22),
                        SizedBox(width: 6),
                        Text('중요한 경고',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      '한 번 정한 추적 앱과 시간 한도는\n게임 도중에 절대 변경할 수 없습니다.\n\n'
                      '다마고치가 죽어야만 새로 설정할 수 있어요.\n신중하게 결정해 주세요.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _RuleSection(
                icon: '🤒',
                title: '병들기',
                desc: '추적 앱이 한도를 넘으면 다마고치가 병들어요.\n3번 병들면 죽습니다.',
              ),
              const SizedBox(height: 12),
              _RuleSection(
                icon: '💊',
                title: '치료제',
                desc: '하루 동안 모든 앱을 한도의 절반 이하로 쓰면\n치료제 1개를 받아요.',
              ),
              const SizedBox(height: 12),
              _RuleSection(
                icon: '🍙',
                title: '돌보기',
                desc: '먹이, 목욕, 놀이로 다마고치를 직접 돌볼 수 있어요.',
              ),
              const Spacer(),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('위 내용을 모두 이해했습니다'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('시작하기'),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  const _RuleSection({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black54, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
