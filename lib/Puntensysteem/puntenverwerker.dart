// lib/Puntensysteem/puntenverwerker.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

import '../poules/services/poule_service.dart';
import 'package:derde_divisie/moderator/periodestand_service.dart';
// Alleen de puntentelling binnenhalen, niet de gelijknamige corrigeer/verwerk-helpers
import 'package:derde_divisie/Puntensysteem/puntenlogica.dart' show berekenPunten;

final firestore = FirebaseFirestore.instance;
final PouleService _pouleService = PouleService();

String _veldnaamVoorCompetitie(String competitie) {
  final c = competitie.toString();
  if (c.contains('A')) return 'punten_A';
  if (c.contains('B')) return 'punten_B';
  return 'punten_A'; // fallback
}

/// Converteer teamnaam naar veilige Firestore document-id (geen '/')
String _safeDocId(String s) {
  return s.trim().replaceAll('/', '_');
}

/// Zet users.totalen = max(punten_A, punten_B) (merge-safe)
Future<void> _updateTotalenVoorUserRef(
  DocumentReference<Map<String, dynamic>> userRef,
) async {
  final userDoc = await userRef.get();
  final userData = userDoc.data() ?? {};
  final a = (userData['punten_A'] ?? 0) as int;
  final b = (userData['punten_B'] ?? 0) as int;
  final maxAB = a > b ? a : b;
  await userRef.set({'totalen': maxAB}, SetOptions(merge: true));
}

/// ===== Helpers =====

int _asInt(dynamic v) => int.tryParse('$v') ?? 0;

/// Neemt de eerste bestaande int uit een key-lijst (robuuste mapping)
int _firstInt(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final n = int.tryParse('$v');
    if (n != null) return n;
  }
  return 0;
}

/// Schrijft altijd naar het juiste deelnemersdocument:
/// - eerst doc-id == uid
/// - anders lookup op veld 'userId'
/// - anders doc aanmaken op uid (safe i.c.m. increment)
Future<void> _incrementPouleDeelnemerPuntenSafe({
  required String pouleId,
  required String uid,
  required int delta,
}) async {
  final byIdRef = firestore
      .collection('poules')
      .doc(pouleId)
      .collection('deelnemers')
      .doc(uid);

  try {
    final byIdSnap = await byIdRef.get();

    if (byIdSnap.exists) {
      await byIdRef.set(
        {'punten': FieldValue.increment(delta)},
        SetOptions(merge: true),
      );
      developer.log('👍 increment (docId) poule=$pouleId uid=$uid delta=$delta');
      return;
    }

    // Fallback: sommige poules bewaren uid in veld 'userId'
    final q = await firestore
        .collection('poules')
        .doc(pouleId)
        .collection('deelnemers')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      await q.docs.first.reference.set(
        {'punten': FieldValue.increment(delta)},
        SetOptions(merge: true),
      );
      developer.log('👍 increment (userId lookup) poule=$pouleId uid=$uid delta=$delta');
      return;
    }

    // Als er helemaal niets is, maak een doc op uid
    await byIdRef.set(
      {'punten': FieldValue.increment(delta), 'userId': uid},
      SetOptions(merge: true),
    );
    developer.log('🆕 deelnemer-doc aangemaakt poule=$pouleId uid=$uid delta=$delta');
  } catch (e, st) {
    developer.log(
      '❌ increment deelnemers faalde poule=$pouleId uid=$uid delta=$delta',
      error: e,
      stackTrace: st,
    );
  }
}

/// ===== Poule helpers (generiek voor alle varianten) =====

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findPouleDocsForMatch(
  String collectie,
  String wedstrijdId,
) async {
  // Probeer eerst matchId (poule-collecties), dan wedstrijdId (soms gebruikt)
  var snap =
      await firestore.collection(collectie).where('matchId', isEqualTo: wedstrijdId).get();
  if (snap.docs.isNotEmpty) return snap.docs;

  snap = await firestore
      .collection(collectie)
      .where('wedstrijdId', isEqualTo: wedstrijdId)
      .get();
  return snap.docs;
}

