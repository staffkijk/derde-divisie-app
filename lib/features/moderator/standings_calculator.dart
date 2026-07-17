import 'package:derde_divisie/data/config/season_config.dart';

class StandingsCalculator {
  const StandingsCalculator._();

  static List<Map<String, dynamic>> calculateDivisionStandings({
    required String division,
    required Iterable<Map<String, dynamic>> matches,
  }) {
    final target = SeasonConfig.normalizeDivisionCode(division);
    final table = <String, Map<String, dynamic>>{};

    for (final team in SeasonConfig.teamsForDivision(target)) {
      table[team.id] = emptyStats(team.id, team.name, target);
    }

    for (final match in matches) {
      if (SeasonConfig.normalizeDivisionCode(
            (match['division'] ?? '').toString(),
          ) !=
          target) {
        continue;
      }
      applyMatch(table, match, target);
    }

    return sorted(table.values);
  }

  static List<Map<String, dynamic>> calculatePeriodStandings({
    required String division,
    required int period,
    required Iterable<Map<String, dynamic>> matches,
  }) {
    final target = SeasonConfig.normalizeDivisionCode(division);
    final range = periodRange(period);
    final table = <String, Map<String, dynamic>>{};

    for (final team in SeasonConfig.teamsForDivision(target)) {
      table[team.id] = {
        ...emptyStats(team.id, team.name, target),
        'period': period,
      };
    }

    for (final match in matches) {
      if (SeasonConfig.normalizeDivisionCode(
            (match['division'] ?? '').toString(),
          ) !=
          target) {
        continue;
      }
      final round = _int(match['round'] ?? match['speelronde']);
      if (round == null || round < range[0] || round > range[1]) {
        continue;
      }
      applyMatch(table, match, target);
    }

    return sorted(table.values);
  }

  static List<int> periodRange(int period) {
    if (period == 1) return const [1, 12];
    if (period == 2) return const [13, 23];
    return const [24, 34];
  }

  static void applyMatch(
    Map<String, Map<String, dynamic>> table,
    Map<String, dynamic> match,
    String division,
  ) {
    if ((match['status'] ?? '').toString() != 'finished') return;

    final homeScore = _int(match['homeScore'] ?? match['uitslagThuis']);
    final awayScore = _int(match['awayScore'] ?? match['uitslagUit']);
    if (homeScore == null || awayScore == null) return;

    final homeName = _text(
      match['homeTeamName'] ?? match['homeTeam'] ?? match['thuisteam'],
    );
    final awayName = _text(
      match['awayTeamName'] ?? match['awayTeam'] ?? match['uitteam'],
    );
    final homeId = teamId(
      match['homeTeamSlug'] ?? match['homeTeamCode'],
      homeName,
    );
    final awayId = teamId(
      match['awayTeamSlug'] ?? match['awayTeamCode'],
      awayName,
    );
    if (homeId.isEmpty || awayId.isEmpty) return;

    table.putIfAbsent(homeId, () => emptyStats(homeId, homeName, division));
    table.putIfAbsent(awayId, () => emptyStats(awayId, awayName, division));

    applyResult(table[homeId]!, homeScore, awayScore);
    applyResult(table[awayId]!, awayScore, homeScore);
  }

  static Map<String, dynamic> emptyStats(
    String id,
    String name,
    String division,
  ) =>
      {
        'teamId': id,
        'slug': id,
        'teamName': name.isEmpty ? id : name,
        'division': division,
        'played': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'goalDifference': 0,
        'points': 0,
      };

  static void applyResult(
    Map<String, dynamic> stats,
    int goalsFor,
    int goalsAgainst,
  ) {
    stats['played'] = (stats['played'] as int) + 1;
    stats['goalsFor'] = (stats['goalsFor'] as int) + goalsFor;
    stats['goalsAgainst'] = (stats['goalsAgainst'] as int) + goalsAgainst;
    stats['goalDifference'] =
        (stats['goalsFor'] as int) - (stats['goalsAgainst'] as int);
    if (goalsFor > goalsAgainst) {
      stats['wins'] = (stats['wins'] as int) + 1;
      stats['points'] = (stats['points'] as int) + 3;
    } else if (goalsFor == goalsAgainst) {
      stats['draws'] = (stats['draws'] as int) + 1;
      stats['points'] = (stats['points'] as int) + 1;
    } else {
      stats['losses'] = (stats['losses'] as int) + 1;
    }
  }

  static List<Map<String, dynamic>> sorted(
    Iterable<Map<String, dynamic>> standings,
  ) {
    return standings.toList()
      ..sort((a, b) {
        var result = _value(b, 'points').compareTo(_value(a, 'points'));
        if (result != 0) return result;
        result = _value(a, 'played').compareTo(_value(b, 'played'));
        if (result != 0) return result;
        result = _value(b, 'goalDifference').compareTo(
          _value(a, 'goalDifference'),
        );
        if (result != 0) return result;
        result = _value(b, 'goalsFor').compareTo(_value(a, 'goalsFor'));
        if (result != 0) return result;
        result = _value(a, 'goalsAgainst').compareTo(
          _value(b, 'goalsAgainst'),
        );
        if (result != 0) return result;
        return (a['teamName'] ?? '').toString().compareTo(
              (b['teamName'] ?? '').toString(),
            );
      });
  }

  static String teamId(dynamic rawId, String name) {
    final configured =
        SeasonConfig.teamById(_text(rawId)) ?? SeasonConfig.teamByName(name);
    if (configured != null) return configured.id;
    return SeasonConfig.normalizeTeamId(_text(rawId).isEmpty ? name : rawId);
  }

  static int _value(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
