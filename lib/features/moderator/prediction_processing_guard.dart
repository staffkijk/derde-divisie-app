class PredictionProcessingInvariantException implements Exception {
  const PredictionProcessingInvariantException({
    required this.selectedUsers,
    required this.processedUsers,
  });

  final int selectedUsers;
  final int processedUsers;

  @override
  String toString() =>
      'PredictionProcessingInvariantException: '
      '$processedUsers/$selectedUsers voorspellers verwerkt.';
}

bool predictionProcessingIsComplete({
  required int selectedUsers,
  required int processedUsers,
}) {
  return selectedUsers == processedUsers;
}

void ensureCompletePredictionProcessing({
  required int selectedUsers,
  required int processedUsers,
}) {
  if (predictionProcessingIsComplete(
    selectedUsers: selectedUsers,
    processedUsers: processedUsers,
  )) {
    return;
  }

  throw PredictionProcessingInvariantException(
    selectedUsers: selectedUsers,
    processedUsers: processedUsers,
  );
}
