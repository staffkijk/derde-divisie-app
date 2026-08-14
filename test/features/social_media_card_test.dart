import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/features/moderator/social_media_card_screen.dart';

SocialCardMatch match(
  int index, {
  String division = 'A',
  int round = 1,
  String? home,
  String? away,
  int? homeScore,
  int? awayScore,
  DateTime? dateTime,
}) {
  return SocialCardMatch(
    id: 'match-$index-$division-$round',
    division: division,
    round: round,
    homeTeam: home ?? 'Thuisclub $index',
    awayTeam: away ?? 'Uitclub $index',
    kickoffTime: '15:00',
    status: MatchStatus.scheduled,
    homeScore: homeScore,
    awayScore: awayScore,
    dateTime: dateTime ?? DateTime(2026, 8, 15),
    data: {
      'division': division,
      'round': round,
      'date': '2026-08-15',
      'kickoffTime': '15:00',
      'roundMatchIndex': index,
    },
  );
}

SocialStanding standing(int index, String division) {
  return SocialStanding(
    division: division,
    name: index == 0 ? 'Excelsior Maassluis' : 'Club $index',
    position: index + 1,
    played: 4,
    wins: 2,
    draws: 1,
    losses: 1,
    goalsFor: 8,
    goalsAgainst: 5,
    goalDifference: 3,
    points: 7,
  );
}

SocialCardData data({
  List<SocialCardMatch>? matches,
  List<SocialStanding>? standings,
  PredictionSummary summary = const PredictionSummary(),
}) {
  return SocialCardData(
    matches: matches ?? List.generate(9, match),
    standings: standings ?? List.generate(18, (index) => standing(index, 'A')),
    predictionSummary: summary,
  );
}

Widget canvas({
  SocialCardMode mode = SocialCardMode.program,
  SocialCardData? value,
}) {
  return MaterialApp(
    home: Scaffold(
      body: OverflowBox(
        minWidth: socialExportSizeFor(mode).width,
        maxWidth: socialExportSizeFor(mode).width,
        minHeight: socialExportSizeFor(mode).height,
        maxHeight: socialExportSizeFor(mode).height,
        child: SocialMediaExportCanvas(
          divisionName: 'Derde Divisie A',
          round: 1,
          mode: mode,
          data: value ?? data(),
        ),
      ),
    ),
  );
}

