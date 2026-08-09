import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class DivisionDataService {
  const DivisionDataService();

  Future<DivisionData> loadDivision(String division) async {
    final target = SeasonConfig.normalizeDivisionCode(division);
    final results = await Future.wait([
      SeasonPaths.currentSeasonTeams.get(),
      SeasonPaths.currentSeasonMatches.get(),
      SeasonPaths.currentSeasonStandings.get(),
    ]);
    final teamDocs = results[0].docs;
    final allMatches = results[1].docs;
    final standingDocs = results[2].docs;
    final evidence = _divisionEvidence(allMatches);
    final officialTeams = SeasonConfig.teamsForDivision(target);
    final officialTeamIds = officialTeams.map((team) => team.id).toSet();

    final matches = allMatches
        .where((doc) => _matchBelongsToDivision(doc.data(), target, evidence))
        .map((doc) => DivisionMatch(id: doc.id, data: doc.data()))
        .toList();
    final participantIds = <String>{
      for (final match in matches) ...[
        teamIdFromMatch(match.data, home: true),
        teamIdFromMatch(match.data, home: false),
      ],
    }..removeWhere((id) => id.isEmpty);

    final teamsById = <String, DivisionTeam>{};
    for (final doc in teamDocs) {
      final data = doc.data();
      final id = _teamId(
        data['slug'] ?? data['teamId'] ?? data['id'] ?? doc.id,
        data['teamName'] ?? data['name'],
      );
      final explicit = SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['divisie'] ?? '').toString(),
      );
      final inferred = _singleEvidence(evidence[id]);
      final effective =
          inferred ?? (explicit == 'A' || explicit == 'B' ? explicit : null);
      if (effective != target || !officialTeamIds.contains(id)) continue;
      teamsById[id] = _teamFromData(id, data, target);
    }

    for (final team in officialTeams) {
      teamsById.putIfAbsent(
        team.id,
        () => DivisionTeam(
          id: team.id,
          name: team.label,
          shortName: team.listLabel,
          division: target,
          logoPath: team.logoPath,
        ),
      );
    }

    for (final id in participantIds) {
      final inferred = _singleEvidence(evidence[id]);
      if (inferred != target || !officialTeamIds.contains(id)) continue;
      teamsById.putIfAbsent(id, () => _teamFromId(id, target));
    }

    final standings = _dedupeStandings(
      standingDocs
          .where((doc) {
            final data = doc.data();
            final id = _teamId(
              data['teamId'] ?? data['slug'] ?? doc.id,
              data['teamName'] ?? data['club'],
            );
            final explicit = SeasonConfig.normalizeDivisionCode(
              (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '')
                  .toString(),
            );
            final inferred = _singleEvidence(evidence[id]);
            final belongs =
                inferred == target || (inferred == null && explicit == target);
            return belongs && teamsById.containsKey(id);
          })
          .map((doc) => DivisionStanding(id: doc.id, data: doc.data()))
          .toList(),
    )..sort(compareStandings);

    final orderedTeams = <DivisionTeam>[];
    for (final standing in standings) {
      final id = _teamId(
        standing.data['teamId'] ?? standing.data['slug'] ?? standing.id,
        standing.data['teamName'] ?? standing.data['club'],
      );
      final team = teamsById[id];
      if (team != null &&
          !orderedTeams.any((candidate) => candidate.id == team.id)) {
        orderedTeams.add(team);
      }
    }
    final remaining = teamsById.values
        .where(
          (team) => !orderedTeams.any((candidate) => candidate.id == team.id),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    orderedTeams.addAll(remaining);

    return DivisionData(
      division: target,
      teams: orderedTeams,
      matches: matches,
      standings: standings,
    );
  }

  Future<ClubDivisionData> loadClub({
    required String teamSlug,
    required String teamName,
  }) async {
    final results = await Future.wait([
      SeasonPaths.currentSeasonTeams.get(),
      SeasonPaths.currentSeasonMatches.get(),
      SeasonPaths.currentSeasonStandings.get(),
    ]);
    final teamDocs = results[0].docs;
    final allMatches = results[1].docs;
    final allStandings = results[2].docs;
    final requestedId = _teamId(teamSlug, teamName);
    final evidence = _divisionEvidence(allMatches);

    Map<String, dynamic>? teamData;
    for (final doc in teamDocs) {
      final data = doc.data();
      final id = _teamId(
        data['slug'] ?? data['teamId'] ?? data['id'] ?? doc.id,
        data['teamName'] ?? data['name'],
      );
      if (id == requestedId) {
        teamData = data;
        break;
      }
    }
    final matchDivision = _singleEvidence(evidence[requestedId]);
    final teamDivision = SeasonConfig.normalizeDivisionCode(
      (teamData?['division'] ?? teamData?['divisie'] ?? '').toString(),
    );
    final standingDivisions = allStandings
        .where((doc) {
          final data = doc.data();
          return _teamId(
                data['teamId'] ?? data['slug'] ?? doc.id,
                data['teamName'] ?? data['club'],
              ) ==
              requestedId;
        })
        .map(
          (doc) => SeasonConfig.normalizeDivisionCode(
            (doc.data()['division'] ??
                    doc.data()['divisie'] ??
                    doc.data()['competitie'] ??
                    '')
                .toString(),
          ),
        )
        .where((value) => value == 'A' || value == 'B')
        .toSet();
    final division = matchDivision ??
        (teamDivision == 'A' || teamDivision == 'B' ? teamDivision : null) ??
        (standingDivisions.length == 1 ? standingDivisions.first : null);

    final matches = allMatches
        .where((doc) {
          final data = doc.data();
          final involves = teamIdFromMatch(data, home: true) == requestedId ||
              teamIdFromMatch(data, home: false) == requestedId;
          if (!involves) return false;
          if (division == null) return true;
          return matchBelongsToDivision(data, division);
        })
        .map((doc) => DivisionMatch(id: doc.id, data: doc.data()))
        .toList();

    final divisionStandings = division == null
        ? <DivisionStanding>[]
        : standingsForDivision(
            allStandings
                .map((doc) => DivisionStanding(id: doc.id, data: doc.data()))
                .toList(),
            division,
          );
    DivisionStanding? standing;
    var position = 0;
    for (var index = 0; index < divisionStandings.length; index++) {
      final item = divisionStandings[index];
      if (_teamId(
            item.data['teamId'] ?? item.data['slug'] ?? item.id,
            item.data['teamName'] ?? item.data['club'],
          ) ==
          requestedId) {
        standing = item;
        position = index + 1;
        break;
      }
    }
    final team = teamData == null
        ? _teamFromId(requestedId, division ?? '')
        : _teamFromData(requestedId, teamData, division ?? '');
    return ClubDivisionData(
      team: team,
      division: division,
      matches: matches,
      standing: standing,
      position: position,
      divisionTeamCount: divisionStandings.length,
    );
  }

  static int compareStandings(DivisionStanding a, DivisionStanding b) {
    int value(Map<String, dynamic> data, String key, String fallback) {
      final raw = data[key] ?? data[fallback];
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    var result = value(b.data, 'points', 'punten')
        .compareTo(value(a.data, 'points', 'punten'));
    if (result != 0) return result;
    result = value(b.data, 'goalDifference', 'doelsaldo')
        .compareTo(value(a.data, 'goalDifference', 'doelsaldo'));
    if (result != 0) return result;
    result = value(b.data, 'goalsFor', 'doelpuntenVoor')
        .compareTo(value(a.data, 'goalsFor', 'doelpuntenVoor'));
    if (result != 0) return result;
    return (a.data['teamName'] ?? a.data['club'] ?? '').toString().compareTo(
          (b.data['teamName'] ?? b.data['club'] ?? '').toString(),
        );
  }

  /// Filters, deduplicates and sorts a raw standings set for one official
  /// 18-club division.
  static List<DivisionStanding> standingsForDivision(
    List<DivisionStanding> source,
    String division,
  ) {
    final target = SeasonConfig.normalizeDivisionCode(division);
    final officialIds = SeasonConfig.teamsForDivision(
      target,
    ).map((team) => team.id).toSet();
    final filtered = source.where((standing) {
      final data = standing.data;
      final standingDivision = SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '')
            .toString(),
      );
      final id = _teamId(
        data['teamId'] ?? data['slug'] ?? standing.id,
        data['teamName'] ?? data['club'],
      );
      return standingDivision == target && officialIds.contains(id);
    }).toList();
    return _dedupeStandings(filtered)..sort(compareStandings);
  }

  static List<DivisionStanding> _dedupeStandings(
    List<DivisionStanding> source,
  ) {
    final byTeam = <String, DivisionStanding>{};
    for (final standing in source) {
      final id = _teamId(
        standing.data['teamId'] ?? standing.data['slug'] ?? standing.id,
        standing.data['teamName'] ?? standing.data['club'],
      );
      if (id.isEmpty) continue;
      final current = byTeam[id];
      if (current == null || _played(standing.data) >= _played(current.data)) {
        byTeam[id] = standing;
      }
    }
    return byTeam.values.toList();
  }

  static int _played(Map<String, dynamic> data) {
    final value = data['played'] ?? data['gespeeld'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String teamIdFromMatch(
    Map<String, dynamic> data, {
    required bool home,
  }) {
    final teamSlugs = data['teamSlugs'];
    final nestedSlug =
        teamSlugs is Map ? teamSlugs[home ? 'home' : 'away'] : null;
    return _teamId(
      home
          ? data['homeTeamSlug'] ??
              data['homeTeamCode'] ??
              data['homeSlug'] ??
              nestedSlug
          : data['awayTeamSlug'] ??
              data['awayTeamCode'] ??
              data['awaySlug'] ??
              nestedSlug,
      home
          ? data['homeTeamName'] ??
              data['homeTeam'] ??
              data['thuisteam'] ??
              data['home']
          : data['awayTeamName'] ??
              data['awayTeam'] ??
              data['uitteam'] ??
              data['away'],
    );
  }

  static Map<String, Set<String>> _divisionEvidence(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> matches,
  ) {
    final evidence = <String, Set<String>>{};
    for (final doc in matches) {
      final data = doc.data();
      final division = SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '')
            .toString(),
      );
      if (division != 'A' && division != 'B') continue;
      for (final id in [
        teamIdFromMatch(data, home: true),
        teamIdFromMatch(data, home: false),
      ]) {
        if (id.isEmpty) continue;
        evidence.putIfAbsent(id, () => <String>{}).add(division);
      }
    }
    return evidence;
  }

  static bool _matchBelongsToDivision(
    Map<String, dynamic> data,
    String target,
    Map<String, Set<String>> evidence,
  ) {
    if (!matchBelongsToDivision(data, target)) return false;
    final homeEvidence = _singleEvidence(
      evidence[teamIdFromMatch(data, home: true)],
    );
    final awayEvidence = _singleEvidence(
      evidence[teamIdFromMatch(data, home: false)],
    );
    return (homeEvidence == null || homeEvidence == target) &&
        (awayEvidence == null || awayEvidence == target);
  }

  /// Pure guard used by every divisiescherm and by regression tests.
  static bool matchBelongsToDivision(
    Map<String, dynamic> data,
    String division,
  ) {
    final target = SeasonConfig.normalizeDivisionCode(division);
    final explicit = SeasonConfig.normalizeDivisionCode(
      (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '')
          .toString(),
    );
    final hasExplicitDivision = explicit == 'A' || explicit == 'B';
    if (hasExplicitDivision && explicit != target) return false;
    final homeField = SeasonConfig.normalizeDivisionCode(
      (data['homeTeamDivision'] ?? '').toString(),
    );
    final awayField = SeasonConfig.normalizeDivisionCode(
      (data['awayTeamDivision'] ?? '').toString(),
    );
    if ((homeField == 'A' || homeField == 'B') && homeField != target) {
      return false;
    }
    if ((awayField == 'A' || awayField == 'B') && awayField != target) {
      return false;
    }
    final homeTeam = SeasonConfig.teamById(
      teamIdFromMatch(data, home: true),
    );
    final awayTeam = SeasonConfig.teamById(
      teamIdFromMatch(data, home: false),
    );
    if (!hasExplicitDivision) {
      return homeTeam != null &&
          awayTeam != null &&
          homeTeam.division == target &&
          awayTeam.division == target;
    }
    return (homeTeam == null || homeTeam.division == target) &&
        (awayTeam == null || awayTeam.division == target);
  }

  static String? _singleEvidence(Set<String>? values) {
    return values != null && values.length == 1 ? values.first : null;
  }

  static String _teamId(dynamic rawId, dynamic rawName) {
    final id = rawId?.toString() ?? '';
    final name = rawName?.toString() ?? '';
    final configured =
        SeasonConfig.teamById(id) ?? SeasonConfig.teamByName(name);
    return configured?.id ??
        SeasonConfig.normalizeTeamId(id.isNotEmpty ? id : name);
  }

  static DivisionTeam _teamFromData(
    String id,
    Map<String, dynamic> data,
    String division,
  ) {
    final configured = SeasonConfig.teamById(id) ??
        SeasonConfig.teamByName(
          (data['teamName'] ?? data['name'] ?? '').toString(),
        );
    final name = (data['displayName'] ??
            data['teamName'] ??
            data['name'] ??
            configured?.label ??
            id)
        .toString();
    return DivisionTeam(
      id: id,
      name: name,
      shortName:
          (data['shortName'] ?? configured?.listLabel ?? name).toString(),
      division: division,
      logoPath: (data['logoPath'] ??
              configured?.logoPath ??
              SeasonConfig.defaultTeamLogoPath)
          .toString(),
    );
  }

  static DivisionTeam _teamFromId(String id, String division) {
    final configured = SeasonConfig.teamById(id);
    return DivisionTeam(
      id: id,
      name: configured?.label ?? id,
      shortName: configured?.listLabel ?? configured?.label ?? id,
      division: division,
      logoPath: configured?.logoPath ?? SeasonConfig.defaultTeamLogoPath,
    );
  }
}

class DivisionData {
  const DivisionData({
    required this.division,
    required this.teams,
    required this.matches,
    required this.standings,
  });

  final String division;
  final List<DivisionTeam> teams;
  final List<DivisionMatch> matches;
  final List<DivisionStanding> standings;
}

class ClubDivisionData {
  const ClubDivisionData({
    required this.team,
    required this.division,
    required this.matches,
    required this.standing,
    required this.position,
    required this.divisionTeamCount,
  });

  final DivisionTeam team;
  final String? division;
  final List<DivisionMatch> matches;
  final DivisionStanding? standing;
  final int position;
  final int divisionTeamCount;
}

class DivisionTeam {
  const DivisionTeam({
    required this.id,
    required this.name,
    required this.shortName,
    required this.division,
    required this.logoPath,
  });

  final String id;
  final String name;
  final String shortName;
  final String division;
  final String logoPath;

  String get label => name;
}

class DivisionMatch {
  const DivisionMatch({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class DivisionStanding {
  const DivisionStanding({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
