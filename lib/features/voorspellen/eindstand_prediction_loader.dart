import 'dart:async';

import 'package:derde_divisie/features/voorspellen/eindstand_prediction_parser.dart';

typedef EindstandPredictionRead = Future<Map<String, dynamic>?> Function();

Future<EindstandPredictionState> loadEindstandPrediction({
  required EindstandPredictionRead readPrediction,
  required List<String> configuredTeams,
  required String activeSeasonId,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final data = await readPrediction().timeout(timeout);

  return parseEindstandPrediction(
    data: data,
    configuredTeams: configuredTeams,
    activeSeasonId: activeSeasonId,
  );
}