/// Fallback-verwerking voor een poule-collectie (met dedupe + deadline)
Future<void> _verwerkPouleCollectieVoorWedstrijd({
  required String collectie,
  required String wedstrijdId,
  required int echteHome,
  required int echteAway,
}) async {
  final docs = await _findPouleDocsForMatch(collectie, wedstrijdId);
  developer.log('[$collectie] gevonden=${docs.length} voor match=$wedstrijdId');
  if (docs.isEmpty) return;

  // Deadline bepalen uit match (12:00 op wedstrijddag), indien datum bekend
  DateTime? deadline;
  try {
    final matchDoc = await firestore.collection('matches').doc(wedstrijdId).get();
    final matchData = matchDoc.data();
    final Timestamp? ts =
        (matchData?['timestamp'] as Timestamp?) ?? (matchData?['datum'] as Timestamp?);
    if (ts != null) {
      final d = ts.toDate();
      deadline = DateTime(d.year, d.month, d.day, 12);
    } else {
      developer.log('[$collectie] ⚠️ geen datum/timestamp voor match=$wedstrijdId → geen deadline-check');
    }
  } catch (e) {
    developer.log('[$collectie] ⚠️ kon match/$wedstrijdId niet lezen voor deadline: $e');
  }

  // DEDUPE: per user de nieuwste (<= deadline) voorspelling kiezen
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> keep = {};
  final Map<String, int> keepTs = {};
  int skippedAfterDeadline = 0;
  int skippedMissingUid = 0;

  for (final d in docs) {
    final m = d.data();
    final uid = (m['gebruikerId'] ?? m['userId'] ?? m['uid'] ?? '').toString().trim();
    if (uid.isEmpty) {
      skippedMissingUid++;
      continue;
    }
    final Timestamp? t = m['timestamp'] as Timestamp?;
    final int ts = t?.millisecondsSinceEpoch ?? 0;

    // Deadline-handhaving (alleen als bekend)
if (deadline != null) {
  final dt = t?.toDate();
  if (dt == null || dt.isAfter(deadline)) {
    skippedAfterDeadline++;
    continue;
  }
}


    if (!keep.containsKey(uid) || ts >= (keepTs[uid] ?? -1)) {
      keep[uid] = d;
      keepTs[uid] = ts;
    }
  }

  final int dupes = docs.length - keep.length - skippedAfterDeadline - skippedMissingUid;
  if (dupes > 0 || skippedAfterDeadline > 0 || skippedMissingUid > 0) {
    developer.log(
      '[$collectie] dedupe: dupes=$dupes, naDeadline=$skippedAfterDeadline, missingUid=$skippedMissingUid (match=$wedstrijdId)',
    );
  }

  final nieuweUitslag = '$echteHome-$echteAway';
  int processed = 0;
  int participantUpdates = 0;

  for (final d in keep.values) {
    final m = d.data();

    // robuuste keys
    final String pouleId = (m['pouleId'] ?? m['poule'] ?? '').toString().trim();
    final String userId =
        (m['gebruikerId'] ?? m['userId'] ?? m['uid'] ?? '').toString().trim();

    if (pouleId.isEmpty || userId.isEmpty) {
      developer.log('[$collectie] skip: ontbrekende pouleId/userId in ${d.id}');
      continue;
    }

    // Scores (robuuste mapping; blijft backward compatible met scoreThuis/scoreUit)
    final int voorsHome = _firstInt(m, [
      'scoreThuis',
      'thuis',
      'home',
      'voorspellingThuis',
      'homeGoals',
      'goalsHome',
      'homeScore',
      'predHome',
    ]);
    final int voorsAway = _firstInt(m, [
      'scoreUit',
      'uit',
      'away',
      'voorspellingUit',
      'awayGoals',
      'goalsAway',
      'awayScore',
      'predAway',
    ]);

    final bool alVerwerkt = m['verwerkt'] == true;
    final String vorigeUitslag = (m['verwerktVoorUitslag'] ?? '').toString();
    final int oudePunten = _asInt(m['punten']);

    // Als deze exacte uitslag al verwerkt is → niets doen
    if (alVerwerkt && vorigeUitslag == nieuweUitslag) {
      continue;
    }

    // Nieuwe punten berekenen
    final int nieuwePunten = berekenPunten(
      voorspeldThuis: voorsHome,
      voorspeldUit: voorsAway,
      echtThuis: echteHome,
      echtUit: echteAway,
    );

    // Delta t.o.v. eerder bewaarde punten
    final int delta = nieuwePunten - (alVerwerkt ? oudePunten : 0);

    developer.log(
      '[$collectie] poule=$pouleId uid=$userId pred=$voorsHome-$voorsAway '
      'real=$echteHome-$echteAway old=$oudePunten new=$nieuwePunten delta=$delta',
    );

    // 1) Schrijf op de voorspelling zelf
    try {
      await d.reference.set({
        'punten': nieuwePunten,
        'verwerkt': true,
        'verwerktVoorUitslag': nieuweUitslag,
      }, SetOptions(merge: true));
      processed++;
    } catch (e, st) {
      developer.log('❌ set punten op voorspelling faalde ($collectie)', error: e, stackTrace: st);
      continue; // zonder update op de voorspelling geen bijschrijving doen
    }

    // 2) Deelnemer bijwerken met delta
    if (delta != 0) {
      await _incrementPouleDeelnemerPuntenSafe(
        pouleId: pouleId,
        uid: userId,
        delta: delta,
      );
      participantUpdates++;
    }
  }

  developer.log(
    '[$collectie] klaar: voorspellingen bijgewerkt=$processed, deelnemers-updates=$participantUpdates (match=$wedstrijdId)',
  );
}

