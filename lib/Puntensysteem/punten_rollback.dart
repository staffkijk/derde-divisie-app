class PredictionRollback {
  const PredictionRollback({
    required this.pointsDelta,
    required this.nextPoints,
    required this.nextProcessed,
    required this.clearProcessedResult,
  });

  final int pointsDelta;
  final int nextPoints;
  final bool nextProcessed;
  final bool clearProcessedResult;
}

int predictionStoredPoints(Map<String, dynamic> data) {
  final value = data['punten'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

PredictionRollback rollbackProcessedPrediction(Map<String, dynamic> data) {
  if (data['verwerkt'] != true) {
    return const PredictionRollback(
      pointsDelta: 0,
      nextPoints: 0,
      nextProcessed: false,
      clearProcessedResult: true,
    );
  }

  final storedPoints = predictionStoredPoints(data);
  return PredictionRollback(
    pointsDelta: -storedPoints,
    nextPoints: 0,
    nextProcessed: false,
    clearProcessedResult: true,
  );
}
