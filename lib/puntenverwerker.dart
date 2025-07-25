import 'package:cloud_firestore/cloud_firestore.dart';
import 'puntenlogica.dart';

Future<void> verwerkUitslagVoorWedstrijd(String wedstrijdId) async {
  final firestore = FirebaseFirestore.instance;

  print('--- Start verwerking punten voor wedstrijd: $wedstrijdId ---');

  // 1. Haal de wedstrijdgegevens op
  final matchDoc = await firestore.collection('matches').doc(wedstrijdId).get();
  if (!matchDoc.exists) {
    print('⚠️ Wedstrijd niet gevonden in Firestore: $wedstrijdId');
    return;
  }

  final data = matchDoc.data()!;
  print('🏟️ Wedstrijddata: $data');

  final uitslagThuis = data['uitslagThuis'];
  final uitslagUit = data['uitslagUit'];

  print('⚽ Uitslag opgehaald - thuis: $uitslagThuis, uit: $uitslagUit');

  if (uitslagThuis == null || uitslagUit == null) {
    print('⚠️ Waarschuwing: uitslagThuis of uitslagUit is null! Vul deze velden in Firestore.');
    return;
  }

  // 2. Haal alle voorspellingen op uit de subcollectie van deze wedstrijd
  final voorspellingenQuery = await firestore
      .collection('matches')
      .doc(wedstrijdId)
      .collection('voorspellingen')
      .get();

  print('📊 Aantal voorspellingen gevonden: ${voorspellingenQuery.docs.length}');

  // 3. Loop door elke voorspelling en bereken punten
  for (var doc in voorspellingenQuery.docs) {
    final voorspelling = doc.data();
    print('🔎 Voorspelling data document "${doc.id}": $voorspelling');

    // Controleer of de veldnamen bestaan en print ze uit
    final voorspeldThuisRaw = voorspelling['scoreThuis'];
    final voorspeldUitRaw = voorspelling['scoreUit'];
    print('🏠 Voorspelde score thuis (raw): $voorspeldThuisRaw');
    print('🚪 Voorspelde score uit (raw): $voorspeldUitRaw');

    // Probeer te parsen, default naar 0 als niet mogelijk
    final voorspeldThuis = int.tryParse(voorspeldThuisRaw.toString()) ?? 0;
    final voorspeldUit = int.tryParse(voorspeldUitRaw.toString()) ?? 0;

    print('🔍 Voorspelling door ${doc.id} - Thuis: $voorspeldThuis, Uit: $voorspeldUit');

    // Bereken punten met je puntentelling
    final punten = berekenPunten(
      voorspeldThuis: voorspeldThuis,
      voorspeldUit: voorspeldUit,
      echtThuis: uitslagThuis,
      echtUit: uitslagUit,
    );

    print('✅ Punten berekend: $punten');

    // 4. Update document met berekende punten
    await firestore
        .collection('matches')
        .doc(wedstrijdId)
        .collection('voorspellingen')
        .doc(doc.id)
        .update({'punten': punten});

    print('🔄 Punten opgeslagen voor voorspelling ${doc.id}');
  }

  print('--- Punten verwerkt voor wedstrijd $wedstrijdId ---');
}
