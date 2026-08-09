import 'package:derde_divisie/features/voorspellen/eindstand_voorspelling_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dateText = 'Open tot en met 31 augustus 2026';

  Future<void> pumpStatusBar(
    WidgetTester tester, {
    required double width,
    SaveStatus status = SaveStatus.saved,
    TextScaler textScaler = TextScaler.noScaling,
    bool showClubList = false,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: Column(
                children: [
                  PredictionStatusBar(
                    locked: false,
                    points: 0,
                    saveStatus: status,
                    saving: false,
                    onRetry: () {},
                  ),
                  if (showClubList)
                    Expanded(
                      child: ListView.builder(
                        itemCount: 18,
                        itemBuilder: (context, index) => SizedBox(
                          height: 56,
                          child: Text('Club ${index + 1}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps date readable and puts saved status below at 360px',
      (tester) async {
    await pumpStatusBar(tester, width: 360);

    final date = find.text(dateText);
    final saved = find.text('Opgeslagen');
    final dateSize = tester.getSize(date);
    final barSize = tester.getSize(find.byType(PredictionStatusBar));

    expect(dateSize.width, greaterThan(200));
    expect(
        tester.getTopLeft(saved).dy, greaterThan(tester.getTopLeft(date).dy));
    expect(barSize.height, lessThan(140));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps date and saved status side by side on wide screens',
      (tester) async {
    await pumpStatusBar(tester, width: 800);

    final dateTop = tester.getTopLeft(find.text(dateText)).dy;
    final savedTop = tester.getTopLeft(find.text('Opgeslagen')).dy;

    expect((dateTop - savedTop).abs(), lessThan(10));
    expect(
      tester.getTopLeft(find.text('Opgeslagen')).dx,
      greaterThan(tester.getTopLeft(find.text(dateText)).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle instruction uses a separate line on a narrow screen',
      (tester) async {
    await pumpStatusBar(tester, width: 360, status: SaveStatus.idle);

    final instruction = find.text('Sleep clubs om je voorspelling op te slaan');
    expect(instruction, findsOneWidget);
    expect(
      tester.getTopLeft(instruction).dy,
      greaterThan(tester.getTopLeft(find.text(dateText)).dy),
    );
    expect(
      tester.getSize(find.byType(PredictionStatusBar)).height,
      lessThan(180),
    );
    expect(tester.takeException(), isNull);
  });

  for (final testCase in [
    {'width': 360.0, 'scale': 1.5},
    {'width': 360.0, 'scale': 2.0},
    {'width': 412.0, 'scale': 2.0},
  ]) {
    testWidgets(
      'remains usable at ${testCase['width']}px and ${testCase['scale']}x text',
      (tester) async {
        await pumpStatusBar(
          tester,
          width: testCase['width']!,
          textScaler: TextScaler.linear(testCase['scale']!),
          showClubList: true,
        );

        final date = find.text(dateText);
        final saved = find.text('Opgeslagen');
        final bar = find.byType(PredictionStatusBar);
        final dateSize = tester.getSize(date);

        expect(date, findsOneWidget);
        expect(saved, findsOneWidget);
        expect(dateSize.width, greaterThan(200));
        expect(dateSize.width, greaterThan(dateSize.height * 1.5));
        expect(tester.getSize(bar).height, lessThan(260));
        expect(
          tester.getTopLeft(saved).dy,
          greaterThan(tester.getTopLeft(date).dy),
        );
        expect(
          tester.getTopLeft(find.text('Club 1')).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(bar).dy),
        );
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('Club 18'),
          300,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Club 18'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
