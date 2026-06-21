// lib/moderator/resetEindstandPunten.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

// Let op: dit pad moet kloppen met jouw projectstructuur
import 'package:derde_divisie/Puntensysteem/puntenverwerker.dart' show resetWedstrijd;

final Logger _log = Logger('ResetServices');

/// ---------- Alleen eindstandpunten resetten (A & B) ----------
Future<void> resetEindstandPuntenBeide() async {
  final fs = FirebaseFirestore.instance;

  Future<WriteBatch> commitAndNew(WriteBatch b) async {
    await b.commit();
    return fs.batch();
  }

  try {
    _log.info('▶️ Start reset eindstandpunten (A & B)...');

    final eindstandSnap = await fs.collection('eindstand_voorspellingen').get();

    var batch = fs.batch();
    var ops = 0;

    // Om na aftrek 'totalen' te kunnen updaten:
    final Set<String> touchedUsers = {};

    for (final doc in eindstandSnap.docs) {
      final data = doc.data();
      final String? uid = data['gebruikerId'] as String?;
      if (uid == null || uid.isEmpty) continue;

      final dynamic rawA = data['eindstand_A_punten'];
      final int bonusA = rawA is int ? rawA : int.tryParse('$rawA') ?? 0;

      final dynamic rawB = data['eindstand_B_punten'];
      final int bonusB = rawB is int ? rawB : int.tryParse('$rawB') ?? 0;

      final userRef = fs.collection('users').doc(uid);
      final userSnap = await userRef.get();
      if (!userSnap.exists) continue;
      final u = userSnap.data() as Map<String, dynamic>;

      final bool aAwarded = u['eindstandA_awarded'] == true;
      final bool bAwarded = u['eindstandB_awarded'] == true;

      final bool aWasGiven = aAwarded || rawA != null;
      final bool bWasGiven = bAwarded || rawB != null;

      final Map<String, dynamic> userUpd = {};
      if (aWasGiven && bonusA != 0) userUpd['punten_A'] = FieldValue.increment(-bonusA);
      if (bWasGiven && bonusB != 0) userUpd['punten_B'] = FieldValue.increment(-bonusB);
      if (aWasGiven) userUpd['eindstandA_awarded'] = false;
      if (bWasGiven) userUpd['eindstandB_awarded'] = false;

      if (userUpd.isNotEmpty) {
        batch.set(userRef, userUpd, SetOptions(merge: true));
        touchedUsers.add(uid);
        ops++;
      }

      // markers/bonussen leeg op voorspelling
      batch.set(doc.reference, {
        'eindstand_A_punten': null,
        'eindstand_B_punten': null,
      }, SetOptions(merge: true));
      ops++;

      // overzicht leegmaken
      final puntenRef = fs.collection('voorspel_punten').doc(uid);
      batch.set(puntenRef, {
        'eindstand_A_punten': null,
        'eindstand_B_punten': null,
      }, SetOptions(merge: true));
      ops++;

      if (ops > 450) {
        batch = await commitAndNew(batch);
        ops = 0;
      }

      _log.info('🔄 Reset eindstand voor $uid (A:-$bonusA, B:-$bonusB)');
    }

    if (ops > 0) {
      await batch.commit();
    }

    // totalen opnieuw als max(A,B)
    for (final uid in touchedUsers) {
      final ref = fs.collection('users').doc(uid);
      final snap = await ref.get();
      if (!snap.exists) continue;
      final u = snap.data() as Map<String, dynamic>;
      final int a = (u['punten_A'] ?? 0) is int ? u['punten_A'] as int : int.tryParse('${u['punten_A'] ?? 0}') ?? 0;
      final int b = (u['punten_B'] ?? 0) is int ? u['punten_B'] as int : int.tryParse('${u['punten_B'] ?? 0}') ?? 0;
      final int maxAB = a > b ? a : b;
      await ref.set({'totalen': maxAB}, SetOptions(merge: true));
    }

    _log.info('✅ Eindstandpunten A & B veilig gereset.');
  } catch (e, st) {
    _log.severe('❌ Fout bij reset eindstandpunten: $e', e, st);
    rethrow;
  }
}

