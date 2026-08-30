import 'package:cloud_firestore/cloud_firestore.dart';

class PoulePredictionRollbackService {
  const PoulePredictionRollbackService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> rollbackMatch(String matchId) async {
    const collections = <String>[
      'poule_predictions',
      'poule_voorspellingen',
      'predictions',
    ];

    for (final collection in collections) {
      final docs = await _predictionDocs(collection, matchId);
      for (final doc in docs) {
        await _rollbackPrediction(doc.reference);
      }
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _predictionDocs(
    String collection,
    String matchId,
  ) async {
    final byPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    void add(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final doc in snapshot.docs) {
        byPath[doc.reference.path] = doc;
      }
    }

    add(
      await _db.collection(collection).where('matchId', isEqualTo: matchId).get(),
    );
    add(
      await _db
          .collection(collection)
          .where('wedstrijdId', isEqualTo: matchId)
          .get(),
    );

    return byPath.values.toList();
  }

  Future<void> _rollbackPrediction(
    DocumentReference<Map<String, dynamic>> predictionRef,
  ) async {
    final snapshot = await predictionRef.get();
    final data = snapshot.data();
    if (data == null || data['verwerkt'] != true) return;

    final pouleId = (data['pouleId'] ?? data['poule'] ?? '').toString().trim();
    final userId =
        (data['gebruikerId'] ?? data['userId'] ?? data['uid'] ?? '')
            .toString()
            .trim();
    final participantRef = await _participantRef(pouleId, userId);

    await _db.runTransaction((transaction) async {
      final currentPrediction = await transaction.get(predictionRef);
      final prediction = currentPrediction.data();
      if (prediction == null || prediction['verwerkt'] != true) return;

      final oldPoints = _int(prediction['punten']);
      if (oldPoints != 0 && participantRef == null) {
        throw StateError(
          'Pouledeelnemer ontbreekt voor ${predictionRef.path}; rollback gestopt.',
        );
      }

      if (participantRef != null) {
        final participant = await transaction.get(participantRef);
        final participantData = participant.data() ?? const <String, dynamic>{};
        final currentPoints = _int(participantData['punten']);
        transaction.set(
          participantRef,
          {'punten': currentPoints - oldPoints},
          SetOptions(merge: true),
        );
      }

      transaction.set(
        predictionRef,
        {
          'punten': 0,
          'verwerkt': false,
          'verwerktVoorUitslag': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<DocumentReference<Map<String, dynamic>>?> _participantRef(
    String pouleId,
    String userId,
  ) async {
    if (pouleId.isEmpty || userId.isEmpty) return null;

    final direct = _db
        .collection('poules')
        .doc(pouleId)
        .collection('deelnemers')
        .doc(userId);
    if ((await direct.get()).exists) return direct;

    final query = await _db
        .collection('poules')
        .doc(pouleId)
        .collection('deelnemers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.reference;
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
