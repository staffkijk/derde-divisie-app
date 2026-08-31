import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';
import 'package:derde_divisie/features/voorspellen/user_display_name.dart';

enum SocialCardMode { program, results, predictions }

class SocialCardData {
  const SocialCardData({
    required this.matches,
    required this.standings,
    required this.predictionSummary,
    this.formByTeam = const {},
    this.predictionPeriodComplete = true,
  });
  final List<SocialCardMatch> matches;
  final List<SocialStanding> standings;
  final PredictionSummary predictionSummary;
  final Map<String, List<SocialFormResult>> formByTeam;
  final bool predictionPeriodComplete;
}

enum SocialFormResult { win, draw, loss }

class PredictionSocialPeriod {
  const PredictionSocialPeriod(this.startRound, this.endRound);
  final int startRound;
  final int endRound;
  String get label => 'Na speelronde $endRound';
  String get rangeLabel => 'Speelronde $startRound t/m $endRound';
  static const periods = [
    PredictionSocialPeriod(1, 5),
    PredictionSocialPeriod(6, 10),
    PredictionSocialPeriod(11, 15),
    PredictionSocialPeriod(16, 20),
    PredictionSocialPeriod(21, 25),
    PredictionSocialPeriod(26, 30),
    PredictionSocialPeriod(31, 34),
  ];
  static List<int> get publicationRounds =>
      periods.map((period) => period.endRound).toList(growable: false);
  static PredictionSocialPeriod forRound(int round) => periods.firstWhere(
        (period) => round <= period.endRound,
        orElse: () => periods.last,
      );
}

