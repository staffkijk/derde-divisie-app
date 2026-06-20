import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('TeamcodeUpdater');

// ✅ Dit moet exact je officiële mapping zijn (zoals je in de app gebruikt)
const Map<String, String> teamCodeMapping = {
  'ADO\'20': 'ADO20',
  'ASWH': 'ASWH',
  'Blauw Geel\'38/JUMBO': 'BlauwGeel38JUMBO',
  'DOVO': 'DOVO',
  'DVS33 Ermelo': 'DVS33Ermelo',
  'Eemdijk': 'Eemdijk',
  'Excelsior\'31': 'Excelsior31',
  'FC Lisse': 'FCLisse',
  'Gemert': 'Gemert',
  'Goes': 'Goes',
  'Groene Ster': 'GroeneSter',
  'Harkemase Boys': 'HarkemaseBoys',
  'Hercules': 'Hercules',
  'Hoogeveen': 'Hoogeveen',
  'HSC\'21': 'HSC21',
  'Huizen': 'Huizen',
  'Kloetinge': 'Kloetinge',
  'Noordwijk': 'Noordwijk',
  'RBC': 'RBC',
  'Rijnvogels': 'Rijnvogels',
  'Rohda Raalte': 'RohdaRaalte',
  'SC Genemuiden': 'SCGenemuiden',
  'Scherpenzeel': 'Scherpenzeel',
  'Scheveningen': 'Scheveningen',
  'Sparta Nijkerk': 'SpartaNijkerk',
  'Sportlust \'46': 'Sportlust46',
  'Staphorst': 'Staphorst',
  'SteDoCo': 'SteDoCo',
  'sv Meerssen': 'svMeerssen',
  'TEC': 'TEC',
  'TOGB': 'TOGB',
  'UDI\'19': 'UDI19',
  'UNA': 'UNA',
  'Urk': 'Urk',
  'VVSB': 'VVSB',
  'Zwaluwen': 'Zwaluwen',
};

Future<void> voegTeamcodesToeAanWedstrijden() async {
  final firestore = FirebaseFirestore.instance;
  final matches = await firestore.collection('matches').get();

  for (final doc in matches.docs) {
    final data = doc.data();
    final thuisteam = data['thuisteam']?.toString() ?? '';
    final uitteam = data['uitteam']?.toString() ?? '';

    final homeCode = teamCodeMapping[thuisteam];
    final awayCode = teamCodeMapping[uitteam];

    if (homeCode == null || awayCode == null) {
      _log.info('✅ Alles verwerkt');
('⚠️ Niet gevonden in mapping bij wedstrijd ${doc.id}:');
      if (homeCode == null) _log.info('  → thuisteam: "$thuisteam"');
      if (awayCode == null) _log.info('  → uitteam: "$uitteam"');
      continue; // skip deze wedstrijd
    }

    await doc.reference.update({
      'homeTeamCode': homeCode,
      'awayTeamCode': awayCode,
    });

    _log.info('✅ Alles verwerkt');
('✅ Bijgewerkt: ${doc.id} → $homeCode vs $awayCode');
  }

  _log.info('✅ Alles verwerkt');
('🎉 Alle bekende wedstrijden zijn bijgewerkt.');
}
