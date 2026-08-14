class PredictionCandidate {
  const PredictionCandidate(
      {required this.path, required this.data, required this.timestampMillis});
  final String path;
  final Map<String, dynamic> data;
  final int timestampMillis;
}

String predictionUserId(Map<String, dynamic> data) =>
    (data['gebruikerId'] ?? data['userId'] ?? data['uid'] ?? '')
        .toString()
        .trim();

int predictionHomeScore(Map<String, dynamic> data) => _firstInt(data, const [
      'scoreThuis',
      'homeScore',
      'thuisScore',
      'homeGoals',
      'voorspellingThuis',
      'thuis',
      'home',
      'goalsHome',
      'predHome',
    ]);

int predictionAwayScore(Map<String, dynamic> data) => _firstInt(data, const [
      'scoreUit',
      'awayScore',
      'uitScore',
      'awayGoals',
      'voorspellingUit',
      'uit',
      'away',
      'goalsAway',
      'predAway',
    ]);

List<PredictionCandidate> selectLatestPredictionPerUser(
  Iterable<PredictionCandidate> candidates,
) {
  final byPath = <String, PredictionCandidate>{};
  for (final candidate in candidates) {
    byPath[candidate.path] = candidate;
  }
  final byUser = <String, PredictionCandidate>{};
  for (final candidate in byPath.values) {
    final userId = predictionUserId(candidate.data);
    if (userId.isEmpty) continue;
    final current = byUser[userId];
    if (current == null ||
        candidate.timestampMillis > current.timestampMillis ||
        (candidate.timestampMillis == current.timestampMillis &&
            candidate.path.compareTo(current.path) < 0)) {
      byUser[userId] = candidate;
    }
  }
  return byUser.values.toList()..sort((a, b) => a.path.compareTo(b.path));
}

int _firstInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}
