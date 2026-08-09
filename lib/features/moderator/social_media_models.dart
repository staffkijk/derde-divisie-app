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
  });
  final List<SocialCardMatch> matches;
  final List<SocialStanding> standings;
  final PredictionSummary predictionSummary;
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
    this.weekWinners = const [],
    this.globalTop = const [],
  });
  final List<PredictionRankEntry> weekWinners;
  final List<PredictionRankEntry> globalTop;
}

PredictionSummary buildPredictionSummary({
  required List<RankingUser> users,
  required List<Map<String, dynamic>> predictions,
  required Set<String> roundMatchIds,
}) {
  final byId = {for (final user in users) user.id: user};
  final scores = <String, int>{};
  for (final prediction in predictions) {
    final matchId =
        (prediction['wedstrijdId'] ?? prediction['matchId'] ?? '').toString();
    if (!roundMatchIds.contains(matchId)) continue;
    final uid = (prediction['gebruikerId'] ??
            prediction['userId'] ??
            prediction['uid'] ??
            '')
        .toString();
    if (uid.isEmpty) continue;
    scores.update(
      uid,
      (old) => old + rankingInt(prediction['punten']),
      ifAbsent: () => rankingInt(prediction['punten']),
    );
  }
  final best = scores.values.fold<int>(
    0,
    (old, score) => score > old ? score : old,
  );
  final winners = scores.entries
      .where((entry) => best > 0 && entry.value == best)
      .map((entry) {
    final user = byId[entry.key];
    return PredictionRankEntry(
      entry.key,
      user == null ? 'Onbekende gebruiker' : resolveUserDisplayName(user.data),
      entry.value,
    );
  }).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final sorted = sortRanking<RankingUser>(
    users,
    type: RankingType.global,
    dataOf: (user) => user.data,
    idOf: (user) => user.id,
  );
  return PredictionSummary(
    weekWinners: winners,
    globalTop: sorted
        .take(5)
        .map(
          (user) => PredictionRankEntry(
            user.id,
            resolveUserDisplayName(user.data),
            rankingScore(user.data, RankingType.global),
          ),
        )
        .toList(),
  );
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

  factory SocialCardMatch.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    int? nullableInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    return SocialCardMatch(
      id: doc.id,
      division: SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['competitie'] ?? '').toString(),
      ),
      round: rankingInt(data['round'] ?? data['speelronde']),
      homeTeam:
          (data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam'] ?? '')
              .toString()
              .trim(),
      awayTeam:
          (data['awayTeamName'] ?? data['awayTeam'] ?? data['uitteam'] ?? '')
              .toString()
              .trim(),
      kickoffTime: MatchDateTimeFormatter.publicTime(data),
      status: parseMatchStatus(data['status']),
      dateTime: MatchDateTimeFormatter.dateTimeFromData(data),
      homeScore: nullableInt(data['homeScore'] ?? data['uitslagThuis']),
      awayScore: nullableInt(data['awayScore'] ?? data['uitslagUit']),
      data: data,
    );
  }

  static int compare(SocialCardMatch a, SocialCardMatch b) {
    return MatchDateTimeFormatter.compare(a.data, b.data);
  }
}
