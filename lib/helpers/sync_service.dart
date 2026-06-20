// lib/helpers/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Eenvoudige DTO i.p.v. Dart records (SDK-compatibel)
class _IdsEarliest {
  final List<String> ids;
  final DateTime? earliest;
  _IdsEarliest({required this.ids, required this.earliest});
}

class SyncService {
  SyncService._();
  static final instance = SyncService._();

  final _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _fsCompetitionName(String code) {
    switch (code.toLowerCase()) {
      case 'dda':
        return 'Derde Divisie A';
      case 'ddb':
        return 'Derde Divisie B';
      default:
        return code; // al leesbare vorm?
    }
  }

  String _poolCollectionFor(String competition) {
    // DDA -> poule_predictions, DDB -> poule_voorspellingen
    return competition.toLowerCase() == 'dda'
        ? 'poule_predictions'
        : 'poule_voorspellingen';
  }

  String _normTeamCode(String s) => s
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll("'", '')
      .replaceAll('/', '')
      .replaceAll('.', '')
      .replaceAll('-', '');

  // EU DST helpers (zonder extra package)
  DateTime _lastSundayBoundaryUtc(int year, int month) {
    final nextMonth = (month == 12)
        ? DateTime.utc(year + 1, 1, 1)
        : DateTime.utc(year, month + 1, 1);
    DateTime d = nextMonth.subtract(const Duration(days: 1));
    d = DateTime.utc(d.year, d.month, d.day);
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d.add(const Duration(hours: 1)); // 01:00 UTC
  }

  bool _isDstAmsterdam(DateTime utc) {
    final u = utc.toUtc();
    final start = _lastSundayBoundaryUtc(u.year, 3);
    final end = _lastSundayBoundaryUtc(u.year, 10);
    return u.isAfter(start) && u.isBefore(end);
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size < list.length) ? i + size : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  // ---------------------------------------------------------------------------
  // Round overrides
  // ---------------------------------------------------------------------------

  /// Haalt een override op voor 1 competitie+ronde.
  /// Verwacht document id: 'dda_18' / 'ddb_18' in collectie 'round_overrides'
  /// met veld: reopenUntil (Timestamp).
  /// Geeft UTC DateTime terug als override actief is (now < reopenUntil).
  Future<DateTime?> _roundOverrideUtc({
    required String competition, // 'dda' | 'ddb'
    required int round,
  }) async {
    final id = '${competition.toLowerCase()}_$round';
    final snap = await _db.collection('round_overrides').doc(id).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final ts = data['reopenUntil'];
    if (ts is! Timestamp) return null;

    final untilUtc = ts.toDate().toUtc();
    if (DateTime.now().toUtc().isAfter(untilUtc)) return null;

    return untilUtc;
  }

  // ---------------------------------------------------------------------------
  // Deadlines & ronde data
  // ---------------------------------------------------------------------------

  // returns: ids van de wedstrijden in deze ronde + vroegste aftrap (UTC)
  Future<_IdsEarliest> _matchIdsAndEarliest({
    required String competition, // 'dda' | 'ddb'
    required int round,
  }) async {
    final fsComp = _fsCompetitionName(competition);
    final qs = await _db
        .collection('matches')
        .where('competitie', isEqualTo: fsComp)
        .where('speelronde', isEqualTo: round)
        .orderBy('datum')
        .get();

    final ids = <String>[];
    DateTime? earliest;

    for (final d in qs.docs) {
      ids.add(d.id);
      final ts = d.data()['datum'];
      if (ts is Timestamp) {
        final dt = ts.toDate().toUtc();
        if (earliest == null || dt.isBefore(earliest)) earliest = dt;
      }
    }

    return _IdsEarliest(ids: ids, earliest: earliest);
  }

