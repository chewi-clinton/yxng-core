import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LifeosApp());
    await tester.pump();

    expect(find.text('lifeos'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
