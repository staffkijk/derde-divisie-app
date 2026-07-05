import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

final _firestore = FirebaseFirestore.instance;

/// Verwerk alle voorspellingen van een bepaalde wedstrijd en update gebruikerspunten.
Future<void> verwerkVoorspellingenVoorWedstrijd(
    String wedstrijdId, int echtThuis, int echtUit) async {
  final voorspellingen = await _firestore
      .collection('matches')
      .doc(wedstrijdId)
      .collection('voorspellingen')
      .get();

  for (final doc in voorspellingen.docs) {
    final data = doc.data();
    final gebruikerId = data['gebruikerId'];
    final scoreThuis = int.tryParse(data['scoreThuis']?.toString() ?? '') ?? 0;
    final scoreUit = int.tryParse(data['scoreUit']?.toString() ?? '') ?? 0;
    final oudePunten = data['punten'] ?? 0;

    if (gebruikerId == null || gebruikerId.toString().isEmpty) {
      developer.log('⚠️ Ongeldig gebruikerId in voorspelling ${doc.id}');
      continue;
    }

    final gebruikerRef = _firestore.collection('users').doc(gebruikerId);
    final gebruikerDoc = await gebruikerRef.get();

    if (!gebruikerDoc.exists) {
      developer.log(
          '⚠️ Gebruiker $gebruikerId bestaat niet (voorspelling ${doc.id}) — overslaan');
      continue;
    }

    final nieuwePunten = berekenPunten(
      voorspeldThuis: scoreThuis,
      voorspeldUit: scoreUit,
      echtThuis: echtThuis,
      echtUit: echtUit,
    );

    // Update voorspelling met nieuwe punten
    await doc.reference.update({'punten': nieuwePunten});

    // Voeg 'punten' toe of werk bij
    if (!gebruikerDoc.data()!.containsKey('punten')) {
      await gebruikerRef.set({'punten': nieuwePunten}, SetOptions(merge: true));
      developer.log(
          '✅ Punten toegevoegd voor nieuwe gebruiker $gebruikerId: $nieuwePunten');
    } else {
      final verschil = nieuwePunten - oudePunten;
      await gebruikerRef.update({
        'punten': FieldValue.increment(verschil),
      });
      developer.log('✅ Punten bijgewerkt voor $gebruikerId: +$verschil');
    }
  }
}

/// Puntentelling op basis van regels
int berekenPunten({
  required int voorspeldThuis,
  required int voorspeldUit,
  required int echtThuis,
  required int echtUit,
}) {
  if (voorspeldThuis == echtThuis && voorspeldUit == echtUit) {
    return 10;
  }

  final voorspeldWinst = voorspeldThuis.compareTo(voorspeldUit);
  final echtWinst = echtThuis.compareTo(echtUit);

  if (voorspeldWinst == 0 && echtWinst == 0) {
    return 7; // Gelijkspel goed
  }

  int punten = 0;

  if (voorspeldWinst == echtWinst) {
    punten += 5;
  }

  if (voorspeldThuis == echtThuis) punten += 2;
  if (voorspeldUit == echtUit) punten += 2;

  return punten > 10 ? 10 : punten;
}