Future<void> _verwerkAllePouleCollectiesVoorWedstrijd({
  required String wedstrijdId,
  required int echteHome,
  required int echteAway,
}) async {
  const collecties = [
    'poule_voorspellingen', // Derde Divisie B
    'poule_predictions',    // Derde Divisie A
    'predictions',          // 1-team poules
  ];
  for (final c in collecties) {
    try {
      await _verwerkPouleCollectieVoorWedstrijd(
        collectie: c,
        wedstrijdId: wedstrijdId,
        echteHome: echteHome,
        echteAway: echteAway,
      );
      developer.log('🏆 Poule-collectie "$c" verwerkt voor $wedstrijdId');
    } catch (e, st) {
      developer.log('❌ Fout in poule-collectie "$c": $e', stackTrace: st);
    }
  }
}

/// ===== Hoofdverwerker =====

Future<void> verwerkUitslagVoorWedstrijd(String wedstrijdId) async {
  developer.log('[UitslagVerwerking] ▶️ Start verwerking van $wedstrijdId');

  final matchDoc = await firestore.collection('matches').doc(wedstrijdId).get();
  if (!matchDoc.exists) {
    developer.log('⚠️ Wedstrijd $wedstrijdId niet gevonden in Firestore');
    return;
  }

  final data = matchDoc.data()!;
  final uitslagThuis = data['uitslagThuis'];
  final uitslagUit = data['uitslagUit'];
  final vorigeThuis = data['vorigeUitslagThuis'] ?? 0;
  final vorigeUit = data['vorigeUitslagUit'] ?? 0;
  final thuisTeam = (data['thuisteam'] ?? '').toString().trim();
  final uitTeam = (data['uitteam'] ?? '').toString().trim();
  final competitie = (data['competitie'] ?? '').toString().trim();
  final wedstrijdNummer = data['wedstrijdNummer'] ?? 0;
  final veldnaam = _veldnaamVoorCompetitie(competitie);

  if (thuisTeam.isEmpty || uitTeam.isEmpty || competitie.isEmpty) {
    developer.log(
      '❌ Ontbrekende team- of competitiegegevens bij wedstrijd $wedstrijdId: '
      'thuis="$thuisTeam", uit="$uitTeam", competitie="$competitie"',
    );
    return;
  }

  if (uitslagThuis == null || uitslagUit == null) {
    developer.log('⚠️ Uitslag ontbreekt voor wedstrijd $wedstrijdId');
    return;
  }

  // Correctie oude uitslag (stand + periodestanden)
  if (uitslagThuis != vorigeThuis || uitslagUit != vorigeUit) {
    developer.log('🔁 Vorige uitslag wordt gecorrigeerd: $vorigeThuis-$vorigeUit');
    await corrigeerStand(thuisTeam, vorigeThuis, vorigeUit);
    await corrigeerStand(uitTeam, vorigeUit, vorigeThuis);
    await corrigeerPeriodestand(thuisTeam, vorigeThuis, vorigeUit, wedstrijdNummer, competitie);
    await corrigeerPeriodestand(uitTeam, vorigeUit, vorigeThuis, wedstrijdNummer, competitie);
  }

  // Nieuwe uitslag verwerken (stand + periodestanden)
  await verwerkStand(thuisTeam, uitslagThuis, uitslagUit, competitie);
  await verwerkStand(uitTeam, uitslagUit, uitslagThuis, competitie);
  await updatePeriodestand(thuisTeam, uitslagThuis, uitslagUit, wedstrijdNummer, competitie);
  await updatePeriodestand(uitTeam, uitslagUit, uitslagThuis, wedstrijdNummer, competitie);

  await firestore.collection('matches').doc(wedstrijdId).update({
    'vorigeUitslagThuis': uitslagThuis,
    'vorigeUitslagUit': uitslagUit,
    'verwerkt': true,
  });

  developer.log('✅ Uitslag opgeslagen bij wedstrijd $wedstrijdId');

  // ⚽️ Hoofd-voorspellingen (A/B)
  await verwerkVoorspellingenVoorWedstrijd(
    wedstrijdId,
    uitslagThuis,
    uitslagUit,
    veldnaam,
  );

  // 🏆 Poule-voorspellingen (service + failsafe op alle collecties)
  final poulesSnapshot = await firestore.collection('poules').get();
  for (final poule in poulesSnapshot.docs) {
    final pouleId = poule.id;
    try {
      await _pouleService.verwerkPuntenVoorPouleVoorspellingen(
        pouleId: pouleId,
        matchId: wedstrijdId,
        echteHome: uitslagThuis,
        echteAway: uitslagUit,
      );
      developer.log('🏁 PouleService attempt voor $pouleId');
    } catch (e, st) {
      developer.log('❌ Fout in PouleService voor $pouleId: $e', stackTrace: st);
    }
  }

  // Fallback die alle collecties dekt (ook als service niks vindt)
  await _verwerkAllePouleCollectiesVoorWedstrijd(
    wedstrijdId: wedstrijdId,
    echteHome: uitslagThuis,
    echteAway: uitslagUit,
  );

  // Periode-standen automatisch bijwerken (samenvattend)
  final periodeService = PeriodestandService();
  final divisie = competitie.contains('A') ? 'dda' : 'ddb';
  await periodeService.herberekenAllePeriodesVoorDivisie(divisie);

  developer.log('[UitslagVerwerking] ✅ Klaar voor $wedstrijdId');
}