/// ---------- VOLLEDIGE reset: alles naar 0, voorspellingen blijven behouden ----------
Future<void> volledigeResetAllesNaarNul() async {
  final fs = FirebaseFirestore.instance;

  Future<WriteBatch> commitAndNew(WriteBatch b) async {
    await b.commit();
    return fs.batch();
  }

  try {
    _log.info('▶️ Start VOLLEDIGE RESET...');

    // 1) Wedstrijden terugdraaien (boekt ook punten/poules/standen/periodestanden terug)
    final matchesSnap = await fs.collection('matches').get();
    _log.info('🧼 Reset alle wedstrijden: ${matchesSnap.docs.length}');
    for (final m in matchesSnap.docs) {
      await resetWedstrijd(m.id);
    }

    // 2) Eindstand-bonussen/markers leegmaken
    var batch = fs.batch();
    var ops = 0;

    _log.info('🧽 Reset eindstand-bonussen/markers...');
    final eindstandSnap = await fs.collection('eindstand_voorspellingen').get();
    for (final d in eindstandSnap.docs) {
      batch.set(d.reference, {
        'eindstand_A_punten': null,
        'eindstand_B_punten': null,
        'eindstand_A_punten_old': null,
        'eindstand_B_punten_old': null,
      }, SetOptions(merge: true));
      ops++;
      if (ops > 450) {
        batch = await commitAndNew(batch);
        ops = 0;
      }
    }

    // 3) Alle users op 0 + flags uit
    _log.info('👤 Zet alle users-punten op 0 + flags uit...');
    final usersSnap = await fs.collection('users').get();
    for (final u in usersSnap.docs) {
      batch.set(u.reference, {
        'punten_A': 0,
        'punten_B': 0,
        'totalen': 0,
        'eindstandA_awarded': false,
        'eindstandB_awarded': false,
      }, SetOptions(merge: true));
      ops++;
      if (ops > 450) {
        batch = await commitAndNew(batch);
        ops = 0;
      }
    }

    // 4) voorspel_punten leeg loggen
    _log.info('🗒️ Leeg voorspel_punten...');
    final vpSnap = await fs.collection('voorspel_punten').get();
    for (final d in vpSnap.docs) {
      batch.set(d.reference, {
        'eindstand_A_punten': null,
        'eindstand_B_punten': null,
      }, SetOptions(merge: true));
      ops++;
      if (ops > 450) {
        batch = await commitAndNew(batch);
        ops = 0;
      }
    }

    // 5) Alle poule-deelnemerspunten op 0
    _log.info('👥 Zet alle poule-deelnemers op 0...');
    final poulesSnap = await fs.collection('poules').get();
    for (final p in poulesSnap.docs) {
      final deelnemers = await p.reference.collection('deelnemers').get();
      for (final d in deelnemers.docs) {
        batch.set(d.reference, {'punten': 0}, SetOptions(merge: true));
        ops++;
        if (ops > 450) {
          batch = await commitAndNew(batch);
          ops = 0;
        }
      }
    }

    // 6) (extra schoonmaak) voorspellingen-collecties markeren als onbewerkt
    Future<void> wipePredictionCollection(String collectie) async {
      final snap = await fs.collection(collectie).get();
      for (final d in snap.docs) {
        batch.set(d.reference, {
          'punten': null,
          'verwerkt': false,
          'verwerktVoorUitslag': null,
        }, SetOptions(merge: true));
        ops++;
        if (ops > 450) {
          batch = await commitAndNew(batch);
          ops = 0;
        }
      }
    }

    _log.info('🧹 Extra schoonmaak: voorspellingen-collecties resetten...');
    await wipePredictionCollection('voorspellingen');        // algemeen A/B
    await wipePredictionCollection('poule_predictions');     // DDA
    await wipePredictionCollection('poule_voorspellingen');  // DDB
    await wipePredictionCollection('predictions');           // 1-team

    if (ops > 0) {
      await batch.commit();
    }

    _log.info('✅ VOLLEDIGE RESET voltooid. Alles staat weer op 0 (voorspellingen blijven bewaard).');
  } catch (e, st) {
    _log.severe('❌ Fout tijdens volledige reset: $e', e, st);
    rethrow;
  }
}
