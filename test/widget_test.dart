import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:mistake_tracking_app/main.dart';

void main() {
  testWidgets('marks a saved mistake as repeated from the full mistakes list', (
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

    await tester.ensureVisible(find.text('View All Mistakes'));
    await tester.tap(find.text('View All Mistakes'));
    await tester.pumpAndSettle();

    expect(find.text('Mistakes List'), findsOneWidget);
    expect(
      find.text('1. Mistake: Worked on multiple features at once'),
      findsOneWidget,
    );
    expect(
      find.text('Lesson: Always finish one feature before starting another'),
      findsOneWidget,
    );
    expect(find.text('Repeated: 0 times'), findsOneWidget);

    await tester.tap(find.text('Repeated Today'));
    await tester.pumpAndSettle();

    expect(find.text('Repeated: 1 times'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Repeated: 1 times'), findsOneWidget);
  });

  testWidgets('shows the daily review once per day and updates repeat counts', (
    WidgetTester tester,
  ) async {
    final createdAt = DateTime(2026, 3, 29, 8, 0);
    SharedPreferences.setMockInitialValues({
      'saved_mistakes': [
        '{"mistake":"Worked on multiple features","lesson":"Finish one before starting another","createdAt":"${createdAt.toIso8601String()}","repeatCount":0,"lastRepeatedOn":null}',
        '{"mistake":"Used phone while studying","lesson":"Keep the phone outside the room","createdAt":"${createdAt.add(const Duration(minutes: 1)).toIso8601String()}","repeatCount":2,"lastRepeatedOn":null}',
      ],
    });

    await tester.pumpWidget(const MistakeTrackingApp());
    await tester.pumpAndSettle();

    expect(find.text('Daily Review'), findsOneWidget);
    expect(find.textContaining('Worked on multiple features'), findsOneWidget);
    expect(find.textContaining('Used phone while studying'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Yes').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'No').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finish Review'));
    await tester.pumpAndSettle();

    expect(find.text('Add Mistake'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final savedEntries = preferences.getStringList('saved_mistakes');

    expect(savedEntries, isNotNull);

    final decodedEntries = savedEntries!
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    expect(decodedEntries[0]['repeatCount'], 1);
    expect(decodedEntries[1]['repeatCount'], 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MistakeTrackingApp());
    await tester.pumpAndSettle();

    expect(find.text('Daily Review'), findsNothing);
    expect(find.text('Add Mistake'), findsOneWidget);
  });
}