Future<void> verwerkVoorspellingenVoorWedstrijd(
  String wedstrijdId,
  int uitslagThuis,
  int uitslagUit,
  String veldnaam,
) async {
  final wedstrijdSnapshot =
      await firestore.collection('matches').doc(wedstrijdId).get();
  final matchData = wedstrijdSnapshot.data();

  // Ondersteun zowel 'timestamp' als 'datum' (beide Firestore Timestamp)
  final Timestamp? ts =
      (matchData?['timestamp'] as Timestamp?) ??
      (matchData?['datum'] as Timestamp?);

  // Deadline = 12:00 op wedstrijddag (alleen als datum bekend is)
  DateTime? deadline;
  if (ts != null) {
    final d = ts.toDate();
    deadline = DateTime(d.year, d.month, d.day, 12);
  } else {
    developer.log(
        '⚠️ Geen datum/timestamp bij match $wedstrijdId — deadline-check wordt overgeslagen.');
  }

  // Bij jou is wedstrijdId het doc-id zoals 'A1'/'B12'
  final voorspellingenSnapshot = await firestore
      .collection('voorspellingen')
      .where('wedstrijdId', isEqualTo: wedstrijdId)
      .get();

  final nieuweUitslag = '$uitslagThuis-$uitslagUit';

  int processed = 0;
  int userUpdates = 0;

  for (final doc in voorspellingenSnapshot.docs) {
    final data = doc.data();
    final gebruikerId = data['gebruikerId'] as String?;
    final invulMoment = (data['timestamp'] as Timestamp?)?.toDate();

    // Deadline-handhaving alleen als we een datum hebben
    if (deadline != null) {
      if (invulMoment == null || invulMoment.isAfter(deadline)) {
        developer.log('[AB] skip (na deadline) uid=$gebruikerId match=$wedstrijdId');
        continue;
      }
    }

    final voorspellingThuis = int.tryParse(data['scoreThuis'].toString()) ?? 0;
    final voorspellingUit = int.tryParse(data['scoreUit'].toString()) ?? 0;
    final alVerwerkt = data['verwerkt'] == true;
    final vorigeUitslag = (data['verwerktVoorUitslag'] ?? '').toString();
    final vorigePunten = (data['punten'] ?? 0) as int;

    if (alVerwerkt && vorigeUitslag == nieuweUitslag) continue;

    // oude punten afboeken (merge-safe)
    if (alVerwerkt && vorigePunten != 0 && gebruikerId != null) {
      try {
        final userRef = firestore.collection('users').doc(gebruikerId);
        await userRef.set({veldnaam: FieldValue.increment(-vorigePunten)}, SetOptions(merge: true));
        await _updateTotalenVoorUserRef(userRef);
      } catch (e, st) {
        developer.log('❌ aftrek users-$veldnaam faalde', error: e, stackTrace: st);
      }
    }

    // nieuwe punten berekenen
    final punten = berekenPunten(
      voorspeldThuis: voorspellingThuis,
      voorspeldUit: voorspellingUit,
      echtThuis: uitslagThuis,
      echtUit: uitslagUit,
    );

    // opslaan bij voorspelling
    try {
      await doc.reference.set({
        'punten': punten,
        'verwerkt': true,
        'verwerktVoorUitslag': nieuweUitslag,
      }, SetOptions(merge: true));
      processed++;
    } catch (e, st) {
      developer.log('❌ set punten op AB-voorspelling faalde', error: e, stackTrace: st);
      continue;
    }

    // user-totalen bijwerken (merge-safe)
    if (gebruikerId != null) {
      try {
        final userRef = firestore.collection('users').doc(gebruikerId);
        await userRef.set({veldnaam: FieldValue.increment(punten)}, SetOptions(merge: true));
        await _updateTotalenVoorUserRef(userRef);
        userUpdates++;
      } catch (e, st) {
        developer.log('❌ bijschrijven users-$veldnaam faalde', error: e, stackTrace: st);
      }
    }

    developer.log(
      '[AB] uid=$gebruikerId pred=$voorspellingThuis-$voorspellingUit '
      'real=$uitslagThuis-$uitslagUit punten=$punten',
    );
  }

  developer.log('[AB] klaar: voorspellingen bijgewerkt=$processed, user-updates=$userUpdates (match=$wedstrijdId)');
}

