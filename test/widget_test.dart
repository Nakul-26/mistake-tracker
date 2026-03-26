import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mistake_tracking_app/main.dart';

void main() {
  testWidgets('saves a mistake and shows it in recent saves', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MistakeTrackingApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Worked on multiple features at once',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Always finish one feature before starting another',
    );

    await tester.tap(find.text('Save Mistake'));
    await tester.pumpAndSettle();

    expect(find.text('Mistake saved.'), findsOneWidget);
    expect(find.text('Worked on multiple features at once'), findsOneWidget);
    expect(
      find.text('Always finish one feature before starting another'),
      findsOneWidget,
    );
  });
}
