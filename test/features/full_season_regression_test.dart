import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/moderator/standings_calculator.dart';

void main() {
  group('Volledig seizoen regressie', () {
    for (final division in [SeasonConfig.divisionA, SeasonConfig.divisionB]) {
      test('simuleert alle 306 wedstrijden van Divisie $division correct', () {
        final teams = SeasonConfig.teamsForDivision(division);
        expect(teams, hasLength(18));

        final matches = _doubleRoundRobin(division, teams);
        expect(matches, hasLength(306));
        expect(matches.where((m) => m['division'] == division), hasLength(306));

        final standings = StandingsCalculator.calculateDivisionStandings(
          division: division,
          matches: matches,
        );

        expect(standings, hasLength(18));
        expect(
          standings.fold<int>(0, (sum, row) => sum + row['played'] as int),
          612,
          reason: '306 wedstrijden moeten samen 612 team-wedstrijden opleveren',
        );
        expect(
          standings.every((row) => row['played'] == 34),
          isTrue,
          reason: 'iedere club moet in een volledige competitie 34 keer spelen',
        );
        expect(
          standings.fold<int>(0, (sum, row) => sum + row['goalsFor'] as int),
          standings.fold<int>(0, (sum, row) => sum + row['goalsAgainst'] as int),
          reason: 'alle gemaakte goals moeten exact gelijk zijn aan alle tegengoals',
        );

        final pairCounts = <String, int>{};
        for (final match in matches) {
          final home = match['homeTeamSlug'] as String;
          final away = match['awayTeamSlug'] as String;
          final pair = [home, away]..sort();
          final key = '${pair[0]}::${pair[1]}';
          pairCounts[key] = (pairCounts[key] ?? 0) + 1;
        }
        expect(pairCounts, hasLength(153));
        expect(pairCounts.values.every((count) => count == 2), isTrue);
      });

      test('scorewijziging in Divisie $division telt nooit dubbel', () {
        final teams = SeasonConfig.teamsForDivision(division);
        final matches = _doubleRoundRobin(division, teams);
        final target = Map<String, dynamic>.from(matches.first);
        final homeId = target['homeTeamSlug'] as String;
        final awayId = target['awayTeamSlug'] as String;

        final original = StandingsCalculator.calculateDivisionStandings(
          division: division,
          matches: matches,
        );

        final changedMatches = matches
            .map((match) => Map<String, dynamic>.from(match))
            .toList();
        changedMatches[0]
          ..['homeScore'] = 0
          ..['awayScore'] = 5;

        final changed = StandingsCalculator.calculateDivisionStandings(
          division: division,
          matches: changedMatches,
        );

        final changedHome = _team(changed, homeId);
        final changedAway = _team(changed, awayId);
        expect(changedHome['played'], 34);
        expect(changedAway['played'], 34);

        final fresh = StandingsCalculator.calculateDivisionStandings(
          division: division,
          matches: changedMatches.reversed,
        );
        expect(_normalized(changed), _normalized(fresh));
        expect(_normalized(changed), isNot(_normalized(original)));
      });

      test('finished naar scheduled verwijdert exact één wedstrijd in Divisie $division', () {
        final teams = SeasonConfig.teamsForDivision(division);
        final matches = _doubleRoundRobin(division, teams)
            .map((match) => Map<String, dynamic>.from(match))
            .toList();
        final target = matches.first;
        final homeId = target['homeTeamSlug'] as String;
        final awayId = target['awayTeamSlug'] as String;
        target['status'] = 'scheduled';

        final standings = StandingsCalculator.calculateDivisionStandings(
          division: division,
          matches: matches,
        );

        expect(_team(standings, homeId)['played'], 33);
        expect(_team(standings, awayId)['played'], 33);
        expect(
          standings
              .where((row) => row['teamId'] != homeId && row['teamId'] != awayId)
              .every((row) => row['played'] == 34),
          isTrue,
        );
      });

      test('periodes 1, 2 en 3 dekken samen alle 34 speelrondes in Divisie $division', () {
        final teams = SeasonConfig.teamsForDivision(division);
        final matches = _doubleRoundRobin(division, teams);
        final playedTotals = <String, int>{for (final team in teams) team.id: 0};

        for (var period = 1; period <= 3; period++) {
          final periodStandings = StandingsCalculator.calculatePeriodStandings(
            division: division,
            period: period,
            matches: matches,
          );
          for (final row in periodStandings) {
            playedTotals[row['teamId'] as String] =
                playedTotals[row['teamId'] as String]! + row['played'] as int;
          }
        }

        expect(playedTotals.values.every((played) => played == 34), isTrue);
      });
    }
  });
}

List<Map<String, dynamic>> _doubleRoundRobin(
  String division,
  List<SeasonTeam> teams,
) {
  final rotating = teams.toList();
  final rounds = <Map<String, dynamic>>[];
  var matchIndex = 0;

  for (var round = 1; round <= 17; round++) {
    for (var i = 0; i < rotating.length ~/ 2; i++) {
      final left = rotating[i];
      final right = rotating[rotating.length - 1 - i];
      final swap = (round + i).isEven;
      final home = swap ? right : left;
      final away = swap ? left : right;
      rounds.add(_match(division, round, matchIndex++, home, away));
    }

    final fixed = rotating.first;
    final tail = rotating.sublist(1);
    tail.insert(0, tail.removeLast());
    rotating
      ..clear()
      ..add(fixed)
      ..addAll(tail);
  }

  final firstHalf = rounds.toList();
  for (final first in firstHalf) {
    final round = first['round'] as int;
    final home = teams.singleWhere((team) => team.id == first['homeTeamSlug']);
    final away = teams.singleWhere((team) => team.id == first['awayTeamSlug']);
    rounds.add(_match(division, round + 17, matchIndex++, away, home));
  }

  return rounds;
}

Map<String, dynamic> _match(
  String division,
  int round,
  int index,
  SeasonTeam home,
  SeasonTeam away,
) {
  final homeScore = (index * 3 + round) % 5;
  final awayScore = (index * 2 + round + 1) % 4;
  return {
    'division': division,
    'round': round,
    'homeTeamSlug': home.id,
    'awayTeamSlug': away.id,
    'homeTeamName': home.name,
    'awayTeamName': away.name,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'status': 'finished',
  };
}

Map<String, dynamic> _team(List<Map<String, dynamic>> standings, String id) {
  return standings.singleWhere((row) => row['teamId'] == id);
}

List<Map<String, dynamic>> _normalized(List<Map<String, dynamic>> standings) {
  return standings
      .map((row) => Map<String, dynamic>.fromEntries(
            row.entries.where((entry) => entry.key != 'position'),
          ))
      .toList();
}