/// ===== Standen en periode-standen =====

Future<void> corrigeerStand(String team, int scoreVoor, int scoreTegen) async {
  final docRef = firestore.collection('standen').doc(_safeDocId(team));
  final doc = await docRef.get();
  if (!doc.exists) return;

  final data = doc.data()!;
  int gespeeld = data['gespeeld'] ?? 0;
  int gewonnen = data['gewonnen'] ?? 0;
  int gelijk = data['gelijk'] ?? 0;
  int verloren = data['verloren'] ?? 0;
  int doelpuntenVoor = data['doelpuntenVoor'] ?? 0;
  int doelpuntenTegen = data['doelpuntenTegen'] ?? 0;
  int punten = data['punten'] ?? 0;

  if (gespeeld == 0) return;

  doelpuntenVoor -= scoreVoor;
  doelpuntenTegen -= scoreTegen;
  gespeeld--;

  if (scoreVoor == scoreTegen) {
    gelijk--;
    punten -= 1;
  } else if (scoreVoor > scoreTegen) {
    gewonnen--;
    punten -= 3;
  } else {
    verloren--;
  }

  await docRef.update({
    'gespeeld': gespeeld,
    'gewonnen': gewonnen,
    'gelijk': gelijk,
    'verloren': verloren,
    'doelpuntenVoor': doelpuntenVoor,
    'doelpuntenTegen': doelpuntenTegen,
    'punten': punten,
  });
}

