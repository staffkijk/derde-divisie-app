import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/features/moderator/social_media_card_screen.dart';

void main() {
  testWidgets('programma exporteert 9 A en 9 B met werkelijke datums en tijden',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matches = <SocialCardMatch>[];
    for (final division in ['A', 'B']) {
      for (var i = 8; i >= 0; i--) {
        // Vrijdag, zaterdag, zondag en een verplaatste dinsdagwedstrijd.
        final day = i == 8 ? 18 : 14 + i % 3;
        final date = DateTime(2026, 8, day, 14 + i % 3, 15);
        final time = '${date.hour}:15';
        matches.add(SocialCardMatch(
          id: '$division-$i',
          division: division,
          round: 5,
          homeTeam: 'Eemdijk',
          awayTeam: 'Hollandia',
          kickoffTime: time,
          dateTime: date,
          status: MatchStatus.scheduled,
          data: {
            'division': division,
            'round': 5,
            'date': '2026-08-${day.toString().padLeft(2, '0')}',
            'kickoffTime': time
          },
        ));
      }
    }
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(
      key: key,
      child: SocialMediaExportCanvas(
        divisionName: 'Derde Divisie A',
        round: 5,
        mode: SocialCardMode.program,
        data: SocialCardData(
            matches: matches,
            standings: const [],
            predictionSummary: const PredictionSummary()),
      ),
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(MatchRow), findsNWidgets(18));
    expect(find.byType(TeamLogo), findsNWidgets(36));
    expect(find.byType(StandTable), findsNothing);
    expect(find.text('PROGRAMMA'), findsOneWidget);
    expect(
        find.text('Speelronde 5  \u2022  Derde Divisie A + B'), findsOneWidget);
    final columns = tester
        .widgetList<ProgramDivisionColumn>(find.byType(ProgramDivisionColumn))
        .toList();
    expect(columns.map((c) => c.matches.length), [9, 9]);
    for (final column in columns) {
      expect(column.matches.every((m) => m.round == 5), isTrue);
      final groups = groupSocialMatchesByDate(column.matches);
      expect(groups.keys.map((d) => d.day), [14, 15, 16, 18]);
      for (final entry in groups.entries) {
        expect(
            entry.value.every((m) => m.dateTime!.day == entry.key.day), isTrue);
        for (var i = 1; i < entry.value.length; i++) {
          expect(SocialCardMatch.compare(entry.value[i - 1], entry.value[i]),
              lessThanOrEqualTo(0));
        }
      }
    }
    for (final header in ['VR 14 AUG', 'ZA 15 AUG', 'ZO 16 AUG', 'DI 18 AUG']) {
      expect(find.text(header), findsNWidgets(2));
    }
    final rows = tester.widgetList<MatchRow>(find.byType(MatchRow)).toList();
    expect(rows.every((r) => r.mode == SocialCardMode.program), isTrue);
    expect(find.text('14:15'), findsNWidgets(6));
    expect(find.text('15:15'), findsNWidgets(6));
    expect(find.text('16:15'), findsNWidgets(6));
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      expect(image.width, 1600);
      expect(image.height, 900);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png!.lengthInBytes, greaterThan(1000));
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
