import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:derde_divisie/Puntensysteem/puntenverwerker.dart'
    show draaiVoorspellingenVoorWedstrijdTerug;
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/moderator/general_prediction_points_service.dart';
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
      await const GeneralPredictionPointsService().processMatch(
        matchId: matchRef.id,
        homeScore: homeScore,
        awayScore: awayScore,
        userPointsField: division == 'B' ? 'punten_B' : 'punten_A',
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
    return clearResultAndSetStatus(matchRef: matchRef, status: status);
  }

  Future<void> clearResultAndSetStatus({
    required DocumentReference<Map<String, dynamic>> matchRef,
    required String status,
  }) async {
    if (!_nonFinishedStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }

    final before = await matchRef.get();
    final oldData = before.data() ?? {};
    final division = _divisionFromMatch(oldData);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final oldStatus = (oldData['status'] ?? '').toString();
    final wasProcessed =
        oldData['processed'] == true || oldData['verwerkt'] == true;
    final hadScore = oldData['homeScore'] != null ||
        oldData['awayScore'] != null ||
        oldData['uitslagThuis'] != null ||
        oldData['uitslagUit'] != null;

    await matchRef.set(
      {
        'homeScore': FieldValue.delete(),
        'awayScore': FieldValue.delete(),
        'uitslagThuis': FieldValue.delete(),
        'uitslagUit': FieldValue.delete(),
        'vorigeUitslagThuis': FieldValue.delete(),
        'vorigeUitslagUit': FieldValue.delete(),
        'status': status,
        'resultConfirmed': false,
        'processed': false,
        'verwerkt': false,
        'processedAt': FieldValue.delete(),
        'processingError': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      },
      SetOptions(merge: true),
    );

    await StandenService().herberekenStandVoorDivisie(division);
    await PeriodestandService().herberekenAllePeriodesVoorDivisie(division);
    await draaiVoorspellingenVoorWedstrijdTerug(
      matchRef.id,
      division == 'B' ? 'punten_B' : 'punten_A',
    );

    await ActivityLogService().log(
      eventType: ActivityEventType.resultProcessed,
      entityType: 'match',
      entityId: matchRef.id,
      metadata: {
        'division': division,
        'status': status,
        'oldStatus': oldStatus,
        'wasProcessed': wasProcessed,
        'hadScore': hadScore,
      },
    );
  }

  static const _nonFinishedStatuses = {
    'scheduled',
    'postponed',
    'cancelled',
    'abandoned',
  };

  String _divisionFromMatch(Map<String, dynamic> data) {
    final raw =
        (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '')
            .toString();
    final normalized = SeasonConfig.normalizeDivisionCode(raw);
    if (normalized == 'A' || normalized == 'B') return normalized;
    throw StateError('Divisie kan niet worden bepaald voor wedstrijd.');
  }
}