Future<void> verwerkStand(String team, int scoreVoor, int scoreTegen, String competitie) async {
  final docRef = firestore.collection('standen').doc(_safeDocId(team));
  final doc = await docRef.get();

  int gespeeld = 0;
  int gewonnen = 0;
  int gelijk = 0;
  int verloren = 0;
  int doelpuntenVoor = 0;
  int doelpuntenTegen = 0;
  int punten = 0;

  if (doc.exists) {
    final data = doc.data()!;
    gespeeld = data['gespeeld'] ?? 0;
    gewonnen = data['gewonnen'] ?? 0;
    gelijk = data['gelijk'] ?? 0;
    verloren = data['verloren'] ?? 0;
    doelpuntenVoor = data['doelpuntenVoor'] ?? 0;
    doelpuntenTegen = data['doelpuntenTegen'] ?? 0;
    punten = data['punten'] ?? 0;
  }

  // Update statistieken
  doelpuntenVoor += scoreVoor;
  doelpuntenTegen += scoreTegen;
  gespeeld++;

  if (scoreVoor == scoreTegen) {
    gelijk++;
    punten += 1;
  } else if (scoreVoor > scoreTegen) {
    gewonnen++;
    punten += 3;
  } else {
    verloren++;
  }

  await docRef.set({
    'club': team, // originele naam bewaren in veld
    'competitie': competitie,
    'gespeeld': gespeeld,
    'gewonnen': gewonnen,
    'gelijk': gelijk,
    'verloren': verloren,
    'doelpuntenVoor': doelpuntenVoor,
    'doelpuntenTegen': doelpuntenTegen,
    'punten': punten,
  }, SetOptions(merge: true));

  developer.log('[Stand] ➕ $team krijgt $scoreVoor-$scoreTegen toegevoegd in competitie $competitie');
}

