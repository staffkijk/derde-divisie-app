import 'package:derde_divisie/features/moderator/result_processing_service.dart';

/// Compatibility entry point: processing always uses the stored current result.
class GeneralPredictionPointsService {
  const GeneralPredictionPointsService();
  Future<void> processMatch({required String matchId, required int homeScore,
    required int awayScore, required String userPointsField}) =>
      ResultProcessingService.requestProcessing(matchId);
}
