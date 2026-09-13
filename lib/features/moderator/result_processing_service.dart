import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/features/moderator/general_prediction_points_service.dart';
import 'package:derde_divisie/features/moderator/periodestand_service.dart';
import 'package:derde_divisie/features/moderator/poule_prediction_rollback_service.dart';
import 'package:derde_divisie/features/moderator/prediction_processing_guard.dart';
import 'package:derde_divisie/features/moderator/standen_service.dart';

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
    final runId = _runId(matchRef.id);

    await matchRef.set(
      {
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': 'finished',
        'resultConfirmed': true,
        'processed': false,
        'verwerkt': false,
        'processingStatus': 'processing',
        'predictionProcessingComplete': false,
        'processingError': FieldValue.delete(),
        'processingFailedAt': FieldValue.delete(),
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

    await _processSavedResult(
      matchRef: matchRef,
      homeScore: homeScore,
      awayScore: awayScore,
      division: division,
      round: round,
      runId: runId,
      uid: uid,
    );
  }

  /// Maakt een reeds opgeslagen einduitslag opnieuw af zonder de score te
  /// wijzigen. De contribution-ledger maakt deze retry idempotent.
  Future<void> retryStoredResultProcessing({
    required DocumentReference<Map<String, dynamic>> matchRef,
  }) async {
    final snapshot = await matchRef.get();
    if (!snapshot.exists) {
      throw StateError('Wedstrijd ${matchRef.id} bestaat niet.');
    }

    final data = snapshot.data() ?? const <String, dynamic>{};
    final homeScore = _firstInt(data, const ['homeScore', 'uitslagThuis']);
    final awayScore = _firstInt(data, const ['awayScore', 'uitslagUit']);
    if (homeScore == null || awayScore == null) {
      throw StateError(
        'Wedstrijd ${matchRef.id} heeft geen volledige opgeslagen uitslag.',
      );
    }

    final division = _divisionFromMatch(data);
    final round = _firstInt(data, const ['round', 'speelronde', 'ronde']) ?? 0;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final runId = _runId(matchRef.id);

    await matchRef.set(
      {
        'processed': false,
        'verwerkt': false,
        'processingStatus': 'processing',
        'predictionProcessingComplete': false,
        'processingError': FieldValue.delete(),
        'processingFailedAt': FieldValue.delete(),
        'processingAttempts': FieldValue.increment(1),
        'lastProcessingRunId': runId,
        'lastProcessingWasRetry': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      },
      SetOptions(merge: true),
    );

    await _processSavedResult(
      matchRef: matchRef,
      homeScore: homeScore,
      awayScore: awayScore,
      division: division,
      round: round,
      runId: runId,
      uid: uid,
    );
  }

  Future<void> _processSavedResult({
    required DocumentReference<Map<String, dynamic>> matchRef,
    required int homeScore,
    required int awayScore,
    required String division,
    required int round,
    required String runId,
    required String? uid,
  }) async {
    PredictionProcessingSummary? summary;

    try {
      await StandenService().herberekenStandVoorDivisie(division);
      await PeriodestandService().herberekenAllePeriodesVoorDivisie(division);

      summary = await const GeneralPredictionPointsService().processMatch(
        matchId: matchRef.id,
        homeScore: homeScore,
        awayScore: awayScore,
        userPointsField: division == 'B' ? 'punten_B' : 'punten_A',
      );

      ensureCompletePredictionProcessing(
        selectedUsers: summary.selectedUsers,
        processedUsers: summary.processedUsers,
      );

      await matchRef.set(
        {
          'processed': true,
          'verwerkt': true,
          'processingStatus': 'processed',
          'predictionProcessingComplete': true,
          'predictionSourceDocuments': summary.sourceDocuments,
          'predictionSelectedUsers': summary.selectedUsers,
          'predictionProcessedUsers': summary.processedUsers,
          'processedResultKey': '$homeScore-$awayScore',
          'predictionProcessingCheckedAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
          if (uid != null) 'processedBy': uid,
          'processingError': FieldValue.delete(),
          'processingFailedAt': FieldValue.delete(),
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
          'predictionSourceDocuments': summary.sourceDocuments,
          'predictionSelectedUsers': summary.selectedUsers,
          'predictionProcessedUsers': summary.processedUsers,
        },
      );
    } catch (error) {
      await matchRef.set(
        {
          'processed': false,
          'verwerkt': false,
          'processingStatus': 'failed',
          'predictionProcessingComplete': false,
          if (summary != null) ...{
            'predictionSourceDocuments': summary.sourceDocuments,
            'predictionSelectedUsers': summary.selectedUsers,
            'predictionProcessedUsers': summary.processedUsers,
          },
          'processingError': error.toString(),
          'processingFailedAt': FieldValue.serverTimestamp(),
          'predictionProcessingCheckedAt': FieldValue.serverTimestamp(),
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

    await const GeneralPredictionPointsService().rollbackMatch(
      matchId: matchRef.id,
      userPointsField: division == 'B' ? 'punten_B' : 'punten_A',
    );
    await const PoulePredictionRollbackService().rollbackMatch(matchRef.id);

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
        'processingStatus': 'not_processed',
        'predictionProcessingComplete': false,
        'processedAt': FieldValue.delete(),
        'processedResultKey': FieldValue.delete(),
        'processingError': FieldValue.delete(),
        'processingFailedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (uid != null) 'updatedBy': uid,
      },
      SetOptions(merge: true),
    );

    await StandenService().herberekenStandVoorDivisie(division);
    await PeriodestandService().herberekenAllePeriodesVoorDivisie(division);

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

  static int? _firstInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _runId(String matchId) =>
      '${matchId}_${DateTime.now().microsecondsSinceEpoch.toString()}';
}
