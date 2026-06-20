// lib/moderator/mod_tools.dart
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/Puntensysteem/puntenverwerker.dart';
import 'package:derde_divisie/Puntensysteem/puntenlogica.dart'
    show berekenPunten;
import 'package:derde_divisie/Puntensysteem/eindstand_puntenverwerker.dart'
    as eindstand;

final _db = FirebaseFirestore.instance;

int _toIntMod(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

String _asString(dynamic value) => value?.toString().trim() ?? '';

bool _hasScoreFields(Map<String, dynamic> data) {
  return data.containsKey('scoreThuis') && data.containsKey('scoreUit');
}

String _normAudit(String s) {
  return s
      .replaceAll('’', '')
      .replaceAll("'", '')
      .replaceAll(' ', '')
      .replaceAll('/', '')
      .replaceAll('-', '')
      .replaceAll('.', '')
      .toUpperCase();
}

Future<void> _forEachCollection(
  String collectionPath,
  Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> d) onDoc, {
  int pageSize = 400,
}) async {
  Query<Map<String, dynamic>> q = _db
      .collection(collectionPath)
      .orderBy(FieldPath.documentId)
      .limit(pageSize);

  var total = 0;

  while (true) {
    final snap = await q.get();
    if (snap.docs.isEmpty) break;

    for (final d in snap.docs) {
      await onDoc(d);
      total++;
    }

    developer.log('[MOD] $collectionPath processed=$total');

    final last = snap.docs.last;
    q = _db
        .collection(collectionPath)
        .orderBy(FieldPath.documentId)
        .limit(pageSize)
        .startAfterDocument(last);
  }
}

