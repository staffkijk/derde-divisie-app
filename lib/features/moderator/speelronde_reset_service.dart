import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';
class SpeelrondeResetService {
  Future<void> resetSpeelronde(String divisie, int speelronde) async {
    final matches = await SeasonPaths.currentSeasonMatches
        .where('division', isEqualTo: divisie).where('round', isEqualTo: speelronde).get();
    await Future.wait(matches.docs.map((doc) => const ResultProcessingService()
      .clearResultAndSetStatus(matchRef: doc.reference, status: 'scheduled')));
  }
}
