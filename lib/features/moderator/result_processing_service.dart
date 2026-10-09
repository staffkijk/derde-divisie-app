import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Saving commits only the source result. Durable Functions events own all
/// derived data; closing this browser cannot interrupt processing.
class ResultProcessingService {
  const ResultProcessingService();
  static Future<void> requestProcessing(String matchId) async {
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('retryMatchResult').call<void>({'matchId': matchId});
  }

  Future<void> saveFinishedResult({
    required DocumentReference<Map<String, dynamic>> matchRef,
    required int homeScore,
    required int awayScore,
    required String division,
    required int round,
    required String homeTeam,
    required String awayTeam,
    required String homeTeamSlug,
    required String awayTeamSlug,
  }) async {
    if (homeScore < 0 || awayScore < 0) {
      throw ArgumentError('Scores moeten positief of nul zijn.');
    }
    // Keep identifiers/date from the current match. A stale form must not
    // overwrite a concurrent schedule or team edit.
    await matchRef.update({
      'homeScore': homeScore, 'awayScore': awayScore,
      'uitslagThuis': homeScore, 'uitslagUit': awayScore,
      'status': 'finished', 'resultConfirmed': true,
      ..._pending(),
    });
  }

  Future<void> retryStoredResultProcessing({
    required DocumentReference<Map<String, dynamic>> matchRef,
  }) => requestProcessing(matchRef.id);

  Future<void> saveWithoutScore({
    required DocumentReference<Map<String, dynamic>> matchRef,
    required String status,
  }) => clearResultAndSetStatus(matchRef: matchRef, status: status);

  Future<void> clearResultAndSetStatus({
    required DocumentReference<Map<String, dynamic>> matchRef,
    required String status,
  }) async {
    if (!const {'scheduled', 'postponed', 'cancelled', 'abandoned'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await matchRef.update({
      'homeScore': FieldValue.delete(), 'awayScore': FieldValue.delete(),
      'uitslagThuis': FieldValue.delete(), 'uitslagUit': FieldValue.delete(),
      'status': status, 'resultConfirmed': false,
      ..._pending(),
    });
  }

  Map<String, dynamic> _pending() => {
    'processed': false, 'verwerkt': false,
    'processingStatus': 'pending', 'predictionProcessingComplete': false,
    'processingRequest': FieldValue.increment(1),
    'processingError': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': FirebaseAuth.instance.currentUser?.uid,
  };
}
