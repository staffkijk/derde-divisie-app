import 'package:cloud_functions/cloud_functions.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';
Future<void> resetEindstandPuntenBeide() async {
  for(final division in ['A','B']) {
    await FirebaseFunctions.instanceFor(region:'europe-west1').httpsCallable('processFinalStandings')
      .call<void>({'division':division,'reset':true});
  }
}
Future<void> volledigeResetAllesNaarNul() async {
  await resetEindstandPuntenBeide();
  final matches=await SeasonPaths.currentSeasonMatches.get();
  for(final match in matches.docs.where((d)=>d.id!='_meta')) {
    await const ResultProcessingService().clearResultAndSetStatus(matchRef:match.reference,status:'scheduled');
  }
}
