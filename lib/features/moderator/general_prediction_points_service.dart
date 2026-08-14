import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/Puntensysteem/puntenlogica.dart'
    show berekenPunten;
import 'package:derde_divisie/Puntensysteem/prediction_processing_helpers.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class GeneralPredictionPointsService {
  const GeneralPredictionPointsService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> processMatch({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String userPointsField,
  }) async {
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
      final userId = _userId(data);
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

    final resultKey = '$homeScore-$awayScore';
    var processed = 0;

    for (final entry in selectedByUser.entries) {
      final userId = entry.key;
      final doc = entry.value;
      final data = doc.data();
      final previousProcessed = data['verwerkt'] == true;
      final previousResult = (data['verwerktVoorUitslag'] ?? '').toString();
      final previousPoints = _int(data['punten']);

      if (previousProcessed && previousResult == resultKey) continue;

      final predictionHome = predictionHomeScore(data);
      final predictionAway = predictionAwayScore(data);
      final newPoints = berekenPunten(
        voorspeldThuis: predictionHome,
        voorspeldUit: predictionAway,
        echtThuis: homeScore,
        echtUit: awayScore,
      );
      final delta = newPoints - (previousProcessed ? previousPoints : 0);

      await doc.reference.set({
        'punten': newPoints,
        'verwerkt': true,
        'verwerktVoorUitslag': resultKey,
      }, SetOptions(merge: true));

      if (delta != 0) {
        final userRef = _db.collection('users').doc(userId);
        await userRef.set(
          {userPointsField: FieldValue.increment(delta)},
          SetOptions(merge: true),
        );
        await _updateGlobalTotal(userRef);
      }

      processed++;
    }

    developer.log(
      '[GeneralPredictionPoints] match=$matchId bronnen=${docs.length} '
      'gebruikers=${selectedByUser.length} verwerkt=$processed',
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _findAllPredictionDocs(String matchId) async {
    final byPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    Future<void> add(QuerySnapshot<Map<String, dynamic>> snapshot) async {
      for (final doc in snapshot.docs) {
        byPath[doc.reference.path] = doc;
      }
    }

    await add(
      await SeasonPaths.currentSeasonPredictions
          .where('wedstrijdId', isEqualTo: matchId)
          .get(),
    );
    await add(
      await SeasonPaths.currentSeasonPredictions
          .where('matchId', isEqualTo: matchId)
          .get(),
    );
    await add(
      await _db
          .collection('voorspellingen')
          .where('wedstrijdId', isEqualTo: matchId)
          .get(),
    );
    await add(
      await _db
          .collection('voorspellingen')
          .where('matchId', isEqualTo: matchId)
          .get(),
    );

    return byPath.values.toList();
  }

  Future<void> _updateGlobalTotal(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    final snapshot = await userRef.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final a = _int(data['punten_A']);
    final b = _int(data['punten_B']);
    await userRef.set(
      {'totalen': a > b ? a : b},
      SetOptions(merge: true),
    );
  }

  static String _userId(Map<String, dynamic> data) {
    return (data['gebruikerId'] ?? data['userId'] ?? data['uid'] ?? '')
        .toString()
        .trim();
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
