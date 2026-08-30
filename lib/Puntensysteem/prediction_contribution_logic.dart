class PredictionContributionState {
  const PredictionContributionState({
    required this.points,
    required this.resultKey,
    required this.processed,
  });

  final int points;
  final String resultKey;
  final bool processed;
}

class PredictionContributionTransition {
  const PredictionContributionTransition({
    required this.previousPoints,
    required this.nextPoints,
    required this.delta,
    required this.resultKey,
    required this.adoptsExistingContribution,
  });

  final int previousPoints;
  final int nextPoints;
  final int delta;
  final String resultKey;
  final bool adoptsExistingContribution;
}

PredictionContributionTransition planPredictionContribution({
  required int newPoints,
  required String resultKey,
  PredictionContributionState? ledger,
  PredictionContributionState? prediction,
}) {
  final hasLedger = ledger?.processed == true;
  final canAdoptPrediction = !hasLedger &&
      prediction?.processed == true &&
      prediction!.resultKey.isNotEmpty;

  final previousPoints = hasLedger
      ? ledger!.points
      : canAdoptPrediction
          ? prediction!.points
          : 0;

  return PredictionContributionTransition(
    previousPoints: previousPoints,
    nextPoints: newPoints,
    delta: newPoints - previousPoints,
    resultKey: resultKey,
    adoptsExistingContribution: canAdoptPrediction,
  );
}

String predictionContributionDocumentId({
  required String division,
  required String userId,
  required String matchId,
}) {
  String safe(String value) => value.trim().replaceAll('/', '_');
  return '${safe(division)}__${safe(userId)}__${safe(matchId)}';
}

class PredictionTotals {
  const PredictionTotals({
    required this.pointsA,
    required this.pointsB,
  });

  final int pointsA;
  final int pointsB;

  int get totalen => pointsA > pointsB ? pointsA : pointsB;
}

PredictionTotals rebuildPredictionTotals(
  Iterable<({String division, int points})> contributions,
) {
  var pointsA = 0;
  var pointsB = 0;

  for (final contribution in contributions) {
    final division = contribution.division.trim().toUpperCase();
    if (division == 'A') {
      pointsA += contribution.points;
    } else if (division == 'B') {
      pointsB += contribution.points;
    }
  }

  return PredictionTotals(pointsA: pointsA, pointsB: pointsB);
}
