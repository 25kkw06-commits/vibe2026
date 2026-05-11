import 'package:flutter_test/flutter_test.dart';
import 'package:app_usage_tracker/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const UsageTrackerApp());
  });
}
