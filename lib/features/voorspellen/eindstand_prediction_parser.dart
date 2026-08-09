import 'package:derde_divisie/data/config/season_config.dart';

class EindstandPredictionState {
  const EindstandPredictionState({
    required this.clubs,
    required this.points,
    required this.hasValidSavedPrediction,
  });

  final List<String> clubs;
  final int points;
  final bool hasValidSavedPrediction;
}

/// Parses an account-specific prediction without trusting legacy Firestore
/// values. Invalid data is only repaired in memory; the source document is not
/// changed until the user explicitly changes the ranking.
EindstandPredictionState parseEindstandPrediction({
  required Map<String, dynamic>? data,
  required List<String> configuredTeams,
  required String activeSeasonId,
}) {
  final fallback = List<String>.unmodifiable(configuredTeams);
  if (data == null || data['seasonId']?.toString() != activeSeasonId) {
    return EindstandPredictionState(
      clubs: fallback,
      points: 0,
      hasValidSavedPrediction: false,
    );
  }

  final rawRanking = data['voorspelling'];
  final configuredByKey = <String, String>{
    for (final team in configuredTeams)
      SeasonConfig.normalizeTeamKey(team): team,
  };
  final repaired = <String>[];
  final seen = <String>{};

  if (rawRanking is List) {
    for (final value in rawRanking) {
      if (value is! String || value.trim().isEmpty) continue;
      final canonicalName = SeasonConfig.displayNameForTeam(value.trim());
      final key = SeasonConfig.normalizeTeamKey(canonicalName);
      final configuredName = configuredByKey[key];
      if (configuredName != null && seen.add(key)) repaired.add(configuredName);
    }
  }

  final isValid = rawRanking is List &&
      rawRanking.length == configuredTeams.length &&
      repaired.length == configuredTeams.length;
  if (!isValid) {
    for (final team in configuredTeams) {
      final key = SeasonConfig.normalizeTeamKey(team);
      if (seen.add(key)) repaired.add(team);
    }
  }

  final rawPoints = data['punten'];
  return EindstandPredictionState(
    clubs: List<String>.unmodifiable(repaired),
    points: rawPoints is num ? rawPoints.toInt() : 0,
    hasValidSavedPrediction: isValid,
  );
}
