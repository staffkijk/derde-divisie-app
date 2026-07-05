import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:derde_divisie/Puntensysteem/puntenverwerker.dart';
import 'package:derde_divisie/features/moderator/periodestand_service.dart';
import 'package:derde_divisie/features/moderator/standen_service.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';

class ResultProcessingService {
  const ResultProcessingService();

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final runId =
        '${matchRef.id}_${DateTime.now().microsecondsSinceEpoch.toString()}';
    await matchRef.set(
      {
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': 'finished',
        'resultConfirmed': true,
        'processed': false,
        'verwerkt': false,
        'processingError': FieldValue.delete(),
        'processingAttempts': FieldValue.increment(1),
        'lastProcessingRunId': runId,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
        'uitslagThuis': homeScore,
        'uitslagUit': awayScore,
        'speelronde': round,
        'competitie': 'Derde Divisie $division',
        'thuisteam': homeTeam,
        'uitteam': awayTeam,
        'homeTeamCode': homeTeamSlug,
        'awayTeamCode': awayTeamSlug,
      },
      SetOptions(merge: true),
    );
    await ActivityLogService().log(
      eventType: ActivityEventType.resultSavedByModerator,
      entityType: 'match',
      entityId: matchRef.id,
      metadata: {
        'division': division,
        'round': round,
        'runId': runId,
      },
    );

    try {
      await StandenService().herberekenStandVoorDivisie(division);
      await PeriodestandService().herberekenAllePeriodesVoorDivisie(division);
      await verwerkVoorspellingenVoorWedstrijd(
        matchRef.id,
        homeScore,
        awayScore,
        division == 'B' ? 'punten_B' : 'punten_A',
      );
      await matchRef.set(
        {
          'processed': true,
          'verwerkt': true,
          'processedAt': FieldValue.serverTimestamp(),
          if (uid != null) 'processedBy': uid,
          'processingError': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      await ActivityLogService().log(
        eventType: ActivityEventType.resultProcessed,
        entityType: 'match',
        entityId: matchRef.id,
        metadata: {
          'division': division,
          'round': round,
          'runId': runId,
        },
      );
    } catch (error) {
      await matchRef.set(
        {
          'processed': false,
          'verwerkt': false,
          'processingError': error.toString(),
        },
        SetOptions(merge: true),
      );
      rethrow;
    }
  }

  Future<void> saveWithoutScore({
    required DocumentReference<Map<String, dynamic>> matchRef,
    required String status,
  }) {
    if (status != 'postponed' &&
        status != 'cancelled' &&
        status != 'abandoned') {
      throw ArgumentError.value(status, 'status');
    }
    return matchRef.set(
      {
        'homeScore': FieldValue.delete(),
        'awayScore': FieldValue.delete(),
        'uitslagThuis': FieldValue.delete(),
        'uitslagUit': FieldValue.delete(),
        'status': status,
        'resultConfirmed': false,
        'processed': false,
        'verwerkt': false,
        'processingError': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