class RankingUser {
  const RankingUser(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class PredictionRankEntry {
  const PredictionRankEntry(this.userId, this.name, this.score);
  final String userId;
  final String name;
  final int score;
}

class PredictionSummary {
  const PredictionSummary({
    this.periodWinners = const [],
    this.globalTop = const [],
  });
  final List<PredictionRankEntry> periodWinners;
  final List<PredictionRankEntry> globalTop;
}

PredictionSummary buildPredictionSummary({
  required List<RankingUser> users,
  required List<Map<String, dynamic>> predictions,
  required Map<String, String> periodMatchDivisions,
  required Map<String, String> throughMatchDivisions,
}) {
  final byId = {for (final user in users) user.id: user};
  final periodScoresA = <String, int>{};
  final periodScoresB = <String, int>{};
  final scoresA = <String, int>{};
  final scoresB = <String, int>{};
  for (final prediction in predictions) {
    final matchId =
        (prediction['wedstrijdId'] ?? prediction['matchId'] ?? '').toString();
    final uid = (prediction['gebruikerId'] ??
            prediction['userId'] ??
            prediction['uid'] ??
            '')
        .toString();
    if (uid.isEmpty) continue;
    final points = rankingInt(prediction['punten']);
    final periodDivision = periodMatchDivisions[matchId];
    if (periodDivision == 'A') {
      periodScoresA.update(uid, (old) => old + points, ifAbsent: () => points);
    } else if (periodDivision == 'B') {
      periodScoresB.update(uid, (old) => old + points, ifAbsent: () => points);
    }
    final division = throughMatchDivisions[matchId];
    if (division == 'A') {
      scoresA.update(uid, (old) => old + points, ifAbsent: () => points);
    } else if (division == 'B') {
      scoresB.update(uid, (old) => old + points, ifAbsent: () => points);
    }
  }
  final periodUserIds = {...periodScoresA.keys, ...periodScoresB.keys};
  final periodScores = {
    for (final uid in periodUserIds)
      uid: rankingScore({
        'punten_A': periodScoresA[uid] ?? 0,
        'punten_B': periodScoresB[uid] ?? 0,
      }, RankingType.global),
  };
  final best = periodScores.values
      .fold<int>(0, (old, score) => score > old ? score : old);
  final winners = periodScores.entries
      .where((entry) => best > 0 && entry.value == best)
      .map((entry) => PredictionRankEntry(
            entry.key,
            byId[entry.key] == null
                ? 'Onbekende gebruiker'
                : resolveUserDisplayName(byId[entry.key]!.data),
            entry.value,
          ))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final historicalUsers = users.map((user) => RankingUser(user.id, {
        ...user.data,
        'punten_A': scoresA[user.id] ?? 0,
        'punten_B': scoresB[user.id] ?? 0,
      }));
  final sorted = sortRanking<RankingUser>(
    historicalUsers,
    type: RankingType.global,
    dataOf: (user) => user.data,
    idOf: (user) => user.id,
  );
  return PredictionSummary(
    periodWinners: winners,
    globalTop: sorted
        .take(5)
        .map((user) => PredictionRankEntry(
              user.id,
              resolveUserDisplayName(user.data),
              rankingScore(user.data, RankingType.global),
            ))
        .toList(),
  );
}

bool predictionPeriodIsComplete(
  Iterable<SocialCardMatch> matches,
  PredictionSocialPeriod period,
) {
  final relevant = matches.where((match) =>
      match.round >= period.startRound && match.round <= period.endRound);
  if (relevant.isEmpty) {
    return false;
  }
  final rounds = relevant.map((match) => match.round).toSet();
  for (var round = period.startRound; round <= period.endRound; round++) {
    if (!rounds.contains(round)) {
      return false;
    }
  }
  return relevant.every((match) =>
      match.status == MatchStatus.finished &&
      (match.data['processed'] == true || match.data['verwerkt'] == true));
}

String canonicalSocialTeamKey(
  String value, {
  required String division,
  String? teamId,
}) {
  final normalizedDivision = SeasonConfig.normalizeDivisionCode(division);
  final byId = teamId == null ? null : SeasonConfig.teamById(teamId);
  if (byId != null && byId.division == normalizedDivision) {
    return '$normalizedDivision:${byId.id}';
  }
  final team = SeasonConfig.teamByName(value);
  if (team != null && team.division == normalizedDivision) {
    return '$normalizedDivision:${team.id}';
  }
  return '$normalizedDivision:${SeasonConfig.normalizeTeamKey(value)}';
}

bool _socialMatchCanCountForForm(SocialCardMatch match) {
  if (match.homeScore == null || match.awayScore == null) return false;
  switch (match.status) {
    case MatchStatus.postponed:
    case MatchStatus.cancelled:
    case MatchStatus.abandoned:
      return false;
    case MatchStatus.scheduled:
    case MatchStatus.finished:
      return true;
  }
}

Map<String, List<SocialFormResult>> buildSocialForm({
  required Iterable<SocialStanding> standings,
  required Iterable<SocialCardMatch> matches,
  int limit = 5,
}) {
  final result = <String, List<SocialFormResult>>{};
  for (final standing in standings) {
    final key = canonicalSocialTeamKey(
      standing.name,
      division: standing.division,
      teamId: standing.teamId,
    );
    final teamMatches = matches.where((match) {
      if (match.division != standing.division ||
          !_socialMatchCanCountForForm(match)) {
        return false;
      }
      return canonicalSocialTeamKey(
                match.homeTeam,
                division: match.division,
                teamId: match.homeTeamId,
              ) ==
              key ||
          canonicalSocialTeamKey(
                match.awayTeam,
                division: match.division,
                teamId: match.awayTeamId,
              ) ==
              key;
    }).toList()
      ..sort(SocialCardMatch.compare);
    result[key] =
        teamMatches.reversed.take(limit).toList().reversed.map((match) {
      final home = canonicalSocialTeamKey(
            match.homeTeam,
            division: match.division,
            teamId: match.homeTeamId,
          ) ==
          key;
      final own = home ? match.homeScore! : match.awayScore!;
      final other = home ? match.awayScore! : match.homeScore!;
      if (own > other) return SocialFormResult.win;
      if (own < other) return SocialFormResult.loss;
      return SocialFormResult.draw;
    }).toList();
  }
  return result;
}

int currentProgramRound(Iterable<SocialCardMatch> matches) {
  final rounds =
      matches.map((match) => match.round).where((round) => round > 0);
  if (rounds.isEmpty) return 1;
  final highest = rounds.reduce((a, b) => a > b ? a : b);
  for (var round = 1; round <= highest; round++) {
    final inRound = matches.where((match) => match.round == round);
    if (inRound.any((match) =>
        match.status == MatchStatus.scheduled ||
        match.status == MatchStatus.postponed)) {
      return round;
    }
  }
  return highest;
}

int currentResultsRound(Iterable<SocialCardMatch> matches) {
  final playedRounds = matches
      .where((match) =>
          match.homeScore != null &&
          match.awayScore != null &&
          match.status != MatchStatus.cancelled &&
          match.status != MatchStatus.abandoned &&
          match.status != MatchStatus.postponed)
      .map((match) => match.round)
      .where((round) => round > 0);
  if (playedRounds.isEmpty) return currentProgramRound(matches);
  return playedRounds.reduce((a, b) => a > b ? a : b);
}

List<int> socialRoundChoices(SocialCardMode mode) =>
    mode == SocialCardMode.predictions
        ? PredictionSocialPeriod.publicationRounds
        : List.generate(34, (index) => index + 1);

String predictionSocialText(
  PredictionSummary summary,
  int round, {
  bool compact = false,
}) {
  final period = PredictionSocialPeriod.forRound(round);
  final winner = summary.periodWinners.isEmpty
      ? 'Nog geen periodewinnaar'
      : summary.periodWinners
          .map((entry) => '${entry.name} - ${entry.score} punten')
          .join('\n');
  final top = summary.globalTop
      .asMap()
      .entries
      .map((entry) =>
          '${entry.key + 1}. ${entry.value.name} - ${entry.value.score}')
      .join('\n');
  return 'Voorspelpoule na speelronde $round 🏆\n\n'
      'Periodewinnaar speelronde ${period.startRound} t/m ${period.endRound}:\n$winner\n\n'
      '${compact ? '' : 'Top 5 algemeen:\n$top\n\n'}'
      'Volledige ranglijst: derdediv.nl';
}

List<SocialCardMatch> filterSocialMatches(
  Iterable<SocialCardMatch> matches, {
  required String division,
  required int round,
}) {
  return matches
      .where((match) => match.division == division && match.round == round)
      .toList()
    ..sort(SocialCardMatch.compare);
}

Map<DateTime, List<SocialCardMatch>> groupSocialMatchesByDate(
  Iterable<SocialCardMatch> matches,
) {
  final groups = <DateTime, List<SocialCardMatch>>{};
  for (final match in matches) {
    final value = match.dateTime;
    if (value == null) continue;
    final date = DateTime(value.year, value.month, value.day);
    groups.putIfAbsent(date, () => []).add(match);
  }
  for (final group in groups.values) {
    group.sort(SocialCardMatch.compare);
  }
  return Map.fromEntries(
    groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

String socialDateHeader(DateTime date) {
  const weekdays = ['MA', 'DI', 'WO', 'DO', 'VR', 'ZA', 'ZO'];
  const months = [
    'JAN',
    'FEB',
    'MRT',
    'APR',
    'MEI',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OKT',
    'NOV',
    'DEC',
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

String socialFileName(SocialCardMode mode, String division, int round) {
  switch (mode) {
    case SocialCardMode.program:
      return 'derdediv_programma_${division}_speelronde_$round.png';
    case SocialCardMode.results:
      return 'derdediv_uitslagen_${division}_speelronde_$round.png';
    case SocialCardMode.predictions:
      return 'derdediv_voorspelpoule_speelronde_$round.png';
  }
}

class SocialStanding {
  const SocialStanding({
    required this.division,
    required this.name,
    required this.position,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    this.teamId,
  });
  final String division;
  final String name;
  final int position;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
  final String? teamId;

  factory SocialStanding.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final goalsFor =
        rankingInt(data['goalsFor'] ?? data['doelpuntenVoor'] ?? data['dv']);
    final goalsAgainst = rankingInt(
      data['goalsAgainst'] ?? data['doelpuntenTegen'] ?? data['dt'],
    );
    return SocialStanding(
      division: SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['competitie'] ?? '').toString(),
      ),
      name: (data['teamName'] ??
              data['name'] ??
              data['team'] ??
              data['club'] ??
              doc.id)
          .toString(),
      position: rankingInt(data['position'] ?? data['positie'] ?? data['rank']),
      played: rankingInt(data['played'] ?? data['gespeeld']),
      wins: rankingInt(data['wins'] ?? data['won'] ?? data['gewonnen']),
      draws: rankingInt(data['draws'] ?? data['drawn'] ?? data['gelijk']),
      losses: rankingInt(data['losses'] ?? data['lost'] ?? data['verloren']),
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      goalDifference: rankingInt(
        data['goalDifference'] ?? data['doelsaldo'] ?? goalsFor - goalsAgainst,
      ),
      points: rankingInt(data['points'] ?? data['punten']),
      teamId: (data['teamId'] ?? data['clubId'])?.toString(),
    );
  }

  static int compare(SocialStanding a, SocialStanding b) {
    if (a.position > 0 && b.position > 0) {
      return a.position.compareTo(b.position);
    }
    var result = b.points.compareTo(a.points);
    if (result != 0) return result;
    result = b.goalDifference.compareTo(a.goalDifference);
    if (result != 0) return result;
    result = b.goalsFor.compareTo(a.goalsFor);
    if (result != 0) return result;
    return a.name.compareTo(b.name);
  }
}

class SocialCardMatch {
  const SocialCardMatch({
    required this.id,
    required this.division,
    required this.round,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffTime,
    required this.status,
    required this.data,
    this.dateTime,
    this.homeScore,
    this.awayScore,
    this.homeTeamId,
    this.awayTeamId,
  });
  final String id;
  final String division;
  final int round;
  final String homeTeam;
  final String awayTeam;
  final String kickoffTime;
  final MatchStatus status;
  final Map<String, dynamic> data;
  final DateTime? dateTime;
  final int? homeScore;
  final int? awayScore;
  final String? homeTeamId;
  final String? awayTeamId;

  factory SocialCardMatch.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    int? nullableInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    String readableTeamValue(Object? value) {
      if (value == null) return '';
      if (value is DocumentReference) return value.id.trim();
      if (value is Map) {
        for (final key in const [
          'name',
          'teamName',
          'displayName',
          'id',
          'teamId',
          'clubId',
          'code',
        ]) {
          final candidate = value[key];
          if (candidate != null && candidate.toString().trim().isNotEmpty) {
            return candidate.toString().trim();
          }
        }
        return '';
      }
      return value.toString().trim();
    }

    String firstTeamValue(List<Object?> values) {
      for (final value in values) {
        final candidate = readableTeamValue(value);
        if (candidate.isNotEmpty) return candidate;
      }
      return '';
    }

    final homeScore = nullableInt(
      data['homeScore'] ?? data['uitslagThuis'] ?? data['thuisScore'],
    );
    final awayScore = nullableInt(
      data['awayScore'] ?? data['uitslagUit'] ?? data['uitScore'],
    );

    return SocialCardMatch(
      id: doc.id,
      division: SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['competitie'] ?? '').toString(),
      ),
      round: rankingInt(data['round'] ?? data['speelronde'] ?? data['ronde']),
      homeTeam: firstTeamValue([
        data['homeTeamName'],
        data['homeTeam'],
        data['thuisteam'],
        data['thuisTeam'],
        data['home'],
        data['homeTeamCode'],
        data['homeTeamId'],
        data['homeClubId'],
      ]),
      awayTeam: firstTeamValue([
        data['awayTeamName'],
        data['awayTeam'],
        data['uitteam'],
        data['uitTeam'],
        data['away'],
        data['awayTeamCode'],
        data['awayTeamId'],
        data['awayClubId'],
      ]),
      kickoffTime: MatchDateTimeFormatter.publicTime(data),
      status: parseMatchStatus(data['status']),
      dateTime: MatchDateTimeFormatter.dateTimeFromData(data),
      homeScore: homeScore,
      awayScore: awayScore,
      homeTeamId: firstTeamValue([
        data['homeTeamId'],
        data['homeClubId'],
        data['homeTeamCode'],
        data['thuisTeamId'],
        data['thuisteamId'],
      ]),
      awayTeamId: firstTeamValue([
        data['awayTeamId'],
        data['awayClubId'],
        data['awayTeamCode'],
        data['uitTeamId'],
        data['uitteamId'],
      ]),
      data: data,
    );
  }

  static int compare(SocialCardMatch a, SocialCardMatch b) {
    return MatchDateTimeFormatter.compare(a.data, b.data);
  }
}
