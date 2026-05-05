import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Upkeep app renders login shell', (WidgetTester tester) async {
    await tester.pumpWidget(const UpkeepApp());
    await tester.pumpAndSettle();

    expect(find.text('Upkeep'), findsWidgets);
    expect(find.text('Welcome back!'), findsOneWidget);
  });
}
