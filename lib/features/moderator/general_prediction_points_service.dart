import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/Puntensysteem/prediction_contribution_logic.dart';
import 'package:derde_divisie/Puntensysteem/prediction_processing_helpers.dart';
import 'package:derde_divisie/Puntensysteem/puntenlogica.dart'
    show berekenPunten;
import 'package:derde_divisie/data/firestore/season_paths.dart';

class PredictionProcessingSummary {
  const PredictionProcessingSummary({
    required this.sourceDocuments,
    required this.selectedUsers,
    required this.processedUsers,
  });

  final int sourceDocuments;
  final int selectedUsers;
  final int processedUsers;
}

class GeneralPredictionPointsService {
  const GeneralPredictionPointsService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<PredictionProcessingSummary> processMatch({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String userPointsField,
  }) async {
    final selected = await _selectedPredictionDocs(matchId);
    final resultKey = '$homeScore-$awayScore';
    final division = _divisionForUserPointsField(userPointsField);
    var processed = 0;

    for (final entry in selected.selectedByUser.entries) {
      final userId = entry.key;
      final predictionRef = entry.value.reference;
      final ledgerId = predictionContributionDocumentId(
        division: division,
        userId: userId,
        matchId: matchId,
      );
      final ledgerRef =
          SeasonPaths.currentSeasonPredictionContributions.doc(ledgerId);
      final userRef = _db.collection('users').doc(userId);

      await _db.runTransaction((transaction) async {
        final predictionSnapshot = await transaction.get(predictionRef);
        final ledgerSnapshot = await transaction.get(ledgerRef);
        final userSnapshot = await transaction.get(userRef);

        final prediction = predictionSnapshot.data();
        if (prediction == null) {
          throw StateError(
            'Prediction verdwenen tijdens verwerking: ${predictionRef.path}',
          );
        }

        final predictionHome = predictionHomeScore(prediction);
        final predictionAway = predictionAwayScore(prediction);
        final newPoints = berekenPunten(
          voorspeldThuis: predictionHome,
          voorspeldUit: predictionAway,
          echtThuis: homeScore,
          echtUit: awayScore,
        );

        final predictionState = PredictionContributionState(
          points: _int(prediction['punten']),
          resultKey: (prediction['verwerktVoorUitslag'] ?? '').toString(),
          processed: prediction['verwerkt'] == true,
        );
        final ledgerData = ledgerSnapshot.data();
        final ledgerState = ledgerData == null
            ? null
            : PredictionContributionState(
                points: _int(ledgerData['points']),
                resultKey: (ledgerData['resultKey'] ?? '').toString(),
                processed: ledgerData['processed'] == true,
              );
        final transition = planPredictionContribution(
          newPoints: newPoints,
          resultKey: resultKey,
          ledger: ledgerState,
          prediction: predictionState,
        );

        final userData = userSnapshot.data() ?? const <String, dynamic>{};
        final currentA = _int(userData['punten_A']);
        final currentB = _int(userData['punten_B']);
        final nextA = userPointsField == 'punten_A'
            ? currentA + transition.delta
            : currentA;
        final nextB = userPointsField == 'punten_B'
            ? currentB + transition.delta
            : currentB;
        final nextTotal = nextA > nextB ? nextA : nextB;

        transaction.set(
          predictionRef,
          {
            'punten': newPoints,
            'verwerkt': true,
            'verwerktVoorUitslag': resultKey,
          },
          SetOptions(merge: true),
        );
        transaction.set(
          ledgerRef,
          {
            'userId': userId,
            'matchId': matchId,
            'division': division,
            'predictionPath': predictionRef.path,
            'points': newPoints,
            'resultKey': resultKey,
            'processed': true,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!ledgerSnapshot.exists)
              'createdAt': FieldValue.serverTimestamp(),
            if (transition.adoptsExistingContribution)
              'adoptedExistingContribution': true,
          },
          SetOptions(merge: true),
        );
        transaction.set(
          userRef,
          {
            'punten_A': nextA,
            'punten_B': nextB,
            'totalen': nextTotal,
          },
          SetOptions(merge: true),
        );
      });

      processed++;
    }

    developer.log(
      '[GeneralPredictionPoints] match=$matchId '
      'bronnen=${selected.sourceDocuments} '
      'gebruikers=${selected.selectedByUser.length} verwerkt=$processed',
    );