  // Deadline per ronde:
  // 1) als override actief is: reopenUntil (UTC)
  // 2) anders: 12:00 lokale tijd (CET/CEST) op dag earliest → terugrekenen naar UTC
  Future<DateTime?> _deadlineUtcForRound({
    required String competition,
    required int round,
  }) async {
    // ✅ Override eerst (exact 1 ronde open, rest blijft dicht)
    final overrideUtc =
        await _roundOverrideUtc(competition: competition, round: round);
    if (overrideUtc != null) return overrideUtc;

    final res =
        await _matchIdsAndEarliest(competition: competition, round: round);
    if (res.earliest == null) return null;

    final earliest = res.earliest!; // UTC
    final isDst = _isDstAmsterdam(earliest);
    final offset = Duration(hours: isDst ? 2 : 1);
    final localDate = earliest.add(offset);
    final localDeadline = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
      12,
      0,
      0,
    );
    return localDeadline.subtract(offset);
  }

  // Deadline per losse wedstrijd = 12:00 lokale tijd op wedstrijddag
  DateTime _deadlineUtcForMatchDate(DateTime utcKickoff) {
    final isDst = _isDstAmsterdam(utcKickoff);
    final offset = Duration(hours: isDst ? 2 : 1);
    final local = utcKickoff.add(offset);
    final localDeadline =
        DateTime.utc(local.year, local.month, local.day, 12, 0, 0);
    return localDeadline.subtract(offset);
  }

  // ---------------------------------------------------------------------------
  // Upserts (schrijven naar doelcollecties)
  // ---------------------------------------------------------------------------

  Future<void> _upsertPoolPredictionTopLevel({
    required String poolId,
    required String userId,
    required String competition, // 'dda' | 'ddb'
    required int round,
    required String matchId,
    required Map<String, dynamic> generalPrediction, // {scoreThuis, scoreUit}
    required DateTime deadlineUtc,
  }) async {
    final coll = _poolCollectionFor(competition);
    final docRef = _db.collection(coll).doc('${poolId}_${userId}_$matchId');

    await _db.runTransaction((tx) async {
      final nowUtc = DateTime.now().toUtc();
      if (nowUtc.isAfter(deadlineUtc)) return;

      final snap = await tx.get(docRef);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        // Wanneer in poule handmatig is ingevuld, niet overschrijven
        final isManual = data['syncedFromGeneral'] != true;
        if (isManual) return;
      }

      tx.set(
        docRef,
        {
          'pouleId': poolId,
          'gebruikerId': userId,
          'userId': userId, // compat
          'matchId': matchId,
          'wedstrijdId': matchId, // compat
          ...generalPrediction,
          'syncedFromGeneral': true,
          'syncedUpdatedAt': FieldValue.serverTimestamp(),
          'round': round,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _upsertOneTeamPrediction({
    required String poolId,
    required String userId,
    required String matchId,
    required Map<String, dynamic> generalPrediction,
    required DateTime deadlineUtc,
  }) async {
    // Gebruik het id-schema van jouw One-team scherm:
    final docId = '${userId}_${matchId}_$poolId';
    final docRef = _db.collection('predictions').doc(docId);

    await _db.runTransaction((tx) async {
      final nowUtc = DateTime.now().toUtc();
      if (nowUtc.isAfter(deadlineUtc)) return;

      final snap = await tx.get(docRef);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        // Als handmatig (geen sync-vlag), niet overschrijven
        final isManual = data['syncedFromGeneral'] != true;
        if (isManual) return;
      }

      tx.set(
        docRef,
        {
          'pouleId': poolId,
          'gebruikerId': userId,
          'userId': userId, // compat
          'matchId': matchId,
          'wedstrijdId': matchId, // compat
          ...generalPrediction, // scoreThuis, scoreUit
          'homeGoals': generalPrediction['scoreThuis'],
          'awayGoals': generalPrediction['scoreUit'],
          'syncedFromGeneral': true,
          'syncedUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Backfill implementaties
  // ---------------------------------------------------------------------------

  Future<void> _backfillCompetitionPool({
    required String poolId,
    required String userId,
    required String competition, // 'dda' | 'ddb'
  }) async {
    // open rondes backfillen
    for (int round = 1; round <= 34; round++) {
      final m = await _matchIdsAndEarliest(
        competition: competition,
        round: round,
      );
      if (m.ids.isEmpty) continue;

      final deadlineUTC = await _deadlineUtcForRound(
        competition: competition,
        round: round,
      );
      if (deadlineUTC == null) continue;
      if (DateTime.now().toUtc().isAfter(deadlineUTC)) continue; // ronde gesloten

      // whereIn max 10 -> chunken
      for (final chunk in _chunk(m.ids, 10)) {
        final vpQs = await _db
            .collection('voorspellingen')
            .where('gebruikerId', isEqualTo: userId)
            .where('wedstrijdId', whereIn: chunk)
            .get();

        if (vpQs.docs.isEmpty) continue;

        for (final d in vpQs.docs) {
          final data = d.data();
          final matchId = (data['matchId'] ?? data['wedstrijdId']).toString();
          final Map<String, dynamic> gen = {
            'scoreThuis': data['scoreThuis'],
            'scoreUit': data['scoreUit'],
          };

          await _upsertPoolPredictionTopLevel(
            poolId: poolId,
            userId: userId,
            competition: competition,
            round: round,
            matchId: matchId,
            generalPrediction: gen,
            deadlineUtc: deadlineUTC,
          );
        }
      }
    }
  }

  Future<void> _backfillOneTeamPool({
    required String poolId,
    required String userId,
    required String teamCodeRaw, // uit poule-doc
  }) async {
    final teamCode = _normTeamCode(teamCodeRaw);
    if (teamCode.isEmpty) return;

    final qHome = await _db
        .collection('matches')
        .where('homeTeamCode', isEqualTo: teamCode)
        .get();
    final qAway = await _db
        .collection('matches')
        .where('awayTeamCode', isEqualTo: teamCode)
        .get();

    // combineer unique op id
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byId = {};

    for (final d in qHome.docs) {
      byId[d.id] = d;
    }
    for (final d in qAway.docs) {
      byId[d.id] = d;
    }

    if (byId.isEmpty) return;

    for (final entry in byId.entries) {
      final id = entry.key;
      final data = entry.value.data();

      final ts = (data['datum'] ?? data['timestamp']);
      if (ts is! Timestamp) continue;
      final kickoffUtc = ts.toDate().toUtc();
      final deadlineUtc = _deadlineUtcForMatchDate(kickoffUtc);

      if (DateTime.now().toUtc().isAfter(deadlineUtc)) continue; // wedstrijd gesloten

      // globale voorspelling van deze user voor deze match
      // (query i.p.v. docId aannames)
      final g = await _db
          .collection('voorspellingen')
          .where('gebruikerId', isEqualTo: userId)
          .where('wedstrijdId', isEqualTo: id)
          .limit(1)
          .get();
      if (g.docs.isEmpty) continue;

      final gp = g.docs.first.data();
      final gen = {
        'scoreThuis': gp['scoreThuis'],
        'scoreUit': gp['scoreUit'],
      };

      await _upsertOneTeamPrediction(
        poolId: poolId,
        userId: userId,
        matchId: id,
        generalPrediction: gen,
        deadlineUtc: deadlineUtc,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Backfill bij aanzetten sync: neemt open rondes (DDA/DDB) of open wedstrijden (ONE_TEAM) mee.
  Future<void> enableSyncForUserInPool({
    required String poolId,
    required String userId,
  }) async {
    final poolSnap = await _db.collection('poules').doc(poolId).get();
    if (!poolSnap.exists) {
      throw StateError('Poule $poolId bestaat niet.');
    }
    final p = poolSnap.data()!;

    // competition/type bepalen
    final competitionRaw =
        (p['competition'] ?? p['type'] ?? '').toString().toLowerCase();

    // zet vlag + startAt
    await _db
        .collection('poules')
        .doc(poolId)
        .collection('deelnemers')
        .doc(userId)
        .set(
          {'syncEnabled': true, 'syncStartAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );

    if (competitionRaw == 'dda' || competitionRaw == 'ddb') {
      await _backfillCompetitionPool(
        poolId: poolId,
        userId: userId,
        competition: competitionRaw,
      );
      return;
    }

    // ONE_TEAM
    if (competitionRaw == 'team' ||
        (p['type']?.toString().toUpperCase() == 'ONE_TEAM')) {
      final teamCode =
          (p['teamCode'] ?? p['selectedTeam'] ?? p['team'] ?? '').toString();
      await _backfillOneTeamPool(
        poolId: poolId,
        userId: userId,
        teamCodeRaw: teamCode,
      );
      return;
    }

    // Onbekend -> niets doen
  }

  /// Reageer op wijziging in algemene voorspelling (DDA/DDB) – optioneel te gebruiken.
  Future<void> onGeneralPredictionChangedCompetition({
    required String userId,
    required String competition, // 'dda' | 'ddb'
    required int round,
    required String matchId,
    required Map<String, dynamic> generalPrediction,
  }) async {
    final deadlineUTC = await _deadlineUtcForRound(
      competition: competition,
      round: round,
    );
    if (deadlineUTC == null) return;
    if (DateTime.now().toUtc().isAfter(deadlineUTC)) return;

    final poolsQs = await _db
        .collection('poules')
        .where('competition', isEqualTo: competition)
        .get();

    for (final p in poolsQs.docs) {
      final deelnemerDoc = await _db
          .collection('poules')
          .doc(p.id)
          .collection('deelnemers')
          .doc(userId)
          .get();

      if (!deelnemerDoc.exists) continue;
      if (deelnemerDoc.data()?['syncEnabled'] != true) continue;

      await _upsertPoolPredictionTopLevel(
        poolId: p.id,
        userId: userId,
        competition: competition,
        round: round,
        matchId: matchId,
        generalPrediction: generalPrediction,
        deadlineUtc: deadlineUTC,
      );
    }
  }

  /// Reageer op wijziging in algemene voorspelling (ONE_TEAM) – optioneel te gebruiken.
  Future<void> onGeneralPredictionChangedOneTeam({
    required String userId,
    required String matchId,
    required Map<String, dynamic> generalPrediction,
  }) async {
    // haal match op om deadline + teamcodes te bepalen
    final m = await _db.collection('matches').doc(matchId).get();
    if (!m.exists) return;
    final md = m.data()!;
    final ts = (md['datum'] ?? md['timestamp']);
    if (ts is! Timestamp) return;
    final kickoffUtc = ts.toDate().toUtc();
    final deadlineUtc = _deadlineUtcForMatchDate(kickoffUtc);
    if (DateTime.now().toUtc().isAfter(deadlineUtc)) return;

    final home = (md['homeTeamCode'] ?? '').toString();
    final away = (md['awayTeamCode'] ?? '').toString();

    final pools = await _db.collection('poules').get();
    for (final p in pools.docs) {
      final data = p.data();
      final isOneTeam =
          data['competition']?.toString().toLowerCase() == 'team' ||
              data['type']?.toString().toUpperCase() == 'ONE_TEAM';
      if (!isOneTeam) continue;

      // user deelnemer + syncEnabled?
      final deelnemerDoc = await _db
          .collection('poules')
          .doc(p.id)
          .collection('deelnemers')
          .doc(userId)
          .get();
      if (!deelnemerDoc.exists) continue;
      if (deelnemerDoc.data()?['syncEnabled'] != true) continue;

      final teamCodeRaw =
          (data['teamCode'] ?? data['selectedTeam'] ?? data['team'] ?? '')
              .toString();
      final team = _normTeamCode(teamCodeRaw);
      if (team.isEmpty) continue;

      // alleen schrijven als deze match het team raakt
      if (team != home && team != away) continue;

      await _upsertOneTeamPrediction(
        poolId: p.id,
        userId: userId,
        matchId: matchId,
        generalPrediction: generalPrediction,
        deadlineUtc: deadlineUtc,
      );
    }
  }

  Future<void> disableSyncForUserInPool({
    required String poolId,
    required String userId,
  }) async {
    await _db
        .collection('poules')
        .doc(poolId)
        .collection('deelnemers')
        .doc(userId)
        .set({'syncEnabled': false, 'syncStartAt': null}, SetOptions(merge: true));
  }
}
