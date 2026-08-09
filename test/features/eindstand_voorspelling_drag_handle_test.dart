import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_prediction_parser.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_voorspelling_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> dragHandle(
  WidgetTester tester,
  Finder handle,
  Offset movement, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  TestGesture? gesture;

  try {
    gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: kind,
    );

    await tester.pump();

    await gesture.moveBy(movement);

    await tester.pump(
      const Duration(milliseconds: 300),
    );

    await gesture.up();
    gesture = null;

    await tester.pump();
    await tester.pump(
      const Duration(milliseconds: 500),
    );
  } finally {
    if (gesture != null) {
      await gesture.cancel();
      await tester.pump();
    }
  }
}

void main() {
  const clubs = [
    'Ajax Amateurs',
    'Excelsior Maassluis',
    'Harkemase Boys met een extra lange clubnaam',
    'Quick Boys',
  ];

  Future<List<String>> pumpClubList(
    WidgetTester tester, {
    required double width,
    required TargetPlatform platform,
  }) async {
    final order = [...clubs];

    await tester.binding.setSurfaceSize(
      Size(width, 700),
    );
    addTearDown(
      () => tester.binding.setSurfaceSize(null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: platform,
        ),
        home: Scaffold(
          body: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: order.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) {
                newIndex--;
              }

              final club = order.removeAt(oldIndex);
              order.insert(newIndex, club);
            },
            itemBuilder: (context, index) {
              return PredictionClubRow(
                key: ValueKey(order[index]),
                index: index,
                club: order[index],
                locked: false,
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();

    return order;
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    for (final width in [
      360.0,
      390.0,
      412.0,
    ]) {
      testWidgets(
        'iedere club heeft een zichtbare 48px handle op '
        '$platform bij ${width}px',
        (tester) async {
          await pumpClubList(
            tester,
            width: width,
            platform: platform,
          );

          expect(
            find.byIcon(Icons.drag_handle),
            findsNWidgets(clubs.length),
          );

          for (final club in clubs) {
            final handle = find.byKey(
              ValueKey('drag-handle-$club'),
            );

            expect(
              handle,
              findsOneWidget,
            );

            expect(
              tester.getSize(handle),
              const Size(48, 48),
            );

            expect(
              tester.getTopLeft(handle).dx,
              greaterThan(
                tester
                    .getTopRight(
                      find.text(club),
                    )
                    .dx,
              ),
            );

            expect(
              tester.getTopRight(handle).dx,
              lessThanOrEqualTo(width),
            );
          }

          expect(
            tester.takeException(),
            isNull,
          );
        },
      );
    }
  }

  testWidgets(
    'touch slepen start direct via de handle en wijzigt de volgorde',
    (tester) async {
      final order = await pumpClubList(
        tester,
        width: 390,
        platform: TargetPlatform.android,
      );

      final handle = find.byKey(
        const ValueKey(
          'drag-handle-Ajax Amateurs',
        ),
      );

      await dragHandle(
        tester,
        handle,
        const Offset(0, 160),
      );

      expect(
        order.first,
        isNot('Ajax Amateurs'),
      );

      final reordered = [...order];

      await tester.pump();

      expect(
        order,
        reordered,
        reason: 'een rebuild mag de lokale volgorde niet resetten',
      );

      expect(
        tester.takeException(),
        isNull,
      );
    },
  );

  testWidgets(
    'muis kan op desktop direct via de handle slepen',
    (tester) async {
      final order = await pumpClubList(
        tester,
        width: 900,
        platform: TargetPlatform.windows,
      );

      final handle = find.byKey(
        const ValueKey(
          'drag-handle-Ajax Amateurs',
        ),
      );

      expect(
        handle,
        findsOneWidget,
      );

      await dragHandle(
        tester,
        handle,
        const Offset(0, 160),
        kind: PointerDeviceKind.mouse,
      );

      expect(
        order.first,
        isNot('Ajax Amateurs'),
      );

      expect(
        order.toSet(),
        clubs.toSet(),
      );

      expect(
        tester.takeException(),
        isNull,
      );
    },
  );

  testWidgets(
    'oldIndex en newIndex verplaatsen omlaag zonder off-by-one',
    (tester) async {
      final order = await pumpClubList(
        tester,
        width: 390,
        platform: TargetPlatform.android,
      );

      final handle = find.byKey(
        const ValueKey(
          'drag-handle-Ajax Amateurs',
        ),
      );

      await dragHandle(
        tester,
        handle,
        const Offset(0, 300),
      );

      expect(
        order.indexOf('Ajax Amateurs'),
        greaterThan(0),
      );

      expect(
        order.toSet(),
        clubs.toSet(),
      );
    },
  );

  for (final division in [
    SeasonConfig.divisionA,
    SeasonConfig.divisionB,
  ]) {
    test(
      'via parser geladen lijst kan worden herschikt in Divisie $division',
      () {
        final configuredTeams =
            SeasonConfig.teamNamesForDivision(division).take(4).toList();

        final parsed = parseEindstandPrediction(
          data: {
            'seasonId': SeasonConfig.activeSeasonId,
            'voorspelling': configuredTeams,
          },
          configuredTeams: configuredTeams,
          activeSeasonId: SeasonConfig.activeSeasonId,
        );

        final originalOrder = List<String>.from(
          parsed.clubs,
        );

        final reordered = reorderEindstandClubs(
          parsed.clubs,
          0,
          2,
        );

        expect(
          reordered,
          isNot(originalOrder),
        );

        expect(
          reordered[1],
          originalOrder[0],
        );

        expect(
          reordered.toSet(),
          originalOrder.toSet(),
        );

        expect(
          parsed.clubs,
          originalOrder,
        );
      },
    );
  }
}
