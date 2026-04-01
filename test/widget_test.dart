import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:mistake_tracking_app/main.dart';

void main() {
  testWidgets('shows saved lessons as rules on the start session screen', (
    WidgetTester tester,
  ) async {
    final createdAt = DateTime(2026, 3, 29, 8, 0);
    SharedPreferences.setMockInitialValues({
      'saved_mistakes': [
        '{"mistake":"Worked on multiple features at once","lesson":"Work on ONE feature at a time","trigger":"When starting a coding session","createdAt":"${createdAt.toIso8601String()}","repeatCount":0,"lastRepeatedOn":null}',
        '{"mistake":"Used phone while studying","lesson":"Keep phone away","trigger":"When sitting down to study","createdAt":"${createdAt.add(const Duration(minutes: 1)).toIso8601String()}","repeatCount":0,"lastRepeatedOn":null}',
      ],
      'last_daily_review_date': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(const MistakeTrackingApp());
    await tester.pumpAndSettle();

    expect(find.text('Start Session'), findsOneWidget);

    await tester.tap(find.text('Start Session'));
    await tester.pumpAndSettle();

    expect(find.text('Before you start:'), findsOneWidget);
    expect(find.text('Work on ONE feature at a time'), findsOneWidget);
    expect(find.text('Keep phone away'), findsOneWidget);
    expect(
      find.text('Watch for: Worked on multiple features at once'),
      findsOneWidget,
    );
    expect(find.text('Watch for: Used phone while studying'), findsOneWidget);
    expect(
      find.text('Trigger: When starting a coding session'),
      findsOneWidget,
    );
    expect(find.text('Trigger: When sitting down to study'), findsOneWidget);
  });

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
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'When starting a coding session',
    );

    await tester.ensureVisible(find.text('Save Mistake'));
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
    expect(
      find.text('Trigger: When starting a coding session'),
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
        '{"mistake":"Worked on multiple features","lesson":"Finish one before starting another","trigger":"When beginning a new task block","createdAt":"${createdAt.toIso8601String()}","repeatCount":0,"lastRepeatedOn":null}',
        '{"mistake":"Used phone while studying","lesson":"Keep the phone outside the room","trigger":"When the study session feels boring","createdAt":"${createdAt.add(const Duration(minutes: 1)).toIso8601String()}","repeatCount":2,"lastRepeatedOn":null}',
      ],
    });

    await tester.pumpWidget(const MistakeTrackingApp());
    await tester.pumpAndSettle();

    expect(find.text('Daily Review'), findsOneWidget);
    expect(find.textContaining('Worked on multiple features'), findsOneWidget);
    expect(find.textContaining('Used phone while studying'), findsOneWidget);
    expect(
      find.text('Trigger: When beginning a new task block'),
      findsOneWidget,
    );
    expect(
      find.text('Trigger: When the study session feels boring'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Yes').first);
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.widgetWithText(OutlinedButton, 'No').last,
      find.byType(ListView),
      const Offset(0, -200),
    );
    final noButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'No').last,
    );
    noButton.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Finish Review'));
    await tester.tap(find.text('Finish Review'));
    await tester.pumpAndSettle();

    expect(find.text('Add Mistake'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final savedEntries = preferences.getStringList('saved_mistakes');

    expect(savedEntries, isNotNull);

    final decodedEntries = savedEntries!
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    expect(decodedEntries[0]['repeatCount'], 0);
    expect(
      decodedEntries[0]['trigger'],
      'When beginning a new task block',
    );
    expect(decodedEntries[1]['repeatCount'], 3);
    expect(
      decodedEntries[1]['trigger'],
      'When the study session feels boring',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MistakeTrackingApp());
    await tester.pumpAndSettle();

    expect(find.text('Daily Review'), findsNothing);
    expect(find.text('Add Mistake'), findsOneWidget);
  });
}
