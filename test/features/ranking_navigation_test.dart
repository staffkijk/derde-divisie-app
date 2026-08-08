import 'package:derde_divisie/core/widgets/ranking_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mobileWidths = [360.0, 390.0, 412.0];

  Widget rankingPage(String title, String fallbackRoute) {
    return Builder(
      builder: (context) => Scaffold(
        appBar: RankingAppBar(
          context: context,
          title: title,
          fallbackRoute: fallbackRoute,
        ),
        body: Text('$title content'),
      ),
    );
  }

  for (final width in mobileWidths) {
    testWidgets('alle ranglijstheaders hebben een terugknop op $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final title in [
        'Ranglijsten',
        'Voorspelranking archief',
        'Poule',
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: rankingPage(title, predictionsRankingsRoute)),
        );
        expect(find.byKey(const Key('ranking-back-button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('terugknop popt naar de vorige route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => rankingPage(
                    'Ranglijsten',
                    predictionsRankingsRoute,
                  ),
                ),
              ),
              child: const Text('Open ranglijst'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open ranglijst'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-back-button')));
    await tester.pumpAndSettle();

    expect(find.text('Open ranglijst'), findsOneWidget);
  });

  testWidgets('direct geopende ranglijst gebruikt de voorspel-fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: rankingPage('Ranglijsten', predictionsRankingsRoute),
        routes: {
          predictionsRankingsRoute: (_) =>
              const Scaffold(body: Text('Voorspellen ranglijsten')),
        },
      ),
    );

    await tester.tap(find.byKey(const Key('ranking-back-button')));
    await tester.pumpAndSettle();

    expect(find.text('Voorspellen ranglijsten'), findsOneWidget);
  });

  testWidgets('direct geopende pouleranglijst gebruikt de poule-fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: rankingPage('Poule', poulesOverviewRoute),
        routes: {
          poulesOverviewRoute: (_) =>
              const Scaffold(body: Text('Pouleoverzicht')),
        },
      ),
    );

    await tester.tap(find.byKey(const Key('ranking-back-button')));
    await tester.pumpAndSettle();

    expect(find.text('Pouleoverzicht'), findsOneWidget);
  });
}
