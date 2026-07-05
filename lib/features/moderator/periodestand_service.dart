import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class PeriodestandService {
  Future<void> herberekenAllePeriodesVoorDivisie(String divisieCode) async {
    final division = SeasonConfig.normalizeDivisionCode(divisieCode);
    final snapshot = await SeasonPaths.currentSeasonMatches
        .where('division', isEqualTo: division)
        .get();

    for (var period = 1; period <= 3; period++) {
      await _recalculate(division, period, snapshot.docs);
    }
  }

  Future<void> _recalculate(
    String division,
    int period,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> matches,
  ) async {
    final range = _periodRange(period);
    final table = <String, Map<String, dynamic>>{};

    for (final team in SeasonConfig.teamsForDivision(division)) {
      table[team.id] = _empty(team.id, team.name, division, period);
    }

    for (final doc in matches) {
      final data = doc.data();
      final round = _int(data['round'] ?? data['speelronde']);
      if (round == null || round < range[0] || round > range[1]) continue;
      if ((data['status'] ?? '').toString() != 'finished') continue;

      final homeScore = _int(data['homeScore'] ?? data['uitslagThuis']);
      final awayScore = _int(data['awayScore'] ?? data['uitslagUit']);
      if (homeScore == null || awayScore == null) continue;

      final homeName = _text(
        data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam'],
      );
      final awayName = _text(
        data['awayTeamName'] ?? data['awayTeam'] ?? data['uitteam'],
      );
      final homeId = _teamId(
        data['homeTeamSlug'] ?? data['homeTeamCode'],
        homeName,
      );
      final awayId = _teamId(
        data['awayTeamSlug'] ?? data['awayTeamCode'],
        awayName,
      );
      if (homeId.isEmpty || awayId.isEmpty) continue;

      table.putIfAbsent(
        homeId,
        () => _empty(homeId, homeName, division, period),
      );
      table.putIfAbsent(
        awayId,
        () => _empty(awayId, awayName, division, period),
      );
      _apply(table[homeId]!, homeScore, awayScore);
      _apply(table[awayId]!, awayScore, homeScore);
    }

    final sorted = table.entries.toList()
      ..sort((a, b) {
        var result =
            (b.value['points'] as int).compareTo(a.value['points'] as int);
        if (result != 0) return result;
        result = (b.value['goalDifference'] as int)
            .compareTo(a.value['goalDifference'] as int);
        if (result != 0) return result;
        result =
            (b.value['goalsFor'] as int).compareTo(a.value['goalsFor'] as int);
        if (result != 0) return result;
        return (a.value['teamName'] as String)
            .compareTo(b.value['teamName'] as String);
      });

    final prefix = '${division}_P${period}_';
    final existing = await SeasonPaths.currentSeasonPeriodStandings
        .where('division', isEqualTo: division)
        .where('period', isEqualTo: period)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var index = 0; index < sorted.length; index++) {
      final entry = sorted[index];
      final data = entry.value;
      batch.set(
        SeasonPaths.currentSeasonPeriodStandings.doc('$prefix${entry.key}'),
        {
          ...data,
          'position': index + 1,
          'updatedAt': FieldValue.serverTimestamp(),
          // Compatibiliteit voor de bestaande periodestand-widget.
          'club': data['teamName'],
          'positie': index + 1,
          'gespeeld': data['played'],
          'gewonnen': data['wins'],
          'gelijk': data['draws'],
          'verloren': data['losses'],
          'doelpuntenVoor': data['goalsFor'],
          'doelpuntenTegen': data['goalsAgainst'],
          'doelsaldo': data['goalDifference'],
          'punten': data['points'],
        },
      );
    }
    await batch.commit();
  }

  List<int> _periodRange(int period) {
    if (period == 1) return const [1, 12];
    if (period == 2) return const [13, 23];
    return const [24, 34];
  }

  Map<String, dynamic> _empty(
    String id,
    String name,
    String division,
    int period,
  ) =>
      {
        'teamId': id,
        'slug': id,
        'teamName': name.isEmpty ? id : name,
        'division': division,
        'period': period,
        'played': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'goalDifference': 0,
        'points': 0,
      };

  void _apply(Map<String, dynamic> stats, int goalsFor, int goalsAgainst) {
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

  String _teamId(dynamic rawId, String name) {
    final configured =
        SeasonConfig.teamById(_text(rawId)) ?? SeasonConfig.teamByName(name);
    if (configured != null) return configured.id;
    return SeasonConfig.normalizeTeamKey(_text(rawId).isEmpty ? name : rawId);
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
