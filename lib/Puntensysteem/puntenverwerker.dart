import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';

Future<void> verwerkVoorspellingenVoorWedstrijd(String wedstrijdId,
    int uitslagThuis, int uitslagUit, String veldnaam) =>
    ResultProcessingService.requestProcessing(wedstrijdId);
Future<void> draaiVoorspellingenVoorWedstrijdTerug(String wedstrijdId,
    String veldnaam) => resetWedstrijd(wedstrijdId);
Future<void> verwerkUitslagVoorWedstrijd(String wedstrijdId) =>
    ResultProcessingService.requestProcessing(wedstrijdId);
Future<void> resetWedstrijd(String wedstrijdId) =>
    const ResultProcessingService().clearResultAndSetStatus(
      matchRef: SeasonPaths.currentSeasonMatches.doc(wedstrijdId),
      status: 'scheduled',
    );
