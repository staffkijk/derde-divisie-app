import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/moderator/standings_calculator.dart';

void main() {
  group('StandingsCalculator', () {
    test('berekent thuiswinst, uitwinst, gelijkspel en meerdere wedstrijden',
        () {
      final standings = StandingsCalculator.calculateDivisionStandings(
        division: 'A',
        matches: [
          _match('A', 'acv', 'ado20', 2, 0),
          _match('A', 'dvs33_ermelo', 'acv', 1, 3),
          _match('A', 'ado20', 'dvs33_ermelo', 1, 1),
        ],
      );

      final acv = _team(standings, 'acv');
      final ado20 = _team(standings, 'ado20');
      final dvs = _team(standings, 'dvs33_ermelo');

      expect(acv['played'], 2);
      expect(acv['wins'], 2);
      expect(acv['points'], 6);
      expect(acv['goalsFor'], 5);
      expect(acv['goalsAgainst'], 1);
      expect(ado20['draws'], 1);
      expect(ado20['losses'], 1);
      expect(dvs['draws'], 1);
      expect(dvs['losses'], 1);
    });

    test('neemt divisie B wedstrijden niet mee in divisie A', () {
      final standings = StandingsCalculator.calculateDivisionStandings(
        division: 'A',
        matches: [
          _match('A', 'acv', 'ado20', 1, 0),
          _match('B', 'togb', 'rksv_groene_ster', 9, 0),
        ],
      );

      expect(_team(standings, 'acv')['points'], 3);
      expect(standings.any((team) => team['teamId'] == 'togb'), isFalse);
    });

    test('sorteert op punten, gespeeld, doelsaldo, voor en tegen', () {
      final standings = StandingsCalculator.sorted([
        _stats('meer_gespeeld', points: 6, played: 3, gd: 5, gf: 8, ga: 3),
        _stats('minder_gespeeld', points: 6, played: 2, gd: 5, gf: 8, ga: 3),
        _stats('beter_saldo', points: 6, played: 2, gd: 6, gf: 8, ga: 2),
        _stats('meer_voor', points: 6, played: 2, gd: 6, gf: 9, ga: 3),
        _stats('minder_tegen', points: 6, played: 2, gd: 6, gf: 9, ga: 2),
      ]);

      expect(
        standings.map((team) => team['teamId']),
        [
          'minder_tegen',
          'meer_voor',
          'beter_saldo',
          'minder_gespeeld',
          'meer_gespeeld',
        ],
      );
    });

    test('periodestand gebruikt alleen wedstrijden uit de juiste periode', () {
      final periodTwo = StandingsCalculator.calculatePeriodStandings(
        division: 'A',
        period: 2,
        matches: [
          _match('A', 'acv', 'ado20', 5, 0, round: 12),
          _match('A', 'acv', 'ado20', 1, 0, round: 13),
          _match('A', 'ado20', 'acv', 1, 1, round: 23),
          _match('A', 'ado20', 'acv', 4, 0, round: 24),
        ],
      );

      expect(_team(periodTwo, 'acv')['played'], 2);
      expect(_team(periodTwo, 'acv')['points'], 4);
      expect(_team(periodTwo, 'ado20')['points'], 1);
    });

    test(
        'gewijzigde uitslag telt niet dubbel wanneer stand opnieuw berekend wordt',
        () {
      final original = StandingsCalculator.calculateDivisionStandings(
        division: 'A',
        matches: [_match('A', 'acv', 'ado20', 1, 0)],
      );
      final changed = StandingsCalculator.calculateDivisionStandings(
        division: 'A',
        matches: [_match('A', 'acv', 'ado20', 1, 2)],
      );

      expect(_team(original, 'acv')['points'], 3);
      expect(_team(original, 'ado20')['points'], 0);
      expect(_team(changed, 'acv')['played'], 1);
      expect(_team(changed, 'acv')['points'], 0);
      expect(_team(changed, 'ado20')['played'], 1);
      expect(_team(changed, 'ado20')['points'], 3);
    });
  });
}

Map<String, dynamic> _match(
  String division,
  String home,
  String away,
  int homeScore,
  int awayScore, {
  int round = 1,
}) =>
    {
      'division': division,
      'round': round,
      'homeTeamSlug': home,
      'awayTeamSlug': away,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': 'finished',
    };

Map<String, dynamic> _team(List<Map<String, dynamic>> standings, String id) {
  return standings.singleWhere((team) => team['teamId'] == id);
}

Map<String, dynamic> _stats(
  String id, {
  required int points,
  required int played,
  required int gd,
  required int gf,
  required int ga,
}) =>
    {
      'teamId': id,
      'teamName': id,
      'points': points,
      'played': played,
      'goalDifference': gd,
      'goalsFor': gf,
      'goalsAgainst': ga,
    };
