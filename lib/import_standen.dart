// ❗ Alleen handmatig gebruiken voor het importeren van clubstanden in Firestore
// Gebruik in main() met: await importStanden();


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> importStandenZonderApostrof() async {
  final firestore = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> clubs = [
    // Derde Divisie A
    {'club': 'DOVO', 'divisie': 'Derde Divisie A'},
    {'club': 'Eemdijk', 'divisie': 'Derde Divisie A'},
    {'club': 'Scherpenzeel', 'divisie': 'Derde Divisie A'},
    {'club': 'Staphorst', 'divisie': 'Derde Divisie A'},
    {'club': 'DVS33 Ermelo', 'divisie': 'Derde Divisie A'},
    {'club': 'Sparta Nijkerk', 'divisie': 'Derde Divisie A'},
    {'club': 'TEC', 'divisie': 'Derde Divisie A'},
    {'club': 'Urk', 'divisie': 'Derde Divisie A'},
    {'club': 'Hoogeveen', 'divisie': 'Derde Divisie A'},
    {'club': 'HSC21', 'divisie': 'Derde Divisie A'},
    {'club': 'Sportlust46', 'divisie': 'Derde Divisie A'},
    {'club': 'Excelsior31', 'divisie': 'Derde Divisie A'},
    {'club': 'Hercules', 'divisie': 'Derde Divisie A'},
    {'club': 'SC Genemuiden', 'divisie': 'Derde Divisie A'},
    {'club': 'Huizen', 'divisie': 'Derde Divisie A'},
    {'club': 'Harkemase Boys', 'divisie': 'Derde Divisie A'},
    {'club': 'Rohda Raalte', 'divisie': 'Derde Divisie A'},
    {'club': 'ADO20', 'divisie': 'Derde Divisie A'},

    // Derde Divisie B
    {'club': 'Noordwijk', 'divisie': 'Derde Divisie B'},
    {'club': 'Scheveningen', 'divisie': 'Derde Divisie B'},
    {'club': 'SteDoCo', 'divisie': 'Derde Divisie B'},
    {'club': 'Zwaluwen', 'divisie': 'Derde Divisie B'},
    {'club': 'Kloetinge', 'divisie': 'Derde Divisie B'},
    {'club': 'RBC', 'divisie': 'Derde Divisie B'},
    {'club': 'Groene Ster', 'divisie': 'Derde Divisie B'},
    {'club': 'Rijnvogels', 'divisie': 'Derde Divisie B'},
    {'club': 'UNA', 'divisie': 'Derde Divisie B'},
    {'club': 'ASWH', 'divisie': 'Derde Divisie B'},
    {'club': 'UDI19', 'divisie': 'Derde Divisie B'},
    {'club': 'TOGB', 'divisie': 'Derde Divisie B'},
    {'club': 'FC Lisse', 'divisie': 'Derde Divisie B'},
    {'club': 'Gemert', 'divisie': 'Derde Divisie B'},
    {'club': 'sv Meerssen', 'divisie': 'Derde Divisie B'},
    {'club': 'Blauw Geel38 JUMBO', 'divisie': 'Derde Divisie B'},
    {'club': 'Goes', 'divisie': 'Derde Divisie B'},
    {'club': 'VVSB', 'divisie': 'Derde Divisie B'},
  ];

  for (var club in clubs) {
    final String id = club['club']
        .toString()
        .replaceAll(RegExp(r"[^\w\s]"), '') // verwijder alle niet-letters/nummers/spaties
        .replaceAll(' ', ''); // spaties ook weg voor ID

    await firestore.collection('standen').doc(id).set({
      'club': club['club'], // laat hier wel de echte naam mét spaties staan
      'divisie': club['divisie'],
      'gespeeld': 0,
      'gewonnen': 0,
      'gelijk': 0,
      'verloren': 0,
      'doelpuntenVoor': 0,
      'doelpuntenTegen': 0,
      'punten': 0,
    });
  }

  debugPrint('✅ Clubs zonder apostrof/spaties zijn correct geïmporteerd.');
}

