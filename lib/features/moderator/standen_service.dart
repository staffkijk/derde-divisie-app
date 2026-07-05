import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class StandenService {
  Map<String, dynamic> _emptyStats(SeasonTeam team, String division) => {
        'teamId': team.id,
        'slug': team.id,
        'teamName': team.name,
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

  Future<void> herberekenStandVoorDivisie(String divisieCode) async {
    final division = SeasonConfig.normalizeDivisionCode(divisieCode);
    final matches = await SeasonPaths.currentSeasonMatches
        .where('division', isEqualTo: division)
        .get();
    final standings = <String, Map<String, dynamic>>{};

    for (final team in SeasonConfig.teamsForDivision(division)) {
      standings[team.id] = _emptyStats(team, division);
    }

    for (final doc in matches.docs) {
      final data = doc.data();
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

      standings.putIfAbsent(
        homeId,
        () => _fallbackStats(homeId, homeName, division),
      );
      standings.putIfAbsent(
        awayId,
        () => _fallbackStats(awayId, awayName, division),
      );

      _applyMatch(standings[homeId]!, homeScore, awayScore);
      _applyMatch(standings[awayId]!, awayScore, homeScore);
    }

    final existing = await SeasonPaths.currentSeasonStandings
        .where('division', isEqualTo: division)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final entry in standings.entries) {
      batch.set(
        SeasonPaths.currentSeasonStandings.doc('${division}_${entry.key}'),
        {
          ...entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
          // Tijdelijke leescompatibiliteit met bestaande stand-widgets.
          'club': entry.value['teamName'],
          'competitie': 'Derde Divisie $division',
          'gespeeld': entry.value['played'],
          'gewonnen': entry.value['wins'],
          'gelijk': entry.value['draws'],
          'verloren': entry.value['losses'],
          'doelpuntenVoor': entry.value['goalsFor'],
          'doelpuntenTegen': entry.value['goalsAgainst'],
          'doelsaldo': entry.value['goalDifference'],
          'punten': entry.value['points'],
        },
      );
    }
    await batch.commit();
  }

  Future<void> herberekenStandenVoorCompetitie(String competitieNaam) {
    return herberekenStandVoorDivisie(
      SeasonConfig.normalizeDivisionCode(competitieNaam),
    );
  }

  Map<String, dynamic> _fallbackStats(
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

  void _applyMatch(Map<String, dynamic> stats, int goalsFor, int goalsAgainst) {
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