Future<void> updatePeriodestand(
  String team,
  int scoreVoor,
  int scoreTegen,
  int wedstrijdNummer,
  String competitie,
) async {
  final int periode = (wedstrijdNummer <= 108)
      ? 1
      : (wedstrijdNummer <= 207)
          ? 2
          : 3;

  final competitieCode = competitie.contains('A') ? 'dda' : 'ddb';
  final docRef = firestore
      .collection('periodestanden')
      .doc(competitieCode)
      .collection('periode_$periode')
      .doc(_safeDocId(team));
  final doc = await docRef.get();

  int gespeeld = 0, gewonnen = 0, gelijk = 0, verloren = 0, voor = 0, tegen = 0, punten = 0;
  if (doc.exists) {
    final data = doc.data()!;
    gespeeld = data['gespeeld'] ?? 0;
    gewonnen = data['gewonnen'] ?? 0;
    gelijk = data['gelijk'] ?? 0;
    verloren = data['verloren'] ?? 0;
    voor = data['doelpuntenVoor'] ?? 0;
    tegen = data['doelpuntenTegen'] ?? 0;
    punten = data['punten'] ?? 0;
  }

  gespeeld++;
  voor += scoreVoor;
  tegen += scoreTegen;

  if (scoreVoor > scoreTegen) {
    gewonnen++;
    punten += 3;
  } else if (scoreVoor == scoreTegen) {
    gelijk++;
    punten += 1;
  } else {
    verloren++;
  }

  await docRef.set({
    'club': team, // originele naam opslaan als veld
    'gespeeld': gespeeld,
    'gewonnen': gewonnen,
    'gelijk': gelijk,
    'verloren': verloren,
    'doelpuntenVoor': voor,
    'doelpuntenTegen': tegen,
    'punten': punten,
  }, SetOptions(merge: true));
}

Future<void> corrigeerPeriodestand(
  String team,
  int scoreVoor,
  int scoreTegen,
  int wedstrijdNummer,
  String competitie,
) async {
  final int periode = (wedstrijdNummer <= 108)
      ? 1
      : (wedstrijdNummer <= 207)
          ? 2
          : 3;

  final competitieCode = competitie.contains('A') ? 'dda' : 'ddb';
  final docRef = firestore
      .collection('periodestanden')
      .doc(competitieCode)
      .collection('periode_$periode')
      .doc(_safeDocId(team));
  final doc = await docRef.get();
  if (!doc.exists) return;

  final data = doc.data()!;
  int gespeeld = data['gespeeld'] ?? 0;
  int gewonnen = data['gewonnen'] ?? 0;
  int gelijk = data['gelijk'] ?? 0;
  int verloren = data['verloren'] ?? 0;
  int voor = data['doelpuntenVoor'] ?? 0;
  int tegen = data['doelpuntenTegen'] ?? 0;
  int punten = data['punten'] ?? 0;

  if (gespeeld == 0) return;

  gespeeld--;
  voor -= scoreVoor;
  tegen -= scoreTegen;

  if (scoreVoor > scoreTegen) {
    gewonnen--;
    punten -= 3;
  } else if (scoreVoor == scoreTegen) {
    gelijk--;
    punten -= 1;
  } else {
    verloren--;
  }

  await docRef.update({
    'gespeeld': gespeeld,
    'gewonnen': gewonnen,
    'gelijk': gelijk,
    'verloren': verloren,
    'doelpuntenVoor': voor,
    'doelpuntenTegen': tegen,
    'punten': punten,
  });

  developer.log('[Stand] ➖ Correctie op $team: -$scoreVoor-$scoreTegen');
}

/// ===== Reset =====