Future<void> _deleteCollectionDocs(
  CollectionReference<Map<String, dynamic>> collectionRef,
) async {
  while (true) {
    final snap = await collectionRef.limit(450).get();
    if (snap.docs.isEmpty) break;

    final batch = _db.batch();

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

DateTime? _matchDeadline(Map<String, dynamic> match) {
  final ts = (match['timestamp'] as Timestamp?) ?? (match['datum'] as Timestamp?);
  if (ts == null) return null;

  final d = ts.toDate();
  return DateTime(d.year, d.month, d.day, 12);
}

bool _timestampLijktNaDeadline({
  required Map<String, dynamic> prediction,
  required Map<String, dynamic> match,
}) {
  final deadline = _matchDeadline(match);
  if (deadline == null) return false;

  final ingevuldOp = (prediction['timestamp'] as Timestamp?)?.toDate();
  if (ingevuldOp == null) return false;

  return ingevuldOp.isAfter(deadline);
}

class _AuditWriter {
  _AuditWriter(this.auditRef);

  final DocumentReference<Map<String, dynamic>> auditRef;

  WriteBatch? _batch;
  int _batchCount = 0;

  int issues = 0;
  int critical = 0;
  int warnings = 0;

  final Map<String, int> issuesByType = {};
  final Map<String, int> criticalByType = {};
  final Map<String, int> warningByType = {};

  CollectionReference<Map<String, dynamic>> get _issuesRef =>
      auditRef.collection('issues');

  Future<void> addIssue({
    required String severity,
    required String type,
    required String message,
    String? uid,
    String? username,
    String? wedstrijdId,
    String? pouleId,
    String? club,
    String? divisie,
    String? documentPath,
    dynamic expected,
    dynamic actual,
    dynamic difference,
    Map<String, dynamic>? details,
  }) async {
    issues++;
    issuesByType[type] = (issuesByType[type] ?? 0) + 1;

    if (severity == 'critical') {
      critical++;
      criticalByType[type] = (criticalByType[type] ?? 0) + 1;
    } else {
      warnings++;
      warningByType[type] = (warningByType[type] ?? 0) + 1;
    }

    _batch ??= _db.batch();

    final issueRef = _issuesRef.doc();

    _batch!.set(issueRef, {
      'createdAt': FieldValue.serverTimestamp(),
      'severity': severity,
      'type': type,
      'message': message,
      if (uid != null) 'uid': uid,
      if (username != null) 'username': username,
      if (wedstrijdId != null) 'wedstrijdId': wedstrijdId,
      if (pouleId != null) 'pouleId': pouleId,
      if (club != null) 'club': club,
      if (divisie != null) 'divisie': divisie,
      if (documentPath != null) 'documentPath': documentPath,
      if (expected != null) 'expected': expected,
      if (actual != null) 'actual': actual,
      if (difference != null) 'difference': difference,
      if (details != null) 'details': details,
    });

    _batchCount++;

    if (_batchCount >= 430) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (_batch == null || _batchCount == 0) return;

    await _batch!.commit();

    _batch = null;
    _batchCount = 0;
  }
}

Future<void> _herbouwAlgemeneUserTotalen(String gebruikerId) async {
  final voorspellingenSnap = await _db
      .collection('voorspellingen')
      .where('gebruikerId', isEqualTo: gebruikerId)
      .get();

  int puntenA = 0;
  int puntenB = 0;

  for (final doc in voorspellingenSnap.docs) {
    final data = doc.data();

    if (data['verwerkt'] != true) continue;
    if (data['auditIgnored'] == true || data['ongeldig'] == true) continue;

    final wedstrijdId = _asString(data['wedstrijdId']).toUpperCase();
    final punten = _toIntMod(data['punten']);

    if (wedstrijdId.startsWith('A')) {
      puntenA += punten;
    } else if (wedstrijdId.startsWith('B')) {
      puntenB += punten;
    }
  }

  final eindstandDoc =
      await _db.collection('voorspel_punten').doc(gebruikerId).get();

  if (eindstandDoc.exists) {
    final eindstandData = eindstandDoc.data() ?? {};

    puntenA += _toIntMod(eindstandData['eindstand_A_punten']);
    puntenB += _toIntMod(eindstandData['eindstand_B_punten']);
  }

  final totalen = puntenA > puntenB ? puntenA : puntenB;

  await _db.collection('users').doc(gebruikerId).set({
    'punten_A': puntenA,
    'punten_B': puntenB,
    'totalen': totalen,
    'points': totalen,
    'laatstHerbouwdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  developer.log(
    '✅ [MOD] Totalen herbouwd user=$gebruikerId punten_A=$puntenA punten_B=$puntenB totalen=$totalen',
  );
}

Future<void> herberekenAlleWedstrijden() async {
  developer.log('🔁 [MOD] Start herberekenen van wedstrijden');

  final qs = await _db.collection('matches').get();
  int n = 0;

  for (final m in qs.docs) {
    final d = m.data();

    if (d['uitslagThuis'] != null && d['uitslagUit'] != null) {
      n++;
      developer.log('🔁 [MOD] herbereken ${m.id}');
      await verwerkUitslagVoorWedstrijd(m.id);
    }
  }

  developer.log('✅ [MOD] Herberekend: $n wedstrijden');
}

Future<void> herstelVoorspellingenSpeelronde18A() async {
  developer.log('🛠️ [MOD] FORCE herstel Speelronde 18 A gestart');

  const gebruikerId = 'Tj6yXH5OahhfFPgJhSjNYTM2CYy2';

  const wedstrijdIds = <String>[
    'A154',
    'A155',
    'A156',
    'A157',
    'A158',
    'A159',
    'A160',
    'A161',
    'A162',
  ];

  int bijgewerkt = 0;
  int overgeslagen = 0;
  int totaalPuntenRonde = 0;

  for (final wedstrijdId in wedstrijdIds) {
    final matchDoc = await _db.collection('matches').doc(wedstrijdId).get();

    if (!matchDoc.exists) {
      overgeslagen++;
      continue;
    }

    final matchData = matchDoc.data() ?? {};

    if (matchData['uitslagThuis'] == null || matchData['uitslagUit'] == null) {
      overgeslagen++;
      continue;
    }

    final voorspellingRef =
        _db.collection('voorspellingen').doc('${gebruikerId}_$wedstrijdId');

    final voorspellingDoc = await voorspellingRef.get();

    if (!voorspellingDoc.exists) {
      overgeslagen++;
      continue;
    }

    final voorspellingData = voorspellingDoc.data() ?? {};

    if (!_hasScoreFields(voorspellingData)) {
      overgeslagen++;
      continue;
    }

    final scoreThuis = _toIntMod(voorspellingData['scoreThuis']);
    final scoreUit = _toIntMod(voorspellingData['scoreUit']);
    final uitslagThuis = _toIntMod(matchData['uitslagThuis']);
    final uitslagUit = _toIntMod(matchData['uitslagUit']);

    final punten = berekenPunten(
      voorspeldThuis: scoreThuis,
      voorspeldUit: scoreUit,
      echtThuis: uitslagThuis,
      echtUit: uitslagUit,
    );

    final uitslagKey = '$uitslagThuis-$uitslagUit';

    await voorspellingRef.set({
      'gebruikerId': gebruikerId,
      'wedstrijdId': wedstrijdId,
      'punten': punten,
      'verwerkt': true,
      'verwerktVoorUitslag': uitslagKey,
      'laatstHersteldAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    totaalPuntenRonde += punten;
    bijgewerkt++;
  }

  await _herbouwAlgemeneUserTotalen(gebruikerId);

  developer.log(
    '✅ [MOD] FORCE herstel Speelronde 18 A klaar. bijgewerkt=$bijgewerkt overgeslagen=$overgeslagen rondepunten=$totaalPuntenRonde',
  );
}

Future<void> herstelVoorspellingenVoorWedstrijden(
  List<String> wedstrijdIds,
) async {
  developer.log(
    '🛠️ [MOD] Start herstel voorspellingen voor ${wedstrijdIds.length} wedstrijden',
  );

  int matchesGevonden = 0;
  int matchesOvergeslagen = 0;
  int matchesVerwerkt = 0;

  for (final wedstrijdId in wedstrijdIds) {
    final cleanWedstrijdId = wedstrijdId.trim();

    if (cleanWedstrijdId.isEmpty) {
      matchesOvergeslagen++;
      continue;
    }

    final matchDoc = await _db.collection('matches').doc(cleanWedstrijdId).get();

    if (!matchDoc.exists) {
      matchesOvergeslagen++;
      continue;
    }

    matchesGevonden++;

    final data = matchDoc.data() ?? {};

    if (data['uitslagThuis'] == null || data['uitslagUit'] == null) {
      matchesOvergeslagen++;
      continue;
    }

    final thuis = _toIntMod(data['uitslagThuis']);
    final uit = _toIntMod(data['uitslagUit']);
    final competitie = _asString(data['competitie']);
    final veldnaam = competitie.contains('B') ? 'punten_B' : 'punten_A';

    await verwerkVoorspellingenVoorWedstrijd(
      cleanWedstrijdId,
      thuis,
      uit,
      veldnaam,
    );

    matchesVerwerkt++;
  }

  developer.log(
    '✅ [MOD] Herstel voorspellingen klaar. gevonden=$matchesGevonden verwerkt=$matchesVerwerkt overgeslagen=$matchesOvergeslagen',
  );
}

Future<void> herstelAlleAlgemeneVoorspellingenEnUserTotalen() async {
  developer.log(
    '🛠️ [HERSTEL] Start algemene voorspellingen + usertotalen zonder deadlinefilter',
  );

  final logRef =
      _db.collection('sync_logs').doc('herstel_algemene_voorspellingen_laatste');

  await logRef.set({
    'status': 'running',
    'startedAt': FieldValue.serverTimestamp(),
    'finishedAt': null,
    'message':
        'Herstel algemene voorspellingen loopt zonder harde timestamp deadlinecheck',
  }, SetOptions(merge: true));

  int voorspellingenGezien = 0;
  int voorspellingenBijgewerkt = 0;
  int overgeslagenGeenMatchOfWedstrijdId = 0;
  int overgeslagenGeenUitslag = 0;
  int overgeslagenGeenScore = 0;
  int timestampNaDeadlineAlleenWaarschuwing = 0;
  int usersBijgewerkt = 0;

  try {
    final matchesSnap = await _db.collection('matches').get();
    final usersSnap = await _db.collection('users').get();
    final voorspelPuntenSnap = await _db.collection('voorspel_punten').get();

    final matchesById = <String, Map<String, dynamic>>{
      for (final doc in matchesSnap.docs) doc.id: doc.data(),
    };

    final eindstandByUid = <String, Map<String, dynamic>>{
      for (final doc in voorspelPuntenSnap.docs) doc.id: doc.data(),
    };

    final puntenAByUid = <String, int>{};
    final puntenBByUid = <String, int>{};

    for (final userDoc in usersSnap.docs) {
      puntenAByUid[userDoc.id] = 0;
      puntenBByUid[userDoc.id] = 0;
    }

    WriteBatch batch = _db.batch();
    int batchCount = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (batchCount == 0) return;
      if (!force && batchCount < 430) return;

      await batch.commit();

      batch = _db.batch();
      batchCount = 0;
    }

    Query<Map<String, dynamic>> q = _db
        .collection('voorspellingen')
        .orderBy(FieldPath.documentId)
        .limit(450);

    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        voorspellingenGezien++;

        final data = doc.data();

        if (data['auditIgnored'] == true || data['ongeldig'] == true) {
          continue;
        }

        final uid = _asString(data['gebruikerId']);
        final wedstrijdId = _asString(data['wedstrijdId']);

        if (uid.isEmpty || wedstrijdId.isEmpty) {
          overgeslagenGeenMatchOfWedstrijdId++;
          continue;
        }

        final match = matchesById[wedstrijdId];

        if (match == null) {
          overgeslagenGeenMatchOfWedstrijdId++;
          continue;
        }

        if (!_hasScoreFields(data)) {
          overgeslagenGeenScore++;
          continue;
        }

        if (match['uitslagThuis'] == null || match['uitslagUit'] == null) {
          overgeslagenGeenUitslag++;
          continue;
        }

        if (_timestampLijktNaDeadline(prediction: data, match: match)) {
          timestampNaDeadlineAlleenWaarschuwing++;
        }

        final scoreThuis = _toIntMod(data['scoreThuis']);
        final scoreUit = _toIntMod(data['scoreUit']);
        final uitslagThuis = _toIntMod(match['uitslagThuis']);
        final uitslagUit = _toIntMod(match['uitslagUit']);

        final punten = berekenPunten(
          voorspeldThuis: scoreThuis,
          voorspeldUit: scoreUit,
          echtThuis: uitslagThuis,
          echtUit: uitslagUit,
        );

        final uitslagKey = '$uitslagThuis-$uitslagUit';

        final huidigePunten = data['punten'];
        final huidigePuntenInt = _toIntMod(huidigePunten);
        final huidigeVerwerkt = data['verwerkt'] == true;
        final huidigeUitslag = _asString(data['verwerktVoorUitslag']);

        final moetBijwerken = !huidigeVerwerkt ||
            huidigePunten == null ||
            huidigePuntenInt != punten ||
            huidigeUitslag != uitslagKey;

        if (moetBijwerken) {
          batch.set(
            doc.reference,
            {
              'punten': punten,
              'verwerkt': true,
              'verwerktVoorUitslag': uitslagKey,
              'laatstHersteldAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          batchCount++;
          voorspellingenBijgewerkt++;

          await commitBatchIfNeeded();
        }

        final wedstrijdIdUpper = wedstrijdId.toUpperCase();

        if (wedstrijdIdUpper.startsWith('A')) {
          puntenAByUid[uid] = (puntenAByUid[uid] ?? 0) + punten;
        } else if (wedstrijdIdUpper.startsWith('B')) {
          puntenBByUid[uid] = (puntenBByUid[uid] ?? 0) + punten;
        }
      }

      final last = snap.docs.last;
      q = _db
          .collection('voorspellingen')
          .orderBy(FieldPath.documentId)
          .limit(450)
          .startAfterDocument(last);
    }

    await commitBatchIfNeeded(force: true);

    for (final entry in eindstandByUid.entries) {
      final uid = entry.key;
      final data = entry.value;

      puntenAByUid[uid] =
          (puntenAByUid[uid] ?? 0) + _toIntMod(data['eindstand_A_punten']);
      puntenBByUid[uid] =
          (puntenBByUid[uid] ?? 0) + _toIntMod(data['eindstand_B_punten']);
    }

    WriteBatch userBatch = _db.batch();
    int userBatchCount = 0;

    Future<void> commitUserBatchIfNeeded({bool force = false}) async {
      if (userBatchCount == 0) return;
      if (!force && userBatchCount < 430) return;

      await userBatch.commit();

      userBatch = _db.batch();
      userBatchCount = 0;
    }

    final alleUserIds = <String>{
      ...usersSnap.docs.map((d) => d.id),
      ...puntenAByUid.keys,
      ...puntenBByUid.keys,
    };

    for (final uid in alleUserIds) {
      final puntenA = puntenAByUid[uid] ?? 0;
      final puntenB = puntenBByUid[uid] ?? 0;
      final totalen = puntenA > puntenB ? puntenA : puntenB;

      userBatch.set(
        _db.collection('users').doc(uid),
        {
          'punten_A': puntenA,
          'punten_B': puntenB,
          'totalen': totalen,
          'points': totalen,
          'laatstHerbouwdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      userBatchCount++;
      usersBijgewerkt++;

      await commitUserBatchIfNeeded();
    }

    await commitUserBatchIfNeeded(force: true);

    await logRef.set({
      'status': 'done',
      'finishedAt': FieldValue.serverTimestamp(),
      'message':
          'Herstel algemene voorspellingen afgerond zonder harde timestamp deadlinecheck',
      'summary': {
        'voorspellingenGezien': voorspellingenGezien,
        'voorspellingenBijgewerkt': voorspellingenBijgewerkt,
        'overgeslagenGeenMatchOfWedstrijdId': overgeslagenGeenMatchOfWedstrijdId,
        'overgeslagenGeenUitslag': overgeslagenGeenUitslag,
        'overgeslagenGeenScore': overgeslagenGeenScore,
        'timestampNaDeadlineAlleenWaarschuwing':
            timestampNaDeadlineAlleenWaarschuwing,
        'overgeslagenDeadline': 0,
        'usersBijgewerkt': usersBijgewerkt,
      },
    }, SetOptions(merge: true));

    developer.log(
      '✅ [HERSTEL] Klaar. gezien=$voorspellingenGezien bijgewerkt=$voorspellingenBijgewerkt users=$usersBijgewerkt timestampNaDeadline=$timestampNaDeadlineAlleenWaarschuwing',
    );
  } catch (e, st) {
    await logRef.set({
      'status': 'failed',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Herstel algemene voorspellingen mislukt: $e',
      'summary': {
        'voorspellingenGezien': voorspellingenGezien,
        'voorspellingenBijgewerkt': voorspellingenBijgewerkt,
        'overgeslagenGeenMatchOfWedstrijdId': overgeslagenGeenMatchOfWedstrijdId,
        'overgeslagenGeenUitslag': overgeslagenGeenUitslag,
        'overgeslagenGeenScore': overgeslagenGeenScore,
        'timestampNaDeadlineAlleenWaarschuwing':
            timestampNaDeadlineAlleenWaarschuwing,
        'overgeslagenDeadline': 0,
        'usersBijgewerkt': usersBijgewerkt,
      },
    }, SetOptions(merge: true));

    developer.log(
      '❌ [HERSTEL] Algemene voorspellingen mislukt',
      error: e,
      stackTrace: st,
    );

    rethrow;
  }
}

Future<void> markeerVoorspellingenZonderWedstrijdIdOngeldig() async {
  developer.log('🧹 [HERSTEL] Start markeren voorspellingen zonder wedstrijdId');

  final logRef = _db
      .collection('sync_logs')
      .doc('markeer_voorspellingen_zonder_wedstrijd_laatste');

  await logRef.set({
    'status': 'running',
    'startedAt': FieldValue.serverTimestamp(),
    'finishedAt': null,
    'message': 'Markeren loopt',
  }, SetOptions(merge: true));

  int gezien = 0;
  int gemarkeerd = 0;

  try {
    WriteBatch batch = _db.batch();
    int batchCount = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (batchCount == 0) return;
      if (!force && batchCount < 430) return;

      await batch.commit();

      batch = _db.batch();
      batchCount = 0;
    }

    Query<Map<String, dynamic>> q = _db
        .collection('voorspellingen')
        .orderBy(FieldPath.documentId)
        .limit(450);

    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        gezien++;

        final data = doc.data();
        final wedstrijdId = _asString(data['wedstrijdId']);

        if (wedstrijdId.isNotEmpty) continue;

        batch.set(
          doc.reference,
          {
            'ongeldig': true,
            'auditIgnored': true,
            'redenOngeldig': 'ontbrekende wedstrijdId',
            'gemarkeerdOngeldigAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        batchCount++;
        gemarkeerd++;

        await commitIfNeeded();
      }

      final last = snap.docs.last;
      q = _db
          .collection('voorspellingen')
          .orderBy(FieldPath.documentId)
          .limit(450)
          .startAfterDocument(last);
    }

    await commitIfNeeded(force: true);

    await logRef.set({
      'status': 'done',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Voorspellingen zonder wedstrijdId gemarkeerd',
      'summary': {
        'gezien': gezien,
        'gemarkeerd': gemarkeerd,
      },
    }, SetOptions(merge: true));
  } catch (e, st) {
    await logRef.set({
      'status': 'failed',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Markeren mislukt: $e',
      'summary': {
        'gezien': gezien,
        'gemarkeerd': gemarkeerd,
      },
    }, SetOptions(merge: true));

    developer.log(
      '❌ [HERSTEL] Markeren voorspellingen zonder wedstrijdId mislukt',
      error: e,
      stackTrace: st,
    );

    rethrow;
  }
}

Future<void> herstelAllePoulePunten() async {
  developer.log('🛠️ [HERSTEL] Start herstel alle poulepunten');

  final logRef = _db.collection('sync_logs').doc('herstel_poulepunten_laatste');

  await logRef.set({
    'status': 'running',
    'startedAt': FieldValue.serverTimestamp(),
    'finishedAt': null,
    'message': 'Herstel poulepunten loopt zonder harde timestamp deadlinecheck',
  }, SetOptions(merge: true));

  int voorspellingenGezien = 0;
  int voorspellingenBijgewerkt = 0;
  int deelnemersBijgewerkt = 0;
  int overgeslagenOnvolledig = 0;
  int overgeslagenGeenMatch = 0;
  int overgeslagenGeenUitslag = 0;
  int overgeslagenGeenScore = 0;
  int timestampNaDeadlineAlleenWaarschuwing = 0;

  try {
    final matchesSnap = await _db.collection('matches').get();
    final poulesSnap = await _db.collection('poules').get();

    final matchesById = <String, Map<String, dynamic>>{
      for (final doc in matchesSnap.docs) doc.id: doc.data(),
    };

    final expectedPoulePoints = <String, Map<String, int>>{};

    for (final pouleDoc in poulesSnap.docs) {
      final pouleId = pouleDoc.id;
      expectedPoulePoints[pouleId] = {};

      final deelnemersSnap =
          await pouleDoc.reference.collection('deelnemers').get();

      for (final deelnemerDoc in deelnemersSnap.docs) {
        expectedPoulePoints[pouleId]![deelnemerDoc.id] = 0;
      }
    }

    WriteBatch predBatch = _db.batch();
    int predBatchCount = 0;

    Future<void> commitPredIfNeeded({bool force = false}) async {
      if (predBatchCount == 0) return;
      if (!force && predBatchCount < 430) return;

      await predBatch.commit();

      predBatch = _db.batch();
      predBatchCount = 0;
    }

    for (final collectie in [
      'poule_predictions',
      'poule_voorspellingen',
      'predictions',
    ]) {
      final snap = await _db.collection(collectie).get();

      final grouped = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      final groupedTs = <String, int>{};

      for (final doc in snap.docs) {
        voorspellingenGezien++;

        final data = doc.data();
        final pouleId = _asString(data['pouleId'] ?? data['poule']);
        final uid = _asString(data['gebruikerId'] ?? data['userId'] ?? data['uid']);
        final matchId = _asString(data['matchId'] ?? data['wedstrijdId']);

        if (pouleId.isEmpty || uid.isEmpty || matchId.isEmpty) {
          overgeslagenOnvolledig++;
          continue;
        }

        final match = matchesById[matchId];

        if (match == null) {
          overgeslagenGeenMatch++;
          continue;
        }

        if (match['uitslagThuis'] == null || match['uitslagUit'] == null) {
          overgeslagenGeenUitslag++;
          continue;
        }

        if (!_hasScoreFields(data)) {
          overgeslagenGeenScore++;
          continue;
        }

        if (_timestampLijktNaDeadline(prediction: data, match: match)) {
          timestampNaDeadlineAlleenWaarschuwing++;
        }

        final ts = (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final key = '$collectie|$pouleId|$uid|$matchId';

        if (!grouped.containsKey(key) || ts >= (groupedTs[key] ?? -1)) {
          grouped[key] = doc;
          groupedTs[key] = ts;
        }
      }

      for (final doc in grouped.values) {
        final data = doc.data();

        final pouleId = _asString(data['pouleId'] ?? data['poule']);
        final uid = _asString(data['gebruikerId'] ?? data['userId'] ?? data['uid']);
        final matchId = _asString(data['matchId'] ?? data['wedstrijdId']);

        final match = matchesById[matchId];

        if (match == null) continue;
        if (!_hasScoreFields(data)) continue;
        if (match['uitslagThuis'] == null || match['uitslagUit'] == null) {
          continue;
        }

        final scoreThuis = _toIntMod(data['scoreThuis']);
        final scoreUit = _toIntMod(data['scoreUit']);
        final uitslagThuis = _toIntMod(match['uitslagThuis']);
        final uitslagUit = _toIntMod(match['uitslagUit']);

        final punten = berekenPunten(
          voorspeldThuis: scoreThuis,
          voorspeldUit: scoreUit,
          echtThuis: uitslagThuis,
          echtUit: uitslagUit,
        );

        final uitslagKey = '$uitslagThuis-$uitslagUit';

        final huidigePunten = data['punten'];
        final huidigePuntenInt = _toIntMod(huidigePunten);
        final huidigeVerwerkt = data['verwerkt'] == true;
        final huidigeUitslag = _asString(data['verwerktVoorUitslag']);

        final moetBijwerken = !huidigeVerwerkt ||
            huidigePunten == null ||
            huidigePuntenInt != punten ||
            huidigeUitslag != uitslagKey;

        if (moetBijwerken) {
          predBatch.set(
            doc.reference,
            {
              'punten': punten,
              'verwerkt': true,
              'verwerktVoorUitslag': uitslagKey,
              'laatstHersteldAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          predBatchCount++;
          voorspellingenBijgewerkt++;

          await commitPredIfNeeded();
        }

        expectedPoulePoints.putIfAbsent(pouleId, () => {});
        expectedPoulePoints[pouleId]![uid] =
            (expectedPoulePoints[pouleId]![uid] ?? 0) + punten;
      }

      await commitPredIfNeeded(force: true);
    }

    WriteBatch deelnemersBatch = _db.batch();
    int deelnemersBatchCount = 0;

    Future<void> commitDeelnemersIfNeeded({bool force = false}) async {
      if (deelnemersBatchCount == 0) return;
      if (!force && deelnemersBatchCount < 430) return;

      await deelnemersBatch.commit();

      deelnemersBatch = _db.batch();
      deelnemersBatchCount = 0;
    }

    for (final pouleDoc in poulesSnap.docs) {
      final pouleId = pouleDoc.id;
      final deelnemersSnap =
          await pouleDoc.reference.collection('deelnemers').get();

      for (final deelnemerDoc in deelnemersSnap.docs) {
        final uid = deelnemerDoc.id;
        final expected = expectedPoulePoints[pouleId]?[uid] ?? 0;
        final current = _toIntMod(deelnemerDoc.data()['punten']);

        if (current == expected) continue;

        deelnemersBatch.set(
          deelnemerDoc.reference,
          {
            'punten': expected,
            'laatstHerbouwdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        deelnemersBatchCount++;
        deelnemersBijgewerkt++;

        await commitDeelnemersIfNeeded();
      }
    }

    await commitDeelnemersIfNeeded(force: true);

    await logRef.set({
      'status': 'done',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Herstel poulepunten afgerond',
      'summary': {
        'voorspellingenGezien': voorspellingenGezien,
        'voorspellingenBijgewerkt': voorspellingenBijgewerkt,
        'deelnemersBijgewerkt': deelnemersBijgewerkt,
        'overgeslagenOnvolledig': overgeslagenOnvolledig,
        'overgeslagenGeenMatch': overgeslagenGeenMatch,
        'overgeslagenGeenUitslag': overgeslagenGeenUitslag,
        'overgeslagenGeenScore': overgeslagenGeenScore,
        'timestampNaDeadlineAlleenWaarschuwing':
            timestampNaDeadlineAlleenWaarschuwing,
        'overgeslagenDeadline': 0,
      },
    }, SetOptions(merge: true));
  } catch (e, st) {
    await logRef.set({
      'status': 'failed',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Herstel poulepunten mislukt: $e',
      'summary': {
        'voorspellingenGezien': voorspellingenGezien,
        'voorspellingenBijgewerkt': voorspellingenBijgewerkt,
        'deelnemersBijgewerkt': deelnemersBijgewerkt,
        'overgeslagenOnvolledig': overgeslagenOnvolledig,
        'overgeslagenGeenMatch': overgeslagenGeenMatch,
        'overgeslagenGeenUitslag': overgeslagenGeenUitslag,
        'overgeslagenGeenScore': overgeslagenGeenScore,
        'timestampNaDeadlineAlleenWaarschuwing':
            timestampNaDeadlineAlleenWaarschuwing,
        'overgeslagenDeadline': 0,
      },
    }, SetOptions(merge: true));

    developer.log(
      '❌ [HERSTEL] Poulepunten mislukt',
      error: e,
      stackTrace: st,
    );

    rethrow;
  }
}

Future<void> herstelAllePeriodestanden() async {
  developer.log('🛠️ [HERSTEL] Start herstel periodestanden');

  final logRef =
      _db.collection('sync_logs').doc('herstel_periodestanden_laatste');

  await logRef.set({
    'status': 'running',
    'startedAt': FieldValue.serverTimestamp(),
    'finishedAt': null,
    'message': 'Herstel periodestanden loopt',
  }, SetOptions(merge: true));

  int docsGeschreven = 0;

  try {
    final matchesSnap = await _db.collection('matches').get();

    final matchesById = <String, Map<String, dynamic>>{
      for (final doc in matchesSnap.docs) doc.id: doc.data(),
    };

    for (final divisieCode in ['A', 'B']) {
      for (int periode = 1; periode <= 3; periode++) {
        final expected = _berekenPeriodeStand(
          divisieCode: divisieCode,
          periode: periode,
          matchesById: matchesById,
        );

        final divisieDocId = divisieCode == 'A' ? 'dda' : 'ddb';

        final collectionRef = _db
            .collection('periodestanden')
            .doc(divisieDocId)
            .collection('periode_$periode');

        await _deleteCollectionDocs(collectionRef);

        WriteBatch batch = _db.batch();
        int batchCount = 0;

        Future<void> commitIfNeeded({bool force = false}) async {
          if (batchCount == 0) return;
          if (!force && batchCount < 430) return;

          await batch.commit();

          batch = _db.batch();
          batchCount = 0;
        }

        for (final entry in expected.entries) {
          final club = entry.key;
          final stats = entry.value;

          final docRef = collectionRef.doc(_normAudit(club));

          batch.set(docRef, {
            'club': club,
            'competitie':
                divisieCode == 'A' ? 'Derde Divisie A' : 'Derde Divisie B',
            'divisie': divisieDocId,
            'periode': periode,
            'gespeeld': stats['gespeeld'] ?? 0,
            'gewonnen': stats['gewonnen'] ?? 0,
            'gelijk': stats['gelijk'] ?? 0,
            'verloren': stats['verloren'] ?? 0,
            'doelpuntenVoor': stats['doelpuntenVoor'] ?? 0,
            'doelpuntenTegen': stats['doelpuntenTegen'] ?? 0,
            'doelsaldo': stats['doelsaldo'] ?? 0,
            'punten': stats['punten'] ?? 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          docsGeschreven++;
          batchCount++;

          await commitIfNeeded();
        }

        await commitIfNeeded(force: true);
      }
    }

    await logRef.set({
      'status': 'done',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Herstel periodestanden afgerond',
      'summary': {
        'docsGeschreven': docsGeschreven,
      },
    }, SetOptions(merge: true));
  } catch (e, st) {
    await logRef.set({
      'status': 'failed',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Herstel periodestanden mislukt: $e',
      'summary': {
        'docsGeschreven': docsGeschreven,
      },
    }, SetOptions(merge: true));

    developer.log(
      '❌ [HERSTEL] Periodestanden mislukt',
      error: e,
      stackTrace: st,
    );

    rethrow;
  }
}

Future<void> voerVolledigeEindcontroleAuditUit() async {
  developer.log('🔎 [AUDIT] Start volledige eindcontrole');

  final auditRef = _db.collection('sync_logs').doc('eindcontrole_laatste');
  final issuesRef = auditRef.collection('issues');

  await auditRef.set({
    'status': 'running',
    'startedAt': FieldValue.serverTimestamp(),
    'finishedAt': null,
    'message': 'Audit loopt',
  }, SetOptions(merge: true));

  await _deleteCollectionDocs(issuesRef);

  final writer = _AuditWriter(auditRef);

  int usersCount = 0;
  int matchesCount = 0;
  int voorspellingenCount = 0;
  int poulesCount = 0;
  int pouleDeelnemersCount = 0;
  int eindstandVoorspellingenCount = 0;

  try {
    final usersSnap = await _db.collection('users').get();
    final matchesSnap = await _db.collection('matches').get();
    final voorspellingenSnap = await _db.collection('voorspellingen').get();
    final voorspelPuntenSnap = await _db.collection('voorspel_punten').get();
    final eindstandVoorspellingenSnap =
        await _db.collection('eindstand_voorspellingen').get();
    final standenSnap = await _db.collection('standen').get();
    final poulesSnap = await _db.collection('poules').get();

    usersCount = usersSnap.docs.length;
    matchesCount = matchesSnap.docs.length;
    voorspellingenCount = voorspellingenSnap.docs.length;
    poulesCount = poulesSnap.docs.length;
    eindstandVoorspellingenCount = eindstandVoorspellingenSnap.docs.length;

    final usersById = <String, Map<String, dynamic>>{
      for (final d in usersSnap.docs) d.id: d.data(),
    };

    String usernameFor(String uid) {
      final u = usersById[uid];
      return _asString(u?['username'] ?? u?['displayName'] ?? uid);
    }

    final matchesById = <String, Map<String, dynamic>>{
      for (final d in matchesSnap.docs) d.id: d.data(),
    };

    final voorspelPuntenByUid = <String, Map<String, dynamic>>{
      for (final d in voorspelPuntenSnap.docs) d.id: d.data(),
    };

    final expectedUserA = <String, int>{};
    final expectedUserB = <String, int>{};

    for (final doc in voorspellingenSnap.docs) {
      final p = doc.data();

      final uid = _asString(p['gebruikerId']);
      final wedstrijdId = _asString(p['wedstrijdId']);

      if (p['auditIgnored'] == true || p['ongeldig'] == true) {
        await writer.addIssue(
          severity: 'warning',
          type: 'VOORSPELLING_GEMARKEERD_ONGELDIG',
          message:
              'Voorspelling is gemarkeerd als ongeldig en telt niet mee.',
          uid: uid.isEmpty ? null : uid,
          username: uid.isEmpty ? null : usernameFor(uid),
          wedstrijdId: wedstrijdId.isEmpty ? null : wedstrijdId,
          documentPath: doc.reference.path,
          details: {
            'redenOngeldig': _asString(p['redenOngeldig']),
          },
        );
        continue;
      }

      if (uid.isEmpty) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VOORSPELLING_ZONDER_GEBRUIKER',
          message: 'Voorspelling heeft geen gebruikerId.',
          documentPath: doc.reference.path,
        );
        continue;
      }

      if (wedstrijdId.isEmpty) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VOORSPELLING_ZONDER_WEDSTRIJD',
          message: 'Voorspelling heeft geen wedstrijdId.',
          uid: uid,
          username: usernameFor(uid),
          documentPath: doc.reference.path,
        );
        continue;
      }

      final match = matchesById[wedstrijdId];

      if (match == null) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VOORSPELLING_MATCH_ONTBREEKT',
          message: 'Voorspelling verwijst naar een wedstrijd die niet bestaat.',
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: wedstrijdId,
          documentPath: doc.reference.path,
        );
        continue;
      }

      if (!_hasScoreFields(p)) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VOORSPELLING_SCORE_ONTBREEKT',
          message: 'Voorspelling mist scoreThuis of scoreUit.',
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: wedstrijdId,
          documentPath: doc.reference.path,
        );
        continue;
      }

      if (match['uitslagThuis'] == null || match['uitslagUit'] == null) {
        if (p['verwerkt'] == true || p['punten'] != null) {
          await writer.addIssue(
            severity: 'warning',
            type: 'VOORSPELLING_VERWERKT_ZONDER_UITSLAG',
            message:
                'Voorspelling is verwerkt terwijl de wedstrijd geen volledige uitslag heeft.',
            uid: uid,
            username: usernameFor(uid),
            wedstrijdId: wedstrijdId,
            documentPath: doc.reference.path,
          );
        }
        continue;
      }

      if (_timestampLijktNaDeadline(prediction: p, match: match)) {
        await writer.addIssue(
          severity: 'warning',
          type: 'VOORSPELLING_TIMESTAMP_NA_DEADLINE',
          message:
              'Timestamp ligt na deadline, maar wordt niet gebruikt om punten af te keuren.',
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: wedstrijdId,
          documentPath: doc.reference.path,
        );
      }

      final scoreThuis = _toIntMod(p['scoreThuis']);
      final scoreUit = _toIntMod(p['scoreUit']);
      final uitslagThuis = _toIntMod(match['uitslagThuis']);
      final uitslagUit = _toIntMod(match['uitslagUit']);

      final expectedPoints = berekenPunten(
        voorspeldThuis: scoreThuis,
        voorspeldUit: scoreUit,
        echtThuis: uitslagThuis,
        echtUit: uitslagUit,
      );

      final actualPoints = p['punten'];
      final actualPointsInt = _toIntMod(actualPoints);
      final expectedUitslag = '$uitslagThuis-$uitslagUit';
      final actualUitslag = _asString(p['verwerktVoorUitslag']);

      if (p['verwerkt'] != true) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VOORSPELLING_NIET_VERWERKT',
          message:
              'Voorspelling is geldig en wedstrijd heeft uitslag, maar verwerkt staat niet op true.',
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: wedstrijdId,
          expected: true,
          actual: p['verwerkt'],
          documentPath: doc.reference.path,
        );
      }

      if (actualPoints == null || actualPointsInt != expectedPoints) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VOORSPELLING_PUNTEN_FOUT',
          message: 'Opgeslagen punten wijken af van opnieuw berekende punten.',
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: wedstrijdId,
          expected: expectedPoints,
          actual: actualPoints,
          difference: actualPointsInt - expectedPoints,
          documentPath: doc.reference.path,
          details: {
            'voorspelling': '$scoreThuis-$scoreUit',
            'uitslag': expectedUitslag,
          },
        );
      }

      if (actualUitslag != expectedUitslag) {
        await writer.addIssue(
          severity: 'critical',
          type: 'VERWERKT_VOOR_UITSLAG_FOUT',
          message: 'verwerktVoorUitslag komt niet overeen met de echte uitslag.',
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: wedstrijdId,
          expected: expectedUitslag,
          actual: actualUitslag,
          documentPath: doc.reference.path,
        );
      }

      final wedstrijdIdUpper = wedstrijdId.toUpperCase();

      if (wedstrijdIdUpper.startsWith('A')) {
        expectedUserA[uid] = (expectedUserA[uid] ?? 0) + expectedPoints;
      } else if (wedstrijdIdUpper.startsWith('B')) {
        expectedUserB[uid] = (expectedUserB[uid] ?? 0) + expectedPoints;
      }
    }

    for (final uid in usersById.keys) {
      expectedUserA.putIfAbsent(uid, () => 0);
      expectedUserB.putIfAbsent(uid, () => 0);
    }

    for (final entry in voorspelPuntenByUid.entries) {
      final uid = entry.key;
      final data = entry.value;

      expectedUserA[uid] =
          (expectedUserA[uid] ?? 0) + _toIntMod(data['eindstand_A_punten']);
      expectedUserB[uid] =
          (expectedUserB[uid] ?? 0) + _toIntMod(data['eindstand_B_punten']);
    }

    for (final userDoc in usersSnap.docs) {
      final uid = userDoc.id;
      final u = userDoc.data();

      final expA = expectedUserA[uid] ?? 0;
      final expB = expectedUserB[uid] ?? 0;
      final expTotalen = expA > expB ? expA : expB;

      final actA = _toIntMod(u['punten_A']);
      final actB = _toIntMod(u['punten_B']);
      final actTotalen = _toIntMod(u['totalen']);
      final actPoints = _toIntMod(u['points']);

      final username = usernameFor(uid);

      if (actA != expA) {
        await writer.addIssue(
          severity: 'critical',
          type: 'USER_PUNTEN_A_FOUT',
          message: 'users.punten_A wijkt af van auditberekening.',
          uid: uid,
          username: username,
          expected: expA,
          actual: actA,
          difference: actA - expA,
          documentPath: userDoc.reference.path,
        );
      }

      if (actB != expB) {
        await writer.addIssue(
          severity: 'critical',
          type: 'USER_PUNTEN_B_FOUT',
          message: 'users.punten_B wijkt af van auditberekening.',
          uid: uid,
          username: username,
          expected: expB,
          actual: actB,
          difference: actB - expB,
          documentPath: userDoc.reference.path,
        );
      }

      if (actTotalen != expTotalen) {
        await writer.addIssue(
          severity: 'critical',
          type: 'USER_TOTALEN_FOUT',
          message: 'users.totalen is niet gelijk aan hoogste van A en B.',
          uid: uid,
          username: username,
          expected: expTotalen,
          actual: actTotalen,
          difference: actTotalen - expTotalen,
          documentPath: userDoc.reference.path,
        );
      }

      if (u.containsKey('points') && actPoints != expTotalen) {
        await writer.addIssue(
          severity: 'warning',
          type: 'USER_POINTS_FOUT',
          message: 'users.points wijkt af van users.totalen.',
          uid: uid,
          username: username,
          expected: expTotalen,
          actual: actPoints,
          difference: actPoints - expTotalen,
          documentPath: userDoc.reference.path,
        );
      }
    }

    await _auditEindstandpunten(
      writer: writer,
      usersById: usersById,
      matchesById: matchesById,
      voorspelPuntenByUid: voorspelPuntenByUid,
      eindstandVoorspellingenSnap: eindstandVoorspellingenSnap,
    );

    await _auditStanden(
      writer: writer,
      matchesById: matchesById,
      standenSnap: standenSnap,
    );

    await _auditPeriodestanden(
      writer: writer,
      matchesById: matchesById,
    );

    pouleDeelnemersCount = await _auditPoules(
      writer: writer,
      matchesById: matchesById,
      usersById: usersById,
      poulesSnap: poulesSnap,
    );

    await writer.flush();

    await auditRef.set({
      'status': writer.critical == 0 ? 'ok' : 'issues_found',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': writer.critical == 0
          ? 'Audit afgerond zonder kritieke fouten'
          : 'Audit afgerond met kritieke fouten',
      'summary': {
        'critical': writer.critical,
        'warnings': writer.warnings,
        'issues': writer.issues,
        'criticalByType': writer.criticalByType,
        'warningByType': writer.warningByType,
        'issuesByType': writer.issuesByType,
        'users': usersCount,
        'matches': matchesCount,
        'voorspellingen': voorspellingenCount,
        'poules': poulesCount,
        'pouleDeelnemers': pouleDeelnemersCount,
        'eindstandVoorspellingen': eindstandVoorspellingenCount,
      },
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    developer.log(
      '✅ [AUDIT] Klaar critical=${writer.critical}, warnings=${writer.warnings}',
    );
  } catch (e, st) {
    await writer.flush();

    await auditRef.set({
      'status': 'failed',
      'finishedAt': FieldValue.serverTimestamp(),
      'message': 'Audit mislukt: $e',
      'summary': {
        'critical': writer.critical,
        'warnings': writer.warnings,
        'issues': writer.issues,
        'criticalByType': writer.criticalByType,
        'warningByType': writer.warningByType,
        'issuesByType': writer.issuesByType,
        'users': usersCount,
        'matches': matchesCount,
        'voorspellingen': voorspellingenCount,
        'poules': poulesCount,
        'pouleDeelnemers': pouleDeelnemersCount,
        'eindstandVoorspellingen': eindstandVoorspellingenCount,
      },
    }, SetOptions(merge: true));

    developer.log('❌ [AUDIT] Mislukt', error: e, stackTrace: st);

    rethrow;
  }
}

Future<void> _auditEindstandpunten({
  required _AuditWriter writer,
  required Map<String, Map<String, dynamic>> usersById,
  required Map<String, Map<String, dynamic>> matchesById,
  required Map<String, Map<String, dynamic>> voorspelPuntenByUid,
  required QuerySnapshot<Map<String, dynamic>> eindstandVoorspellingenSnap,
}) async {
  final rankings = <String, Map<String, int>>{
    'A': _berekenEindstandRanking('A', matchesById),
    'B': _berekenEindstandRanking('B', matchesById),
  };

  String usernameFor(String uid) {
    final u = usersById[uid];
    return _asString(u?['username'] ?? u?['displayName'] ?? uid);
  }

  for (final doc in eindstandVoorspellingenSnap.docs) {
    final data = doc.data();

    final divisie = _asString(data['divisie']).toUpperCase();
    final uid = _asString(data['gebruikerId']);

    if (uid.isEmpty || (divisie != 'A' && divisie != 'B')) {
      await writer.addIssue(
        severity: 'warning',
        type: 'EINDSTAND_VOORSPELLING_ONVOLLEDIG',
        message: 'Eindstandvoorspelling mist gebruikerId of geldige divisie.',
        documentPath: doc.reference.path,
      );
      continue;
    }

    final voorspellingRaw = data['voorspelling'];
    final voorspelling = voorspellingRaw is List
        ? voorspellingRaw.map((e) => e.toString()).toList()
        : <String>[];

    final expected = _berekenEindstandPuntenVoorVoorspelling(
      voorspelling: voorspelling,
      rankingByNorm: rankings[divisie] ?? {},
    );

    final markerVeld = 'eindstand_${divisie}_punten';

    final actualDoc = _toIntMod(data[markerVeld]);
    final actualAlt = divisie == 'A'
        ? _toIntMod(data['eindstand_A_punten'])
        : _toIntMod(data['eindstand_B_punten']);

    final voorspelPunten = voorspelPuntenByUid[uid] ?? {};
    final actualVoorspelPunten = _toIntMod(voorspelPunten[markerVeld]);

    if (actualDoc != expected || actualAlt != expected) {
      await writer.addIssue(
        severity: 'critical',
        type: 'EINDSTAND_DOC_PUNTEN_FOUT',
        message: 'Punten op eindstand_voorspellingen wijken af.',
        uid: uid,
        username: usernameFor(uid),
        divisie: divisie,
        expected: expected,
        actual: actualDoc,
        difference: actualDoc - expected,
        documentPath: doc.reference.path,
      );
    }

    if (actualVoorspelPunten != expected) {
      await writer.addIssue(
        severity: 'critical',
        type: 'VOORSPEL_PUNTEN_EINDSTAND_FOUT',
        message: 'Punten in voorspel_punten wijken af van auditberekening.',
        uid: uid,
        username: usernameFor(uid),
        divisie: divisie,
        expected: expected,
        actual: actualVoorspelPunten,
        difference: actualVoorspelPunten - expected,
        documentPath: 'voorspel_punten/$uid',
      );
    }
  }
}

Map<String, int> _berekenEindstandRanking(
  String divisie,
  Map<String, Map<String, dynamic>> matchesById,
) {
  final competitieNaam = 'Derde Divisie $divisie';
  final stats = <String, Map<String, int>>{};

  void init(String clubNorm) {
    stats.putIfAbsent(clubNorm, () {
      return {
        'punten': 0,
        'doelsaldo': 0,
        'gespeeld': 0,
        'doelpuntenVoor': 0,
      };
    });
  }

  for (final match in matchesById.values) {
    if (_asString(match['competitie']) != competitieNaam) continue;
    if (match['uitslagThuis'] == null || match['uitslagUit'] == null) continue;

    final homeRaw = _asString(match['thuisteam']);
    final awayRaw = _asString(match['uitteam']);

    if (homeRaw.isEmpty || awayRaw.isEmpty) continue;

    final home = _normAudit(homeRaw);
    final away = _normAudit(awayRaw);

    final h = _toIntMod(match['uitslagThuis']);
    final a = _toIntMod(match['uitslagUit']);

    init(home);
    init(away);

    stats[home]!['gespeeld'] = stats[home]!['gespeeld']! + 1;
    stats[away]!['gespeeld'] = stats[away]!['gespeeld']! + 1;

    stats[home]!['doelpuntenVoor'] = stats[home]!['doelpuntenVoor']! + h;
    stats[away]!['doelpuntenVoor'] = stats[away]!['doelpuntenVoor']! + a;

    stats[home]!['doelsaldo'] = stats[home]!['doelsaldo']! + (h - a);
    stats[away]!['doelsaldo'] = stats[away]!['doelsaldo']! + (a - h);

    if (h > a) {
      stats[home]!['punten'] = stats[home]!['punten']! + 3;
    } else if (h < a) {
      stats[away]!['punten'] = stats[away]!['punten']! + 3;
    } else {
      stats[home]!['punten'] = stats[home]!['punten']! + 1;
      stats[away]!['punten'] = stats[away]!['punten']! + 1;
    }
  }

  final sorted = stats.entries.toList()
    ..sort((a, b) {
      final av = (a.value['punten']! * 1000000) +
          ((1000 - a.value['gespeeld']!) * 10000) +
          (a.value['doelsaldo']! * 100) +
          a.value['doelpuntenVoor']!;
      final bv = (b.value['punten']! * 1000000) +
          ((1000 - b.value['gespeeld']!) * 10000) +
          (b.value['doelsaldo']! * 100) +
          b.value['doelpuntenVoor']!;

      return bv.compareTo(av);
    });

  return {
    for (int i = 0; i < sorted.length; i++) sorted[i].key: i,
  };
}

int _berekenEindstandPuntenVoorVoorspelling({
  required List<String> voorspelling,
  required Map<String, int> rankingByNorm,
}) {
  int punten = 0;

  for (int i = 0; i < voorspelling.length; i++) {
    final clubNorm = _normAudit(voorspelling[i]);
    final echteIndex = rankingByNorm[clubNorm];

    if (echteIndex == null) continue;

    if (echteIndex == 0 && i == 0) {
      punten += 30;
    } else if (echteIndex == i) {
      punten += 10;
    } else if ((echteIndex - i).abs() == 1) {
      punten += 6;
    } else if ((echteIndex - i).abs() == 2) {
      punten += 2;
    }
  }

  return punten;
}

Future<void> _auditStanden({
  required _AuditWriter writer,
  required Map<String, Map<String, dynamic>> matchesById,
  required QuerySnapshot<Map<String, dynamic>> standenSnap,
}) async {
  final expectedByDivisieClub = <String, Map<String, Map<String, int>>>{};

  Map<String, int> initStats() {
    return {
      'gespeeld': 0,
      'gewonnen': 0,
      'gelijk': 0,
      'verloren': 0,
      'doelpuntenVoor': 0,
      'doelpuntenTegen': 0,
      'punten': 0,
      'doelsaldo': 0,
    };
  }

  for (final match in matchesById.values) {
    final competitie = _asString(match['competitie']);

    if (competitie.isEmpty) continue;
    if (match['uitslagThuis'] == null || match['uitslagUit'] == null) continue;

    final home = _asString(match['thuisteam']);
    final away = _asString(match['uitteam']);

    if (home.isEmpty || away.isEmpty) continue;

    final h = _toIntMod(match['uitslagThuis']);
    final a = _toIntMod(match['uitslagUit']);

    expectedByDivisieClub.putIfAbsent(competitie, () => {});

    final divStats = expectedByDivisieClub[competitie]!;

    divStats.putIfAbsent(home, initStats);
    divStats.putIfAbsent(away, initStats);

    final homeStats = divStats[home]!;
    final awayStats = divStats[away]!;

    homeStats['gespeeld'] = homeStats['gespeeld']! + 1;
    awayStats['gespeeld'] = awayStats['gespeeld']! + 1;

    homeStats['doelpuntenVoor'] = homeStats['doelpuntenVoor']! + h;
    homeStats['doelpuntenTegen'] = homeStats['doelpuntenTegen']! + a;
    awayStats['doelpuntenVoor'] = awayStats['doelpuntenVoor']! + a;
    awayStats['doelpuntenTegen'] = awayStats['doelpuntenTegen']! + h;

    if (h > a) {
      homeStats['gewonnen'] = homeStats['gewonnen']! + 1;
      homeStats['punten'] = homeStats['punten']! + 3;
      awayStats['verloren'] = awayStats['verloren']! + 1;
    } else if (a > h) {
      awayStats['gewonnen'] = awayStats['gewonnen']! + 1;
      awayStats['punten'] = awayStats['punten']! + 3;
      homeStats['verloren'] = homeStats['verloren']! + 1;
    } else {
      homeStats['gelijk'] = homeStats['gelijk']! + 1;
      awayStats['gelijk'] = awayStats['gelijk']! + 1;
      homeStats['punten'] = homeStats['punten']! + 1;
      awayStats['punten'] = awayStats['punten']! + 1;
    }
  }

  for (final divStats in expectedByDivisieClub.values) {
    for (final s in divStats.values) {
      s['doelsaldo'] = s['doelpuntenVoor']! - s['doelpuntenTegen']!;
    }
  }

  final actualByCompetitieClub = <String, Map<String, Map<String, dynamic>>>{};
  final actualPathByCompetitieClub = <String, Map<String, String>>{};

  for (final doc in standenSnap.docs) {
    final data = doc.data();

    final competitie = _asString(data['competitie']);
    final club = _asString(data['club']);

    if (competitie.isEmpty || club.isEmpty) continue;

    actualByCompetitieClub.putIfAbsent(competitie, () => {});
    actualPathByCompetitieClub.putIfAbsent(competitie, () => {});

    actualByCompetitieClub[competitie]![club] = data;
    actualPathByCompetitieClub[competitie]![club] = doc.reference.path;
  }

  for (final compEntry in expectedByDivisieClub.entries) {
    final competitie = compEntry.key;

    for (final clubEntry in compEntry.value.entries) {
      final club = clubEntry.key;
      final expected = clubEntry.value;
      final actual = actualByCompetitieClub[competitie]?[club];

      if (actual == null) {
        await writer.addIssue(
          severity: 'critical',
          type: 'STAND_CLUB_ONTBREEKT',
          message: 'Club ontbreekt in standen.',
          club: club,
          divisie: competitie,
          expected: expected,
        );
        continue;
      }

      for (final field in expected.keys) {
        final actualValue = field == 'doelsaldo'
            ? _toIntMod(
                actual['doelsaldo'] ??
                    (_toIntMod(actual['doelpuntenVoor']) -
                        _toIntMod(actual['doelpuntenTegen'])),
              )
            : _toIntMod(actual[field]);

        final expectedValue = expected[field] ?? 0;

        if (actualValue != expectedValue) {
          await writer.addIssue(
            severity: 'critical',
            type: 'STAND_VELD_FOUT',
            message: 'Standveld $field wijkt af.',
            club: club,
            divisie: competitie,
            expected: expectedValue,
            actual: actualValue,
            difference: actualValue - expectedValue,
            documentPath: actualPathByCompetitieClub[competitie]?[club],
          );
        }
      }
    }
  }
}

Future<void> _auditPeriodestanden({
  required _AuditWriter writer,
  required Map<String, Map<String, dynamic>> matchesById,
}) async {
  for (final divisieCode in ['A', 'B']) {
    for (int periode = 1; periode <= 3; periode++) {
      final expected = _berekenPeriodeStand(
        divisieCode: divisieCode,
        periode: periode,
        matchesById: matchesById,
      );

      final divisieDocId = divisieCode == 'A' ? 'dda' : 'ddb';

      final snap = await _db
          .collection('periodestanden')
          .doc(divisieDocId)
          .collection('periode_$periode')
          .get();

      final actualByClub = <String, Map<String, dynamic>>{};
      final actualPathByClub = <String, String>{};

      for (final doc in snap.docs) {
        final data = doc.data();

        final club = _asString(data['club']).isNotEmpty
            ? _asString(data['club'])
            : doc.id;

        actualByClub[club] = data;
        actualPathByClub[club] = doc.reference.path;
      }

      for (final entry in expected.entries) {
        final club = entry.key;
        final expectedStats = entry.value;
        final actual = actualByClub[club];

        if (actual == null) {
          await writer.addIssue(
            severity: 'critical',
            type: 'PERIODESTAND_CLUB_ONTBREEKT',
            message: 'Club ontbreekt in periodestand.',
            club: club,
            divisie: '$divisieDocId periode_$periode',
            expected: expectedStats,
          );
          continue;
        }

        for (final field in expectedStats.keys) {
          final actualValue = _toIntMod(actual[field]);
          final expectedValue = expectedStats[field] ?? 0;

          if (actualValue != expectedValue) {
            await writer.addIssue(
              severity: 'critical',
              type: 'PERIODESTAND_VELD_FOUT',
              message: 'Periodestandveld $field wijkt af.',
              club: club,
              divisie: '$divisieDocId periode_$periode',
              expected: expectedValue,
              actual: actualValue,
              difference: actualValue - expectedValue,
              documentPath: actualPathByClub[club],
            );
          }
        }
      }
    }
  }
}

Map<String, Map<String, int>> _berekenPeriodeStand({
  required String divisieCode,
  required int periode,
  required Map<String, Map<String, dynamic>> matchesById,
}) {
  final competitie =
      divisieCode == 'A' ? 'Derde Divisie A' : 'Derde Divisie B';

  final startRonde = periode == 1
      ? 1
      : periode == 2
          ? 13
          : 24;

  final eindRonde = periode == 1
      ? 12
      : periode == 2
          ? 23
          : 34;

  Map<String, int> initStats() {
    return {
      'gespeeld': 0,
      'gewonnen': 0,
      'gelijk': 0,
      'verloren': 0,
      'doelpuntenVoor': 0,
      'doelpuntenTegen': 0,
      'punten': 0,
      'doelsaldo': 0,
    };
  }

  final standen = <String, Map<String, int>>{};

  for (final match in matchesById.values) {
    if (_asString(match['competitie']) != competitie) continue;

    final speelronde = _toIntMod(match['speelronde']);

    if (speelronde < startRonde || speelronde > eindRonde) continue;
    if (match['uitslagThuis'] == null || match['uitslagUit'] == null) continue;

    final home = _asString(match['thuisteam']);
    final away = _asString(match['uitteam']);

    if (home.isEmpty || away.isEmpty) continue;

    final h = _toIntMod(match['uitslagThuis']);
    final a = _toIntMod(match['uitslagUit']);

    standen.putIfAbsent(home, initStats);
    standen.putIfAbsent(away, initStats);

    final homeStats = standen[home]!;
    final awayStats = standen[away]!;

    homeStats['gespeeld'] = homeStats['gespeeld']! + 1;
    awayStats['gespeeld'] = awayStats['gespeeld']! + 1;

    homeStats['doelpuntenVoor'] = homeStats['doelpuntenVoor']! + h;
    homeStats['doelpuntenTegen'] = homeStats['doelpuntenTegen']! + a;
    awayStats['doelpuntenVoor'] = awayStats['doelpuntenVoor']! + a;
    awayStats['doelpuntenTegen'] = awayStats['doelpuntenTegen']! + h;

    if (h > a) {
      homeStats['gewonnen'] = homeStats['gewonnen']! + 1;
      homeStats['punten'] = homeStats['punten']! + 3;
      awayStats['verloren'] = awayStats['verloren']! + 1;
    } else if (a > h) {
      awayStats['gewonnen'] = awayStats['gewonnen']! + 1;
      awayStats['punten'] = awayStats['punten']! + 3;
      homeStats['verloren'] = homeStats['verloren']! + 1;
    } else {
      homeStats['gelijk'] = homeStats['gelijk']! + 1;
      awayStats['gelijk'] = awayStats['gelijk']! + 1;
      homeStats['punten'] = homeStats['punten']! + 1;
      awayStats['punten'] = awayStats['punten']! + 1;
    }
  }

  for (final stats in standen.values) {
    stats['doelsaldo'] = stats['doelpuntenVoor']! - stats['doelpuntenTegen']!;
  }

  return standen;
}

Future<int> _auditPoules({
  required _AuditWriter writer,
  required Map<String, Map<String, dynamic>> matchesById,
  required Map<String, Map<String, dynamic>> usersById,
  required QuerySnapshot<Map<String, dynamic>> poulesSnap,
}) async {
  String usernameFor(String uid) {
    final u = usersById[uid];
    return _asString(u?['username'] ?? u?['displayName'] ?? uid);
  }

  final expectedPoulePoints = <String, Map<String, int>>{};
  int deelnemerCount = 0;

  for (final pouleDoc in poulesSnap.docs) {
    final pouleId = pouleDoc.id;

    expectedPoulePoints[pouleId] = {};

    final deelnemersSnap =
        await pouleDoc.reference.collection('deelnemers').get();

    deelnemerCount += deelnemersSnap.docs.length;

    for (final deelnemerDoc in deelnemersSnap.docs) {
      expectedPoulePoints[pouleId]![deelnemerDoc.id] = 0;
    }
  }

  for (final collectie in [
    'poule_predictions',
    'poule_voorspellingen',
    'predictions',
  ]) {
    final snap = await _db.collection(collectie).get();

    final grouped = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final groupedTs = <String, int>{};

    for (final doc in snap.docs) {
      final data = doc.data();

      final pouleId = _asString(data['pouleId'] ?? data['poule']);
      final uid = _asString(data['gebruikerId'] ?? data['userId'] ?? data['uid']);
      final matchId = _asString(data['matchId'] ?? data['wedstrijdId']);

      if (pouleId.isEmpty || uid.isEmpty || matchId.isEmpty) {
        await writer.addIssue(
          severity: 'warning',
          type: 'POULE_VOORSPELLING_ONVOLLEDIG',
          message: 'Poulevoorspelling mist pouleId, gebruikerId of matchId.',
          pouleId: pouleId.isEmpty ? null : pouleId,
          uid: uid.isEmpty ? null : uid,
          username: uid.isEmpty ? null : usernameFor(uid),
          wedstrijdId: matchId.isEmpty ? null : matchId,
          documentPath: doc.reference.path,
          details: {
            'collectie': collectie,
          },
        );
        continue;
      }

      final match = matchesById[matchId];

      if (match == null ||
          match['uitslagThuis'] == null ||
          match['uitslagUit'] == null) {
        continue;
      }

      if (!_hasScoreFields(data)) {
        await writer.addIssue(
          severity: 'critical',
          type: 'POULE_VOORSPELLING_SCORE_ONTBREEKT',
          message: 'Poulevoorspelling mist scoreThuis of scoreUit.',
          pouleId: pouleId,
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: matchId,
          documentPath: doc.reference.path,
          details: {
            'collectie': collectie,
          },
        );
        continue;
      }

      if (_timestampLijktNaDeadline(prediction: data, match: match)) {
        await writer.addIssue(
          severity: 'warning',
          type: 'POULE_VOORSPELLING_TIMESTAMP_NA_DEADLINE',
          message:
              'Timestamp ligt na deadline, maar wordt niet gebruikt om punten af te keuren.',
          pouleId: pouleId,
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: matchId,
          documentPath: doc.reference.path,
          details: {
            'collectie': collectie,
          },
        );
      }

      final ts = (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final key = '$collectie|$pouleId|$uid|$matchId';

      if (!grouped.containsKey(key) || ts >= (groupedTs[key] ?? -1)) {
        grouped[key] = doc;
        groupedTs[key] = ts;
      }
    }

    for (final doc in grouped.values) {
      final data = doc.data();

      final pouleId = _asString(data['pouleId'] ?? data['poule']);
      final uid = _asString(data['gebruikerId'] ?? data['userId'] ?? data['uid']);
      final matchId = _asString(data['matchId'] ?? data['wedstrijdId']);

      final match = matchesById[matchId];

      if (match == null) continue;
      if (match['uitslagThuis'] == null || match['uitslagUit'] == null) continue;
      if (!_hasScoreFields(data)) continue;

      final scoreThuis = _toIntMod(data['scoreThuis']);
      final scoreUit = _toIntMod(data['scoreUit']);
      final uitslagThuis = _toIntMod(match['uitslagThuis']);
      final uitslagUit = _toIntMod(match['uitslagUit']);

      final expected = berekenPunten(
        voorspeldThuis: scoreThuis,
        voorspeldUit: scoreUit,
        echtThuis: uitslagThuis,
        echtUit: uitslagUit,
      );

      final actual = _toIntMod(data['punten']);
      final expectedUitslag = '$uitslagThuis-$uitslagUit';

      if (data['verwerkt'] != true || actual != expected) {
        await writer.addIssue(
          severity: 'critical',
          type: 'POULE_VOORSPELLING_PUNTEN_FOUT',
          message: 'Punten op poulevoorspelling wijken af.',
          pouleId: pouleId,
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: matchId,
          expected: expected,
          actual: data['punten'],
          difference: actual - expected,
          documentPath: doc.reference.path,
          details: {
            'collectie': collectie,
            'voorspelling': '$scoreThuis-$scoreUit',
            'uitslag': expectedUitslag,
          },
        );
      }

      final verwerktVoorUitslag = _asString(data['verwerktVoorUitslag']);

      if (verwerktVoorUitslag != expectedUitslag) {
        await writer.addIssue(
          severity: 'critical',
          type: 'POULE_VERWERKT_VOOR_UITSLAG_FOUT',
          message: 'verwerktVoorUitslag van poulevoorspelling wijkt af.',
          pouleId: pouleId,
          uid: uid,
          username: usernameFor(uid),
          wedstrijdId: matchId,
          expected: expectedUitslag,
          actual: verwerktVoorUitslag,
          documentPath: doc.reference.path,
          details: {
            'collectie': collectie,
          },
        );
      }

      expectedPoulePoints.putIfAbsent(pouleId, () => {});
      expectedPoulePoints[pouleId]![uid] =
          (expectedPoulePoints[pouleId]![uid] ?? 0) + expected;
    }
  }

  for (final pouleDoc in poulesSnap.docs) {
    final pouleId = pouleDoc.id;

    final deelnemersSnap =
        await pouleDoc.reference.collection('deelnemers').get();

    for (final deelnemerDoc in deelnemersSnap.docs) {
      final uid = deelnemerDoc.id;
      final data = deelnemerDoc.data();

      final expected = expectedPoulePoints[pouleId]?[uid] ?? 0;
      final actual = _toIntMod(data['punten']);

      if (actual != expected) {
        await writer.addIssue(
          severity: 'critical',
          type: 'POULE_DEELNEMER_PUNTEN_FOUT',
          message: 'Punten van pouledeelnemer wijken af van auditberekening.',
          pouleId: pouleId,
          uid: uid,
          username: usernameFor(uid),
          expected: expected,
          actual: actual,
          difference: actual - expected,
          documentPath: deelnemerDoc.reference.path,
        );
      }
    }
  }

  return deelnemerCount;
}

Future<void> verwerkEindstandPuntenBeide() async {
  developer.log('🏁 [MOD] Start verwerken eindstandpunten A & B');

  await eindstand.verwerkEindstandPuntenBeide();

  developer.log('✅ [MOD] Eindstandpunten A & B verwerkt');
}

Future<void> _resetAllePouleDeelnemersPunten() async {
  final snap = await _db.collectionGroup('deelnemers').get();

  var n = 0;

  for (final d in snap.docs) {
    await d.reference.set(
      {
        'punten': 0,
      },
      SetOptions(merge: true),
    );

    n++;
  }

  developer.log('🧹 [MOD] poule-deelnemers gereset: $n docs');
}

Future<void> hardeResetEnHerberekenAlles() async {
  developer.log('🧨 [MOD] HARD RESET start');

  await _forEachCollection('users', (d) async {
    await d.reference.set({
      'punten_A': 0,
      'punten_B': 0,
      'totalen': 0,
      'points': 0,
      'eindstandA_awarded': false,
      'eindstandB_awarded': false,
    }, SetOptions(merge: true));
  });

  developer.log('🧹 [MOD] users gereset');

  await _resetAllePouleDeelnemersPunten();

  const predCols = [
    'voorspellingen',
    'poule_predictions',
    'poule_voorspellingen',
    'predictions',
  ];

  for (final c in predCols) {
    await _forEachCollection(c, (d) async {
      await d.reference.set({
        'punten': FieldValue.delete(),
        'verwerkt': false,
        'verwerktVoorUitslag': FieldValue.delete(),
      }, SetOptions(merge: true));
    });

    developer.log('🧹 [MOD] $c geleegd');
  }

  await herberekenAlleWedstrijden();

  developer.log('✅ [MOD] HARD RESET en herberekenen klaar');
}