    return PredictionProcessingSummary(
      sourceDocuments: selected.sourceDocuments,
      selectedUsers: selected.selectedByUser.length,
      processedUsers: processed,
    );
  }

  Future<PredictionProcessingSummary> rollbackMatch({
    required String matchId,
    required String userPointsField,
  }) async {
    final selected = await _selectedPredictionDocs(matchId);
    final division = _divisionForUserPointsField(userPointsField);
    var processed = 0;

    for (final entry in selected.selectedByUser.entries) {
      final userId = entry.key;
      final predictionRef = entry.value.reference;
      final ledgerId = predictionContributionDocumentId(
        division: division,
        userId: userId,
        matchId: matchId,
      );
      final ledgerRef =
          SeasonPaths.currentSeasonPredictionContributions.doc(ledgerId);
      final userRef = _db.collection('users').doc(userId);

      await _db.runTransaction((transaction) async {
        final predictionSnapshot = await transaction.get(predictionRef);
        final ledgerSnapshot = await transaction.get(ledgerRef);
        final userSnapshot = await transaction.get(userRef);

        final prediction = predictionSnapshot.data();
        if (prediction == null) return;

        final ledgerData = ledgerSnapshot.data();
        final ledgerProcessed = ledgerData?['processed'] == true;
        final predictionProcessed = prediction['verwerkt'] == true;
        final previousPoints = ledgerProcessed
            ? _int(ledgerData?['points'])
            : predictionProcessed
                ? _int(prediction['punten'])
                : 0;

        final userData = userSnapshot.data() ?? const <String, dynamic>{};
        final currentA = _int(userData['punten_A']);
        final currentB = _int(userData['punten_B']);
        final nextA = userPointsField == 'punten_A'
            ? currentA - previousPoints
            : currentA;
        final nextB = userPointsField == 'punten_B'
            ? currentB - previousPoints
            : currentB;
        final nextTotal = nextA > nextB ? nextA : nextB;

        transaction.set(
          predictionRef,
          {
            'punten': 0,
            'verwerkt': false,
            'verwerktVoorUitslag': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          ledgerRef,
          {
            'userId': userId,
            'matchId': matchId,
            'division': division,
            'predictionPath': predictionRef.path,
            'points': 0,
            'resultKey': '',
            'processed': false,
            'rolledBackAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (!ledgerSnapshot.exists)
              'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          userRef,
          {
            'punten_A': nextA,
            'punten_B': nextB,
            'totalen': nextTotal,
          },
          SetOptions(merge: true),
        );
      });

      processed++;
    }

    developer.log(
      '[GeneralPredictionPoints] rollback match=$matchId '
      'bronnen=${selected.sourceDocuments} '
      'gebruikers=${selected.selectedByUser.length} verwerkt=$processed',
    );

    return PredictionProcessingSummary(
      sourceDocuments: selected.sourceDocuments,
      selectedUsers: selected.selectedByUser.length,
      processedUsers: processed,
    );
  }

  Future<Map<String, PredictionTotals>> rebuildTotalsReadOnly({
    String? userId,
  }) async {
    final snapshot =
        await SeasonPaths.currentSeasonPredictionContributions.get();
    final grouped = <String, List<PredictionContributionValue>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['processed'] != true) continue;
      final contributionUserId = (data['userId'] ?? '').toString().trim();
      if (contributionUserId.isEmpty) continue;
      if (userId != null && contributionUserId != userId) continue;
      grouped.putIfAbsent(contributionUserId, () => []).add(
            PredictionContributionValue(
              division: (data['division'] ?? '').toString(),
              points: _int(data['points']),
            ),
          );
    }

    return {
      for (final entry in grouped.entries)
        entry.key: rebuildPredictionTotals(entry.value),
    };
  }

  Future<_SelectedPredictionDocs> _selectedPredictionDocs(String matchId) async {
    final match = await SeasonPaths.currentSeasonMatches.doc(matchId).get();
    final matchData = match.data();
    final Timestamp? matchTimestamp =
        (matchData?['scheduledAt'] as Timestamp?) ??
            (matchData?['timestamp'] as Timestamp?) ??
            (matchData?['datum'] as Timestamp?) ??
            (matchData?['date'] as Timestamp?);

    DateTime? deadline;
    if (matchTimestamp != null) {
      final date = matchTimestamp.toDate();
      deadline = DateTime(date.year, date.month, date.day, 12);
    }

    final docs = await _findAllPredictionDocs(matchId);
    final selectedByUser =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final selectedTimestamp = <String, int>{};

    for (final doc in docs) {
      final data = doc.data();
      final userId = predictionUserId(data);
      if (userId.isEmpty) continue;

      final predictionTimestamp = data['timestamp'] as Timestamp?;
      final predictionDate = predictionTimestamp?.toDate();
      if (deadline != null &&
          (predictionDate == null || predictionDate.isAfter(deadline))) {
        continue;
      }

      final millis = predictionTimestamp?.millisecondsSinceEpoch ?? 0;
      final currentMillis = selectedTimestamp[userId] ?? -1;
      if (!selectedByUser.containsKey(userId) || millis >= currentMillis) {
        selectedByUser[userId] = doc;
        selectedTimestamp[userId] = millis;
      }
    }

    return _SelectedPredictionDocs(
      sourceDocuments: docs.length,
      selectedByUser: selectedByUser,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _findAllPredictionDocs(String matchId) async {
    final byPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    void add(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final doc in snapshot.docs) {
        byPath[doc.reference.path] = doc;
      }
    }

    add(
      await SeasonPaths.currentSeasonPredictions
          .where('wedstrijdId', isEqualTo: matchId)
          .get(),
    );
    add(
      await SeasonPaths.currentSeasonPredictions
          .where('matchId', isEqualTo: matchId)
          .get(),
    );
    add(
      await _db
          .collection('voorspellingen')
          .where('wedstrijdId', isEqualTo: matchId)
          .get(),
    );
    add(
      await _db
          .collection('voorspellingen')
          .where('matchId', isEqualTo: matchId)
          .get(),
    );

    return byPath.values.toList();
  }

  static String _divisionForUserPointsField(String userPointsField) {
    if (userPointsField == 'punten_A') return 'A';
    if (userPointsField == 'punten_B') return 'B';
    throw ArgumentError.value(userPointsField, 'userPointsField');
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _SelectedPredictionDocs {
  const _SelectedPredictionDocs({
    required this.sourceDocuments,
    required this.selectedByUser,
  });

  final int sourceDocuments;
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
      selectedByUser;
}
