import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/moderator/moderator_dashboard_screen.dart';

void main() {
  testWidgets('toont geen moderatorcontent terwijl rechten laden',
      (tester) async {
    final completer = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: ModeratorDashboardScreen(
          moderatorStatusLoader: () => completer.future,
          moderatorContentBuilder: (_) => const Text('Moderator content'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Moderator content'), findsNothing);
    expect(find.text('Uitslagen invoeren'), findsNothing);
    expect(find.text('CSV-exports'), findsNothing);
  });

  testWidgets('weigert normale gebruiker zonder moderatorrechten',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModeratorDashboardScreen(
          moderatorStatusLoader: () async => false,
          moderatorContentBuilder: (_) => const Text('Moderator content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Geen toegang'), findsOneWidget);
    expect(
        find.text('Je account heeft geen moderatorrechten.'), findsOneWidget);
    expect(find.text('Moderator content'), findsNothing);
    expect(find.text('Uitslagen invoeren'), findsNothing);
  });

  testWidgets('toont dashboard voor moderator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ModeratorDashboardScreen(
          moderatorStatusLoader: () async => true,
          moderatorContentBuilder: (_) => const Scaffold(
            body: Center(child: Text('Moderator content')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Moderator content'), findsOneWidget);
    expect(find.text('Geen toegang'), findsNothing);
  });
}