Future<void> resetWedstrijd(String wedstrijdId) async {
  developer.log('[Reset] 🧼 Start reset van $wedstrijdId');

  final matchRef = firestore.collection('matches').doc(wedstrijdId);
  final doc = await matchRef.get();
  if (!doc.exists) return;

  final data = doc.data()!;
  final thuis = (data['thuisteam'] ?? '').toString();
  final uit = (data['uitteam'] ?? '').toString();
  final thuisScore = data['uitslagThuis'];
  final uitScore = data['uitslagUit'];
  final competitie = (data['competitie'] ?? '').toString().trim();
  final wedstrijdNummer = data['wedstrijdNummer'] ?? 0;

  final veldnaam = _veldnaamVoorCompetitie(competitie);

  // 1) Standen + periodestanden terugdraaien als er een uitslag stond
  if (thuisScore != null && uitScore != null) {
    await corrigeerStand(thuis, thuisScore, uitScore);
    await corrigeerStand(uit, uitScore, thuisScore);
    await corrigeerPeriodestand(thuis, thuisScore, uitScore, wedstrijdNummer, competitie);
    await corrigeerPeriodestand(uit, uitScore, thuisScore, wedstrijdNummer, competitie);
  }

  // 2) Wedstrijd leegmaken
  await matchRef.update({
    'uitslagThuis': null,
    'uitslagUit': null,
    'vorigeUitslagThuis': null,
    'vorigeUitslagUit': null,
    'verwerkt': false,
  });

  // ---------- Helpers (zonder underscore) ----------
  Future<void> resetAlgemeneVoorspellingen() async {
    final snap = await firestore
        .collection('voorspellingen')
        .where('wedstrijdId', isEqualTo: wedstrijdId)
        .get();

    for (final d in snap.docs) {
      final m = d.data();
      final String? gebruikerId = m['gebruikerId'];
      final int punten = (m['punten'] ?? 0) as int;

      if (gebruikerId != null && punten != 0) {
        final userRef = firestore.collection('users').doc(gebruikerId);
        await userRef.set({veldnaam: FieldValue.increment(-punten)}, SetOptions(merge: true));
        await _updateTotalenVoorUserRef(userRef); // totalen direct herberekenen
      }

      await d.reference.update({
        'punten': FieldValue.delete(),
        'verwerkt': false,
        'verwerktVoorUitslag': FieldValue.delete(),
      });
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getPouleDocs(
    String collectieNaam,
  ) async {
    // Zowel matchId als wedstrijdId ondersteunen
    var snap = await firestore
        .collection(collectieNaam)
        .where('matchId', isEqualTo: wedstrijdId)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs;

    snap = await firestore
        .collection(collectieNaam)
        .where('wedstrijdId', isEqualTo: wedstrijdId)
        .get();
    return snap.docs;
  }

  // Generieke poule-reset
  Future<void> resetPouleCollectie(String collectieNaam) async {
    final docs = await getPouleDocs(collectieNaam);

    final Map<String, Map<String, int>> aftrekPerPoule = {};

    for (final d in docs) {
      final m = d.data();
      final String pouleId = (m['pouleId'] ?? m['poule'] ?? '').toString();
      final String gebruikerId =
          (m['gebruikerId'] ?? m['userId'] ?? m['uid'] ?? '').toString();
      final int punten = (m['punten'] ?? 0) as int;

      if (pouleId.isNotEmpty && gebruikerId.isNotEmpty && punten != 0) {
        aftrekPerPoule[pouleId] ??= {};
        aftrekPerPoule[pouleId]![gebruikerId] =
            (aftrekPerPoule[pouleId]![gebruikerId] ?? 0) + punten;
      }

      await d.reference.update({
        'punten': FieldValue.delete(),
        'verwerkt': false,
        'verwerktVoorUitslag': FieldValue.delete(),
      });
    }

    for (final entry in aftrekPerPoule.entries) {
      final pouleId = entry.key;
      for (final deelnemer in entry.value.entries) {
        await _incrementPouleDeelnemerPuntenSafe(
          pouleId: pouleId,
          uid: deelnemer.key,
          delta: -deelnemer.value,
        );
      }
    }
  }

  // 3) Gebruikerspunten resetten (algemeen + alle poulevormen)
  await resetAlgemeneVoorspellingen();                // algemene A/B
  await resetPouleCollectie('poule_predictions');     // poule DDA
  await resetPouleCollectie('poule_voorspellingen');  // poule DDB
  await resetPouleCollectie('predictions');           // poule één-team

  developer.log('[Reset] ✅ Wedstrijd $wedstrijdId volledig gereset');
}