void main() {
  group('vaste exportcanvas', () {
    for (final width in [360.0, 390.0, 412.0, 1300.0]) {
      testWidgets('blijft 1080x1350 bij viewport $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(canvas());
        final size = tester.getSize(
          find.byKey(const ValueKey('social-export-canvas')),
        );
        expect(size, programSocialExportSize);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('programma toont A en B naast elkaar zonder stand',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matches = [
      ...List.generate(9, (index) => match(index)),
      ...List.generate(7, (index) => match(index, division: 'B')),
    ];
    await tester.pumpWidget(canvas(value: data(matches: matches)));
    expect(find.text('PROGRAMMA'), findsOneWidget);
    expect(find.text('DERDE DIVISIE A'), findsOneWidget);
    expect(find.text('DERDE DIVISIE B'), findsOneWidget);
    expect(find.text('BIJGEWERKTE STAND'), findsNothing);
    expect(find.text('Club 17'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('programma groepeert zaterdag en ADO 20 op zondag',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matches = [
      match(0, dateTime: DateTime(2026, 8, 15)),
      match(
        1,
        home: "ADO '20",
        away: 'Hercules',
        dateTime: DateTime(2026, 8, 16),
      ),
      match(2, division: 'B', dateTime: DateTime(2026, 8, 15)),
    ];
    await tester.pumpWidget(canvas(value: data(matches: matches)));
    expect(find.text('ZA 15 AUG'), findsNWidgets(2));
    expect(find.text('ZO 16 AUG'), findsOneWidget);
    expect(find.text("ADO '20"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uitslagen toont scores en lange namen op een regel',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const names = [
      'Excelsior Maassluis',
      'Harkemase Boys',
      "Blauw Geel'38/Jumbo",
      "DVS'33 Ermelo",
    ];
    final matches = List.generate(
      9,
      (index) => match(
        index,
        home: names[index % names.length],
        away: names[(index + 1) % names.length],
        homeScore: index % 4,
        awayScore: (index + 1) % 3,
      ),
    );
    await tester.pumpWidget(
      canvas(mode: SocialCardMode.results, value: data(matches: matches)),
    );
    expect(find.text('UITSLAGEN'), findsOneWidget);
    expect(find.text('0 - 1'), findsWidgets);
    for (final name in names) {
      final widgets = tester.widgetList<Text>(
        find.byKey(ValueKey('team-$name')),
      );
      expect(widgets, isNotEmpty);
      for (final text in widgets) {
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
        expect(text.overflow, TextOverflow.ellipsis);
      }
    }
    expect(tester.takeException(), isNull);
  });

  test('filtert strikt op divisie en speelronde', () {
    final matches = [
      match(0, division: 'A', round: 1),
      match(1, division: 'B', round: 1),
      match(2, division: 'A', round: 2),
    ];
    final a = filterSocialMatches(matches, division: 'A', round: 1);
    final b = filterSocialMatches(matches, division: 'B', round: 1);
    expect(a.map((entry) => entry.id), ['match-0-A-1']);
    expect(b.map((entry) => entry.id), ['match-1-B-1']);
  });

  test('weekwinnaars gebruiken opgeslagen rondepunten en delen de winst', () {
    final users = [
      const RankingUser('u1', {
        'username': 'Ada',
        'punten_A': 8,
        'punten_B': 14,
      }),
      const RankingUser('u2', {
        'username': 'Bram',
        'punten_A': 14,
        'punten_B': 2,
      }),
      const RankingUser('u3', {
        'username': 'Cato',
        'punten_A': 20,
      }),
    ];
    final summary = buildPredictionSummary(
      users: users,
      roundMatchIds: {'m1', 'm2'},
      predictions: const [
        {'wedstrijdId': 'm1', 'gebruikerId': 'u1', 'punten': 3},
        {'wedstrijdId': 'm2', 'gebruikerId': 'u1', 'punten': 1},
        {'matchId': 'm1', 'userId': 'u2', 'punten': 4},
        {'wedstrijdId': 'andere-ronde', 'gebruikerId': 'u3', 'punten': 9},
      ],
    );
    expect(summary.weekWinners.map((entry) => entry.name), ['Ada', 'Bram']);
    expect(summary.weekWinners.first.score, 4);
    expect(
      summary.globalTop.map((entry) => entry.name),
      ['Cato', 'Ada', 'Bram'],
    );
  });

  testWidgets('voorspelpoule rendert weekwinnaar en top 5', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final summary = PredictionSummary(
      weekWinners: const [PredictionRankEntry('1', 'Ada', 12)],
      globalTop: List.generate(
        5,
        (index) => PredictionRankEntry(
          '$index',
          'Speler $index',
          30 - index,
        ),
      ),
    );
    await tester.pumpWidget(
      canvas(
        mode: SocialCardMode.predictions,
        value: data(summary: summary),
      ),
    );
    expect(find.text('VOORSPELPOULE'), findsOneWidget);
    expect(find.text('WEEKWINNAAR'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Speler 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    testWidgets('preview heeft geen overflow op $width px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SocialMediaPreview(
                mode: SocialCardMode.program,
                child: SocialMediaExportCanvas(
                  divisionName: 'Derde Divisie A',
                  round: 1,
                  mode: SocialCardMode.program,
                  data: data(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('bestandsnamen en PNG-extensie zijn stabiel', () {
    expect(
      socialFileName(SocialCardMode.program, 'A', 1),
      'derdediv_programma_A_speelronde_1.png',
    );
    expect(
      socialFileName(SocialCardMode.results, 'B', 4),
      'derdediv_uitslagen_B_speelronde_4.png',
    );
    expect(
      socialFileName(SocialCardMode.predictions, 'A', 3),
      'derdediv_voorspelpoule_speelronde_3.png',
    );
  });
}
