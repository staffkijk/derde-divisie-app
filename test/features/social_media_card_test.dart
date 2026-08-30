import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';
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
  MatchStatus status = MatchStatus.scheduled,
  bool processed = false,
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
    dateTime: dateTime ?? DateTime(2026, 8, 15),
    data: {
      'division': division,
      'round': round,
      'date': '2026-08-15',
      'kickoffTime': '15:00',
      'roundMatchIndex': index,
      'processed': processed,
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
      testWidgets('behoudt vaste exportmaat bij viewport $width',
          (tester) async {
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

  testWidgets('programmaheader is compact en gecentreerd', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(canvas());
    expect(find.text('PROGRAMMA'), findsOneWidget);
    expect(
      find.text('Speelronde 1  \u{2022}  Derde Divisie A + B'),
      findsOneWidget,
    );
    expect(find.text('derdediv.nl'), findsOneWidget);
    final canvasCenter = tester.getCenter(
      find.byKey(const ValueKey('social-export-canvas')),
    );
    final titleCenter = tester.getCenter(
      find.byKey(const ValueKey('social-header-title')),
    );
    expect((canvasCenter.dx - titleCenter.dx).abs(), lessThan(1));
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
    expect(find.text('Derde Divisie A'), findsOneWidget);
    expect(find.text('Speelronde 1'), findsOneWidget);
    expect(find.text('UITSLAGEN'), findsOneWidget);
    expect(find.text('STAND'), findsOneWidget);
    expect(find.text('BIJGEWERKTE STAND'), findsNothing);
    expect(find.text('Speelronde in cijfers'), findsNothing);
    expect(find.text('0 - 1'), findsWidgets);
    expect(find.byKey(const ValueKey('stand-header')), findsOneWidget);
    for (final header in ['#', 'Club', 'G', 'DS', 'Ptn']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(
      tester
          .getSize(find.byKey(const ValueKey('match-row-match-0-A-1')))
          .height,
      lessThanOrEqualTo(58),
    );
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

  testWidgets('clublogo’s gebruiken hoge filterkwaliteit in beide exports',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final mode in [SocialCardMode.program, SocialCardMode.results]) {
      await tester.pumpWidget(canvas(mode: mode));
      final logos = find.byType(TeamLogo);
      expect(logos, findsWidgets);
      final images = find.descendant(of: logos, matching: find.byType(Image));
      expect(images, findsWidgets);
      for (final image in tester.widgetList<Image>(images)) {
        expect(image.filterQuality, FilterQuality.high);
      }
    }
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

  test('Divisie B-selectie behoudt TOGB en Zwaluwen in speelronde 1', () {
    final matches = [
      match(0, division: 'B', round: 1, home: 'UNA', away: 'TOGB'),
      match(1, division: 'B', round: 1, home: 'Dongen', away: 'Zwaluwen'),
      match(2, division: 'B', round: 2, home: 'TOGB', away: 'Zwaluwen'),
      match(3, division: 'A', round: 1, home: 'Andere', away: 'Wedstrijd'),
    ];
    final selected = filterSocialMatches(matches, division: 'B', round: 1);
    expect(selected, hasLength(2));
    expect(selected.expand((entry) => [entry.homeTeam, entry.awayTeam]),
        containsAll(['TOGB', 'Zwaluwen']));
  });
  test('periodewinnaars gebruiken opgeslagen rondepunten en delen de winst',
      () {
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
      periodMatchDivisions: const {'m1': 'A', 'm2': 'B'},
      throughMatchDivisions: const {'m1': 'A', 'm2': 'B'},
      predictions: const [
        {'wedstrijdId': 'm1', 'gebruikerId': 'u1', 'punten': 3},
        {'wedstrijdId': 'm2', 'gebruikerId': 'u1', 'punten': 1},
        {'matchId': 'm1', 'userId': 'u2', 'punten': 4},
        {'wedstrijdId': 'andere-ronde', 'gebruikerId': 'u3', 'punten': 9},
      ],
    );
    expect(summary.periodWinners.map((entry) => entry.name), ['Bram']);
    expect(summary.periodWinners.first.score, 4);
    expect(
      summary.globalTop.map((entry) => entry.name),
      ['Bram', 'Ada', 'Cato'],
    );
  });

  testWidgets('voorspelpoule rendert periodewinnaar en top 5', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final summary = PredictionSummary(
      periodWinners: const [PredictionRankEntry('1', 'Ada', 12)],
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
    expect(find.text('PERIODEWINNAAR'), findsOneWidget);
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
      socialFileName(SocialCardMode.predictions, 'A', 10),
      'derdediv_voorspelpoule_speelronde_10.png',
    );
  });

  test('prediction publicatiemomenten gebruiken vaste competitieblokken', () {
    expect(
        PredictionSocialPeriod.publicationRounds, [5, 10, 15, 20, 25, 30, 34]);
    for (final expected in const {
      5: [1, 5],
      10: [6, 10],
      15: [11, 15],
      30: [26, 30],
      34: [31, 34]
    }.entries) {
      final period = PredictionSocialPeriod.forRound(expected.key);
      expect([period.startRound, period.endRound], expected.value);
    }
    expect(PredictionSocialPeriod.forRound(7).endRound, 10);
  });

  test('historische top gebruikt beste divisiescore tot gekozen ronde', () {
    final summary = buildPredictionSummary(
      users: const [
        RankingUser('u1', {'username': 'Ada', 'punten_A': 999}),
        RankingUser('u2', {'username': 'Bram'})
      ],
      predictions: const [
        {'wedstrijdId': 'a1', 'gebruikerId': 'u1', 'punten': 3},
        {'wedstrijdId': 'b1', 'gebruikerId': 'u1', 'punten': 8},
        {'wedstrijdId': 'a1', 'gebruikerId': 'u2', 'punten': 7},
        {'wedstrijdId': 'later', 'gebruikerId': 'u1', 'punten': 100},
      ],
      periodMatchDivisions: const {'a1': 'A'},
      throughMatchDivisions: const {'a1': 'A', 'b1': 'B'},
    );
    expect(summary.periodWinners.single.name, 'Bram');
    expect(summary.globalTop.first.name, 'Ada');
    expect(summary.globalTop.first.score, 8);
  });

  test('vorm koppelt aliases, divisie en perspectief correct', () {
    final standings = [standing(0, 'A')];
    final custom = SocialStanding(
        division: 'A',
        name: 'ADO ’20',
        position: 1,
        played: 3,
        wins: 1,
        draws: 1,
        losses: 1,
        goalsFor: 3,
        goalsAgainst: 3,
        goalDifference: 0,
        points: 4);
    final matches = [
      match(1,
          home: "ADO '20",
          away: 'ACV',
          homeScore: 2,
          awayScore: 0,
          status: MatchStatus.finished),
      match(2,
          home: 'ACV',
          away: 'ADO20',
          homeScore: 1,
          awayScore: 1,
          status: MatchStatus.finished),
      match(3,
          home: 'ADO20',
          away: 'ACV',
          homeScore: 0,
          awayScore: 1,
          status: MatchStatus.finished),
      match(4,
          division: 'B',
          home: 'ADO20',
          away: 'UNA',
          homeScore: 9,
          awayScore: 0,
          status: MatchStatus.finished),
      match(5,
          home: 'ADO20',
          away: 'ACV',
          homeScore: 9,
          awayScore: 0,
          status: MatchStatus.postponed),
    ];
    final form =
        buildSocialForm(standings: [custom, ...standings], matches: matches);
    expect(form[canonicalSocialTeamKey(custom.name, division: 'A')],
        [SocialFormResult.win, SocialFormResult.draw, SocialFormResult.loss]);
  });

  test('alle 36 actuele clubs koppelen met centrale teamconfig', () {
    for (final team in SeasonConfig.teams) {
      expect(canonicalSocialTeamKey(team.label, division: team.division),
          '${team.division}:${team.id}');
      for (final alias in team.aliases) {
        expect(canonicalSocialTeamKey(alias, division: team.division),
            '${team.division}:${team.id}');
      }
    }
    expect(SeasonConfig.teamsForDivision('A'), hasLength(18));
    expect(SeasonConfig.teamsForDivision('B'), hasLength(18));
  });

  test('dropdownkeuzes verschillen alleen voor voorspelpoule', () {
    expect(socialRoundChoices(SocialCardMode.predictions),
        [5, 10, 15, 20, 25, 30, 34]);
    expect(socialRoundChoices(SocialCardMode.program),
        List.generate(34, (i) => i + 1));
    expect(socialRoundChoices(SocialCardMode.results),
        List.generate(34, (i) => i + 1));
  });

  test('X-tekst noemt periodewinnaar en nooit weekwinnaar', () {
    const summary = PredictionSummary(
      periodWinners: [PredictionRankEntry('u1', 'Ada', 84)],
      globalTop: [PredictionRankEntry('u1', 'Ada', 120)],
    );
    final text = predictionSocialText(summary, 10);
    expect(text, contains('Voorspelpoule na speelronde 10'));
    expect(text, contains('Periodewinnaar speelronde 6 t/m 10'));
    expect(text, isNot(contains('Weekwinnaar')));
    expect(text.runes.length, lessThanOrEqualTo(280));
  });

  test('onvolledig blok wordt niet exporteerbaar gemarkeerd', () {
    final period = PredictionSocialPeriod.forRound(5);
    expect(
        predictionPeriodIsComplete([
          match(1, round: 1, status: MatchStatus.finished, processed: true),
          match(2, round: 2, status: MatchStatus.finished, processed: false),
        ], period),
        isFalse);
    expect(
        predictionPeriodIsComplete([
          for (var round = 1; round <= 5; round++)
            match(round,
                round: round, status: MatchStatus.finished, processed: true),
        ], period),
        isTrue);
  });

  test('alle clubs met drie afgeronde wedstrijden hebben drie vormblokjes', () {
    for (final division in ['A', 'B']) {
      final teams = SeasonConfig.teamsForDivision(division);
      final matches = <SocialCardMatch>[];
      final rotating = teams.toList();
      for (var round = 1; round <= 3; round++) {
        for (var index = 0; index < 9; index++) {
          matches.add(match(
            round * 10 + index,
            division: division,
            round: round,
            home: rotating[index].label,
            away: rotating[17 - index].label,
            homeScore: index % 3,
            awayScore: (index + round) % 3,
            status: MatchStatus.finished,
            processed: true,
          ));
        }
        rotating.insert(1, rotating.removeLast());
      }
      final standings = teams.map((team) => SocialStanding(
            division: division,
            name: team.label,
            teamId: team.id,
            position: 1,
            played: 3,
            wins: 1,
            draws: 1,
            losses: 1,
            goalsFor: 3,
            goalsAgainst: 3,
            goalDifference: 0,
            points: 4,
          ));
      final form = buildSocialForm(standings: standings, matches: matches);
      for (final team in teams) {
        expect(form['$division:${team.id}'], hasLength(3), reason: team.label);
      }
    }
  });

  group('periodewinnaar gebruikt officiële globale max(A, B)', () {
    PredictionSummary summaryFor(Map<String, List<int>> scores) {
      final users = <RankingUser>[];
      final predictions = <Map<String, dynamic>>[];
      final matches = <String, String>{};
      for (final entry in scores.entries) {
        users.add(RankingUser(entry.key, {'username': entry.key}));
        final aId = '${entry.key}-A';
        final bId = '${entry.key}-B';
        matches[aId] = 'A';
        matches[bId] = 'B';
        if (entry.value[0] >= 0) {
          predictions.add({
            'wedstrijdId': aId,
            'gebruikerId': entry.key,
            'punten': entry.value[0]
          });
        }
        if (entry.value[1] >= 0) {
          predictions.add({
            'wedstrijdId': bId,
            'gebruikerId': entry.key,
            'punten': entry.value[1]
          });
        }
      }
      return buildPredictionSummary(
        users: users,
        predictions: predictions,
        periodMatchDivisions: matches,
        throughMatchDivisions: matches,
      );
    }

    test('A 80 en B 70 geeft 80', () {
      final summary = summaryFor({
        'speler': [80, 70]
      });
      expect(summary.periodWinners.single.score, 80);
    });

    test('A 50 en B 90 geeft 90', () {
      final summary = summaryFor({
        'speler': [50, 90]
      });
      expect(summary.periodWinners.single.score, 90);
    });

    test('A plus B wordt niet bij elkaar opgeteld', () {
      final summary = summaryFor({
        'beide': [60, 60],
        'alleenA': [100, -1]
      });
      expect(summary.periodWinners.single.name, 'alleenA');
      expect(summary.periodWinners.single.score, 100);
    });

    test('gelijke maxscore geeft gedeelde periodewinst', () {
      final summary = summaryFor({
        'eerste': [80, 20],
        'tweede': [10, 80]
      });
      expect(summary.periodWinners.map((entry) => entry.name),
          ['eerste', 'tweede']);
      expect(
          summary.periodWinners.map((entry) => entry.score), everyElement(80));
    });

    test('gebruiker met alleen A kan winnen', () {
      final summary = summaryFor({
        'alleenA': [91, -1],
        'ander': [40, 80]
      });
      expect(summary.periodWinners.single.name, 'alleenA');
    });

    test('gebruiker met alleen B kan winnen', () {
      final summary = summaryFor({
        'alleenB': [-1, 92],
        'ander': [80, 40]
      });
      expect(summary.periodWinners.single.name, 'alleenB');
    });

    test(
        'periodewinnaar en historische top gebruiken dezelfde globale definitie',
        () {
      final summary = summaryFor({
        'beide': [60, 60],
        'beste': [20, 100]
      });
      expect(summary.periodWinners.single.name, 'beste');
      expect(summary.periodWinners.single.score, 100);
      expect(summary.globalTop.first.name, 'beste');
      expect(summary.globalTop.first.score, 100);
    });
  });
}
