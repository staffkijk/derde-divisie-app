import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../models/poule_model.dart';

int berekenPuntenVoorVoorspelling({
  required int voorspeldHome,
  required int voorspeldAway,
  required int echtHome,
  required int echtAway,
}) {
  if (voorspeldHome == echtHome && voorspeldAway == echtAway) return 10;
  if (echtHome == echtAway && voorspeldHome == voorspeldAway) return 7;

  int punten = 0;
  final winnaarEcht = echtHome.compareTo(echtAway);
  final winnaarVoorspeld = voorspeldHome.compareTo(voorspeldAway);

  if (winnaarEcht == winnaarVoorspeld && winnaarEcht != 0) {
    punten = 5;
    if (voorspeldHome == echtHome) punten += 2;
    if (voorspeldAway == echtAway) punten += 2;
  } else {
    if (voorspeldHome == echtHome) punten += 2;
    if (voorspeldAway == echtAway) punten += 2;
  }

  return punten;
}

class PouleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkUniqueName(String name) async {
    final snapshot = await _firestore
        .collection('poules')
        .where('name', isEqualTo: name)
        .get();
    return snapshot.docs.isEmpty;
  }

  Future<void> createPoule(Poule poule) async {
    final pouleRef = _firestore.collection('poules').doc(poule.id);
    await pouleRef.set(poule.toMap());

    await pouleRef.collection('deelnemers').doc(poule.ownerId).set({
      'rol': 'eigenaar',
      'joinedAt': Timestamp.now(),
      'punten': 0,
    });
  }

  /// Verwerk punten voor ALLE poulevormen waar deze wedstrijd in voorkomt:
  /// - 'poule_predictions'   (DDA)
  /// - 'poule_voorspellingen' (DDB)
  /// - 'predictions'          (één-team)
  ///
  /// NB: we filteren overal op `matchId` (niet 'wedstrijdId').
  Future<void> verwerkPuntenVoorPouleVoorspellingen({
    required String pouleId,
    required String matchId,
    required int echteHome,
    required int echteAway,
  }) async {
    developer.log('🔍 Start poulepunten voor poule=$pouleId, match=$matchId');

    // Haal wedstrijd-datum op (voor deadline 12:00 op wedstrijddag)
    final matchDoc = await _firestore.collection('matches').doc(matchId).get();
    final matchData = matchDoc.data();
    final Timestamp? ts = (matchData?['timestamp'] as Timestamp?) ??
        (matchData?['datum'] as Timestamp?);
    if (ts == null) {
      developer.log(
          '⚠️ Geen datum/timestamp bij match $matchId — skip deadline-check.');
    }
    final DateTime? deadline = ts == null
        ? null
        : DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day, 12);

    // Verwerk de drie collecties
    await _verwerkCollectieVoorPoule(
      collectieNaam: 'poule_predictions', // DDA
      pouleId: pouleId,
      matchId: matchId,
      echteHome: echteHome,
      echteAway: echteAway,
      deadline: deadline,
    );

    await _verwerkCollectieVoorPoule(
      collectieNaam: 'poule_voorspellingen', // DDB
      pouleId: pouleId,
      matchId: matchId,
      echteHome: echteHome,
      echteAway: echteAway,
      deadline: deadline,
    );

    await _verwerkCollectieVoorPoule(
      collectieNaam: 'predictions', // één-team poules
      pouleId: pouleId,
      matchId: matchId,
      echteHome: echteHome,
      echteAway: echteAway,
      deadline: deadline,
    );

    developer.log('✅ Poulepunten afgerond voor poule=$pouleId, match=$matchId');
  }

  Future<void> _verwerkCollectieVoorPoule({
    required String collectieNaam,
    required String pouleId,
    required String matchId,
    required int echteHome,
    required int echteAway,
    required DateTime? deadline,
  }) async {
    // Zoek alleen voorspellingen van deze poule en match
    final snap = await _firestore
        .collection(collectieNaam)
        .where('pouleId', isEqualTo: pouleId)
        .where('matchId', isEqualTo: matchId)
        .get();

    if (snap.docs.isEmpty) {
      developer.log(
          'ℹ️ Geen voorspellingen in $collectieNaam voor poule=$pouleId, match=$matchId');
      return;
    }

    final String uitslagKey = '$echteHome-$echteAway';
    final Map<String, int> plusPerDeelnemer =
        {}; // userId -> +punten (som in deze collectie)

    for (final d in snap.docs) {
      final m = d.data();

      final String? gebruikerId = (m['gebruikerId'] ?? '').toString().isEmpty
          ? null
          : (m['gebruikerId'] as String);

      // NB: in alle poulecollecties gebruiken we 'matchId' en scoreThuis/scoreUit
      final int voorspeldHome =
          int.tryParse(m['scoreThuis']?.toString() ?? '') ?? 0;
      final int voorspeldAway =
          int.tryParse(m['scoreUit']?.toString() ?? '') ?? 0;

      final DateTime? ingevuldOp = (m['timestamp'] as Timestamp?)?.toDate();
      final bool alVerwerkt = m['verwerkt'] == true;
      final String vorigeUitslag = (m['verwerktVoorUitslag'] ?? '').toString();
      final int oudePunten = (m['punten'] ?? 0) as int;

      if (gebruikerId == null) continue;

      // Deadline: alleen beoordelen als vóór (of zonder bekende) deadline
      if (deadline != null) {
        if (ingevuldOp == null || ingevuldOp.isAfter(deadline)) {
          // Te laat ingevuld: overslaan
          continue;
        }
      }

      // Als niets is veranderd t.o.v. al verwerkte uitslag: door
      if (alVerwerkt && vorigeUitslag == uitslagKey) {
        continue;
      }

      // 1) Oude punten afboeken bij deelnemer (indien aanwezig)
      if (alVerwerkt && oudePunten != 0) {
        final deelnemerRef = _firestore
            .collection('poules')
            .doc(pouleId)
            .collection('deelnemers')
            .doc(gebruikerId);

        await deelnemerRef.set(
          {'punten': FieldValue.increment(-oudePunten)},
          SetOptions(merge: true),
        );
      }

      // 2) Nieuwe punten berekenen en opslaan op voorspelling
      final int nieuwePunten = berekenPuntenVoorVoorspelling(
        voorspeldHome: voorspeldHome,
        voorspeldAway: voorspeldAway,
        echtHome: echteHome,
        echtAway: echteAway,
      );

      await d.reference.update({
        'punten': nieuwePunten,
        'verwerkt': true,
        'verwerktVoorUitslag': uitslagKey,
      });

      // 3) Optellen in batchmap; schrijven we hieronder per deelnemer weg
      plusPerDeelnemer[gebruikerId] =
          (plusPerDeelnemer[gebruikerId] ?? 0) + nieuwePunten;

      developer.log(
        '📊 [$collectieNaam] $gebruikerId voorspelde $voorspeldHome-$voorspeldAway → $nieuwePunten p',
      );
    }

    // 4) Deelnemerspunten bijwerken (één write per deelnemer)
    for (final entry in plusPerDeelnemer.entries) {
      final deelnemerRef = _firestore
          .collection('poules')
          .doc(pouleId)
          .collection('deelnemers')
          .doc(entry.key);

      await deelnemerRef.set(
        {'punten': FieldValue.increment(entry.value)},
        SetOptions(merge: true),
      );

      developer.log(
          '💾 [$collectieNaam] deelnemer ${entry.key} +${entry.value} punten');
    }
  }
}
