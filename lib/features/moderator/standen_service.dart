import 'package:cloud_firestore/cloud_firestore.dart';

class StandenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Correcte teams Derde Divisie A
  static const List<String> teamsDivisieA = [
    'DOVO', 'Eemdijk', 'Scherpenzeel', 'Staphorst', 'DVS33 Ermelo',
    'Sparta Nijkerk', 'TEC', 'Urk', 'Hoogeveen', 'HSC21',
    'Sportlust46', 'Excelsior31', 'Hercules', 'SC Genemuiden',
    'Huizen', 'Harkemase Boys', 'Rohda Raalte', 'ADO20',
  ];

  // Correcte teams Derde Divisie B
  static const List<String> teamsDivisieB = [
    'Noordwijk', 'Scheveningen', 'SteDoCo', 'Zwaluwen', 'Kloetinge',
    'RBC', 'Groene Ster', 'Rijnvogels', 'UNA', 'ASWH',
    'UDI19', 'TOGB', 'FC Lisse', 'Gemert', 'sv Meerssen',
    'Blauw Geel38 JUMBO', 'Goes', 'VVSB',
  ];

  /// Converteert een teamnaam naar een gestandaardiseerde code (zonder spaties/tekens, lowercase)
  String _teamCode(String naam) {
    return naam.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Map<String, dynamic> _initStats() => {
        'gespeeld': 0,
        'gewonnen': 0,
        'gelijk': 0,
        'verloren': 0,
        'doelpuntenVoor': 0,
        'doelpuntenTegen': 0,
        'punten': 0,
        'doelsaldo': 0,
      };

  Future<void> herberekenStandVoorDivisie(String divisieCode) async {
    final competitieNaam =
        divisieCode == 'A' ? 'Derde Divisie A' : 'Derde Divisie B';

    final matches = await _firestore
        .collection('matches')
        .where('competitie', isEqualTo: competitieNaam)
        .get();

    final Map<String, Map<String, dynamic>> stand = {};

    // Initieer alle teams met code
    final List<String> alleTeams =
        divisieCode == 'A' ? teamsDivisieA : teamsDivisieB;
    for (final team in alleTeams) {
      stand[_teamCode(team)] = _initStats()..['club'] = team;
    }

    // Verwerk gespeelde wedstrijden
    for (final doc in matches.docs) {
      final data = doc.data();

      String? homeName = data['thuisteam'];
      String? awayName = data['uitteam'];

      // fallback: gebruik eventueel homeTeamCode/awayTeamCode
      String? homeCode =
          data['homeTeamCode'] ?? (homeName != null ? _teamCode(homeName) : null);
      String? awayCode =
          data['awayTeamCode'] ?? (awayName != null ? _teamCode(awayName) : null);

      final scoreThuis = data['uitslagThuis'];
      final scoreUit = data['uitslagUit'];

      if (homeName == null || awayName == null) continue;
      if (homeCode == null || awayCode == null) continue;
      if (scoreThuis == null || scoreUit == null) continue;

      // Sla ontbrekende codes meteen terug in Firestore
      if (data['homeTeamCode'] == null || data['awayTeamCode'] == null) {
        await doc.reference.update({
          'homeTeamCode': homeCode,
          'awayTeamCode': awayCode,
        });
      }

      // Zorg dat teams bestaan in de stand
      stand.putIfAbsent(homeCode, () => _initStats()..['club'] = homeName);
      stand.putIfAbsent(awayCode, () => _initStats()..['club'] = awayName);

      // Update statistieken
      stand[homeCode]!['gespeeld'] += 1;
      stand[awayCode]!['gespeeld'] += 1;

      stand[homeCode]!['doelpuntenVoor'] += scoreThuis;
      stand[homeCode]!['doelpuntenTegen'] += scoreUit;
      stand[awayCode]!['doelpuntenVoor'] += scoreUit;
      stand[awayCode]!['doelpuntenTegen'] += scoreThuis;

      if (scoreThuis > scoreUit) {
        stand[homeCode]!['gewonnen'] += 1;
        stand[homeCode]!['punten'] += 3;
        stand[awayCode]!['verloren'] += 1;
      } else if (scoreUit > scoreThuis) {
        stand[awayCode]!['gewonnen'] += 1;
        stand[awayCode]!['punten'] += 3;
        stand[homeCode]!['verloren'] += 1;
      } else {
        stand[homeCode]!['gelijk'] += 1;
        stand[awayCode]!['gelijk'] += 1;
        stand[homeCode]!['punten'] += 1;
        stand[awayCode]!['punten'] += 1;
      }
    }

    // Voeg doelsaldo toe
    for (final stats in stand.values) {
      stats['doelsaldo'] =
          stats['doelpuntenVoor'] - stats['doelpuntenTegen'];
    }

    // Oude standen verwijderen
    final oude = await _firestore
        .collection('standen')
        .where('competitie', isEqualTo: competitieNaam)
        .get();
    for (final doc in oude.docs) {
      await doc.reference.delete();
    }

    // Nieuwe standen opslaan
    for (final entry in stand.entries) {
      await _firestore.collection('standen').doc(entry.key).set({
        'competitie': competitieNaam,
        'club': entry.value['club'], // nette naam voor weergave
        'gespeeld': entry.value['gespeeld'],
        'gewonnen': entry.value['gewonnen'],
        'gelijk': entry.value['gelijk'],
        'verloren': entry.value['verloren'],
        'doelpuntenVoor': entry.value['doelpuntenVoor'],
        'doelpuntenTegen': entry.value['doelpuntenTegen'],
        'punten': entry.value['punten'],
        'doelsaldo': entry.value['doelsaldo'],
      });
    }
  }

  Future<void> herberekenStandenVoorCompetitie(String competitieNaam) async {
    final code = competitieNaam.contains('A') ? 'A' : 'B';
    await herberekenStandVoorDivisie(code);
  }
}
