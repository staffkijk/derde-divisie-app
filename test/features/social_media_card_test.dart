import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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
  MatchStatus status = MatchStatus.scheduled,
}) {
  return SocialCardMatch(
    id: 'match-$index-$division-$round',
    division: division,
    round: round,
    homeTeam: home ?? 'Thuisclub $index',
    awayTeam: away ?? 'Uitclub $index',
    kickoffTime: '15:00',
    status: status,
    homeScore: homeScore,
    awayScore: awayScore,
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
        minWidth: socialExportSize.width,
        maxWidth: socialExportSize.width,
        minHeight: socialExportSize.height,
        maxHeight: socialExportSize.height,
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
  group('gedeelde PNG- en X-statusformatter', () {
    for (final entry in {
      MatchStatus.postponed: 'Uitgesteld',
      MatchStatus.cancelled: 'Afgelast',
      MatchStatus.abandoned: 'Gestaakt',
    }.entries) {
      for (final mode in [SocialCardMode.program, SocialCardMode.results]) {
        test('${entry.key.name} in ${mode.name}, ook met oude scores', () {
          for (final score in [null, 2]) {
            final value = match(0,
                status: entry.key,
                home: 'Eemdijk',
                away: 'Hollandia',
                homeScore: score,
                awayScore: score);
            final label = socialMatchCenterLabel(value, mode);
            expect(label, entry.value);
            expect(label, isNot('15:00'));
            expect('${value.homeTeam} $label ${value.awayTeam}',
                'Eemdijk ${entry.value} Hollandia');
          }
        });
      }
    }
    test(
        'scores alleen in uitslagen; ontbrekende of ongeldige scores vallen terug',
        () {
      final finished =
          match(0, status: MatchStatus.finished, homeScore: 2, awayScore: 1);
      expect(socialMatchCenterLabel(finished, SocialCardMode.results), '2 - 1');
      expect(socialMatchCenterLabel(finished, SocialCardMode.program), '15:00');
      expect(
          socialMatchCenterLabel(
              match(0, homeScore: 0, awayScore: 0), SocialCardMode.results),
          '0 - 0');
      for (final value in [
        match(0),
        match(0, homeScore: 2),
        match(0, awayScore: 1),
        match(0, homeScore: -1, awayScore: 0)
      ]) {
        expect(socialMatchCenterLabel(value, SocialCardMode.results), '15:00');
      }
    });
  });

  final statusMatches = [
    match(0, home: 'Eemdijk', away: 'Hollandia', status: MatchStatus.postponed),
    match(1, status: MatchStatus.cancelled),
    match(2, status: MatchStatus.abandoned),
    match(3, status: MatchStatus.finished, homeScore: 2, awayScore: 1),
    for (var i = 4; i < 9; i++)
      match(i, status: MatchStatus.finished, homeScore: 0, awayScore: 0),
  ];
  for (final width in [360.0, 390.0, 412.0, 1300.0]) {
    for (final preview in [false, true]) {
      testWidgets(
          'uitslagstatussen zonder overflow op $width, preview=$preview',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final value = data(matches: statusMatches);
        await tester.pumpWidget(preview
            ? MaterialApp(
                home: Scaffold(
                    body: SingleChildScrollView(
                        child: SocialMediaPreview(
                            child: SocialMediaExportCanvas(
                                divisionName: 'Derde Divisie A',
                                round: 1,
                                mode: SocialCardMode.results,
                                data: value)))))
            : canvas(mode: SocialCardMode.results, value: value));
        for (final label in ['Uitgesteld', 'Afgelast', 'Gestaakt', '2 - 1']) {
          expect(find.text(label), findsOneWidget);
          final paragraph =
              tester.renderObject<RenderParagraph>(find.text(label));
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(find.text('15:00'), findsNothing);
        final left =
            tester.getRect(find.byKey(const ValueKey('social-matches-column')));
        final right = tester
            .getRect(find.byKey(const ValueKey('social-standings-column')));
        expect(left.right, lessThan(right.left));
        expect(left.top, closeTo(right.top, 0.01));
        expect(find.byType(MatchRow), findsNWidgets(9));
        expect(find.text('Club 17'), findsOneWidget);
        expect(find.text('Eemdijk'), findsOneWidget);
        expect(find.text('Hollandia'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('statussen worden op het daadwerkelijke PNG-canvas geschilderd',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: key,
            child: SocialMediaExportCanvas(
                divisionName: 'Derde Divisie A',
                round: 1,
                mode: SocialCardMode.results,
                data: data(matches: statusMatches)))));
    await tester.pumpAndSettle();
    for (final label in ['Uitgesteld', 'Afgelast', 'Gestaakt', '2 - 1']) {
      expect(find.descendant(of: find.byKey(key), matching: find.text(label)),
          findsOneWidget);
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      expect(image.width, 1600);
      expect(image.height, 900);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      expect(bytes!.buffer.asUint8List().take(8),
          [137, 80, 78, 71, 13, 10, 26, 10]);
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  group('vaste exportcanvas', () {
    for (final width in [360.0, 390.0, 412.0, 1300.0]) {
      testWidgets('blijft 1600x900 bij viewport $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(canvas());
        final size = tester.getSize(
          find.byKey(const ValueKey('social-export-canvas')),
        );
        expect(size, const Size(1600, 900));
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('programma bevat alle negen wedstrijden en volledige stand',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(canvas());
    expect(find.text('PROGRAMMA'), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      expect(find.text('Thuisclub $i'), findsOneWidget);
      expect(find.text('Uitclub $i'), findsOneWidget);
    }
    expect(find.text('STAND'), findsOneWidget);
    expect(find.text('Club 17'), findsOneWidget);
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
