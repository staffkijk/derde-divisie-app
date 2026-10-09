import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:derde_divisie/features/profiel/bekijk_profiel_screen.dart';

void main() {
  testWidgets('K: missing profile exits loading', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: BekijkProfielScreen(
            userId: 'missing', profileLoader: () async => null)));
    await tester.pumpAndSettle();
    expect(find.text('Dit profiel bestaat niet.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('K: failed profile exits loading and retry completes',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: BekijkProfielScreen(
            userId: 'offline',
            profileLoader: () async {
              if (calls++ == 0) throw StateError('offline');
              return {
                'username': 'Loaded',
                'avatarUrl': 'assets/images/profiel_bal.png'
              };
            })));
    await tester.pumpAndSettle();
    expect(find.text('Profiel kon niet worden geladen.'), findsOneWidget);
    await tester.tap(find.text('Opnieuw proberen'));
    await tester.pumpAndSettle();
    expect(find.text('Loaded'), findsWidgets);
  });
}
