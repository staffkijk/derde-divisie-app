import 'dart:async';

import 'package:derde_divisie/features/derde_divisie/program_screen.dart';
import 'package:derde_divisie/features/moderator/moderator_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const oldModeratorControlsHeight390 = 321.0;
const oldProgramControlsHeight390 = 269.0;
const newControlsHeight = 62.0;

ModeratorMatchData fixtureMatch() => const ModeratorMatchData(
      id: 'm1',
      division: 'A',
      round: 1,
      roundMatchIndex: 1,
      homeTeam: 'Sparta Nijkerk',
      awayTeam: "DVS'33 Ermelo",
      homeTeamSlug: 'sparta_nijkerk',
      awayTeamSlug: 'dvs_33_ermelo',
      status: 'scheduled',
      homeScore: null,
      awayScore: null,
    );

void main() {
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('moderatorcontrols zijn compact zonder overflow op $width px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = StreamController<List<ModeratorMatchData>>();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: ModeratorMenuScreen(
              matchesStreamFactory: (_, __) => controller.stream,
            ),
          ),
        ),
      );
      controller.add([fixtureMatch()]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('moderator-results-controls')),
            )
            .height,
        newControlsHeight,
      );
      expect(find.byKey(const ValueKey('result-m1')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('result-m1'))).dy,
        lessThan(250),
      );
      expect(find.text('Sparta Nijkerk'), findsOneWidget);
      expect(find.text("DVS'33 Ermelo"), findsOneWidget);
      expect(find.byTooltip('Opslaan'), findsOneWidget);
    });
  }

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('programmacontrols zijn compact zonder overflow op $width px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: const Scaffold(
              body: Column(
                children: [
                  ProgramHeaderCard(
                    title: 'Programma Derde Divisie A',
                    selectedRound: 4,
                    rounds: [1, 2, 3, 4],
                    showRoundSelector: true,
                    onRoundChanged: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('program-controls'))).height,
        newControlsHeight,
      );
      expect(find.text('Programma · A'), findsOneWidget);
      expect(find.text('Ronde 4'), findsOneWidget);
      expect(find.textContaining('Wedstrijden per speelronde'), findsNothing);
    });
  }

  test('390px controlsecties zijn aantoonbaar kleiner dan voorheen', () {
    expect(newControlsHeight, lessThan(oldModeratorControlsHeight390));
    expect(newControlsHeight, lessThan(oldProgramControlsHeight390));
    expect(oldModeratorControlsHeight390 - newControlsHeight, 259);
    expect(oldProgramControlsHeight390 - newControlsHeight, 207);
  });
}

void _noop(int? _) {}
