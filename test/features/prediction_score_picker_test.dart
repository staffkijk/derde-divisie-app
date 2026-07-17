import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/voorspellen/widgets/prediction_score_picker.dart';

void main() {
  test('snelle uitslagen staan in logische groepen', () {
    expect(
      PredictionScorePicker.quickScoreGroups.map((group) => group.label),
      ['Thuiswinst', 'Gelijk', 'Uitwinst'],
    );
    expect(
      PredictionScorePicker.quickScoreGroups
          .expand((group) => group.scores)
          .map((score) => score.label),
      ['3-1', '2-1', '1-0', '0-0', '1-1', '2-2', '0-1', '1-2', '1-3'],
    );
  });

  testWidgets('snelle uitslag vult beide scores met een callback',
      (tester) async {
    final selected = <PredictionScore>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionScorePicker(
            homeScore: null,
            awayScore: null,
            locked: false,
            semanticLabel: 'Testwedstrijd',
            onScoreSelected: selected.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2-1'));
    await tester.pumpAndSettle();

    expect(selected, hasLength(1));
    expect(selected.single.home, 2);
    expect(selected.single.away, 1);
  });

  testWidgets('Enter opent de scoreselectie', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionScorePicker(
            homeScore: 1,
            awayScore: 0,
            locked: false,
            semanticLabel: 'Testwedstrijd',
            onScoreSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Kies uitslag'), findsOneWidget);
  });

  testWidgets('locked scorevelden openen niet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionScorePicker(
            homeScore: 1,
            awayScore: 0,
            locked: true,
            semanticLabel: 'Testwedstrijd',
            onScoreSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Kies uitslag'), findsNothing);
  });

  testWidgets('Anders accepteert alleen geldige scores 0 tot en met 20',
      (tester) async {
    final selected = <PredictionScore>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionScorePicker(
            homeScore: null,
            awayScore: null,
            locked: false,
            semanticLabel: 'Testwedstrijd',
            onScoreSelected: selected.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anders'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Thuis'), '-1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Uit'), '2.5');
    await tester.tap(find.text('Toepassen'));
    await tester.pumpAndSettle();

    expect(selected, isEmpty);
    expect(find.text('Gebruik 0 t/m 20'), findsOneWidget);
    expect(find.text('Vul een geheel getal in'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Thuis'), '20');
    await tester.enterText(find.widgetWithText(TextFormField, 'Uit'), '0');
    await tester.tap(find.text('Toepassen'));
    await tester.pumpAndSettle();

    expect(selected, hasLength(1));
    expect(selected.single.home, 20);
    expect(selected.single.away, 0);
  });
}
