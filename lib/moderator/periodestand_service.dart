import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodestandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === Normalisatie helpers ===
  String _normKey(String s) =>
      s.toUpperCase().replaceAll(RegExp(r"[\s\-/\.'’]"), '');

  static const List<String> _clubsA = [
    'DOVO','Eemdijk','Scherpenzeel','Staphorst','DVS33 Ermelo',
    'Sparta Nijkerk','TEC','Urk','Hoogeveen','HSC21',
    'Sportlust46','Excelsior31','Hercules','SC Genemuiden','Huizen',
    'Harkemase Boys','Rohda Raalte','ADO20',
  ];

  static const List<String> _clubsB = [
    'Noordwijk','Scheveningen','SteDoCo','Zwaluwen','Kloetinge',
    'RBC','Groene Ster','Rijnvogels','UNA','ASWH',
    'UDI19','TOGB','FC Lisse','Gemert','sv Meerssen',
    'Blauw Geel38 JUMBO','Goes','VVSB',
  ];

  final Map<String, String> _normMapA = {
    for (final name in _clubsA) 
      // key -> canonical display name
      (name.toUpperCase().replaceAll(RegExp(r"[\s\-/\.'’]"), '')): name
  };

  final Map<String, String> _normMapB = {
    for (final name in _clubsB)
      (name.toUpperCase().replaceAll(RegExp(r"[\s\-/\.'’]"), '')): name
  };

  String _canonName(String divisieCode, String raw) {
    final key = _normKey(raw);
    final map = (divisieCode.toUpperCase() == 'A') ? _normMapA : _normMapB;
    return map[key] ?? raw; // fallback
  }

  // === Periode ranges zonder records ===
  List<int> _periodeRange(int periode) {
    if (periode == 1) return [1, 12];
    if (periode == 2) return [13, 23];
    return [24, 34];
  }

  Future<void> herberekenAllePeriodesVoorDivisie(String divisieCode) async {
    for (int periode = 1; periode <= 3; periode++) {
      await _herberekenPeriode(divisieCode, periode);
    }
  }

  Future<void> _herberekenPeriode(String divisieCode, int periode) async {
    final competitie = divisieCode.toUpperCase() == 'A'
        ? 'Derde Divisie A'
        : 'Derde Divisie B';

    final range = _periodeRange(periode);
    final startRonde = range[0];
    final endRonde = range[1];

    // Gebruik één range op 'speelronde' (geen whereIn, geen tweede range)
    final snapshot = await _firestore
        .collection('matches')
        .where('competitie', isEqualTo: competitie)
        .where('speelronde', isGreaterThanOrEqualTo: startRonde)
        .where('speelronde', isLessThanOrEqualTo: endRonde)
        .get();

    final Map<String, Map<String, dynamic>> standen = {};
    final Set<String> alleTeams = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final th = data['uitslagThuis'];
      final ut = data['uitslagUit'];
      if (th == null || ut == null) continue; // alleen verwerkte uitslagen

      final int scoreThuis = (th as num).toInt();
      final int scoreUit = (ut as num).toInt();

      final String rawHome =
    (data['homeTeamCode'] ?? data['homeTeam'] ?? data['thuisteam'] ?? '').toString();
final String rawAway =
    (data['awayTeamCode'] ?? data['awayTeam'] ?? data['uitteam'] ?? '').toString();

      if (rawHome.isEmpty || rawAway.isEmpty) continue;

      final String home = _canonName(divisieCode, rawHome);
      final String away = _canonName(divisieCode, rawAway);

      alleTeams.add(home);
      alleTeams.add(away);

      standen.putIfAbsent(home, _initStats);
      standen.putIfAbsent(away, _initStats);

      // Wedstrijden + doelpunten
      standen[home]!['gespeeld'] += 1;
      standen[away]!['gespeeld'] += 1;
      standen[home]!['doelpuntenVoor'] += scoreThuis;
      standen[home]!['doelpuntenTegen'] += scoreUit;
      standen[away]!['doelpuntenVoor'] += scoreUit;
      standen[away]!['doelpuntenTegen'] += scoreThuis;

      // Punten
      if (scoreThuis > scoreUit) {
        standen[home]!['gewonnen'] += 1;
        standen[home]!['punten'] += 3;
        standen[away]!['verloren'] += 1;
      } else if (scoreUit > scoreThuis) {
        standen[away]!['gewonnen'] += 1;
        standen[away]!['punten'] += 3;
        standen[home]!['verloren'] += 1;
      } else {
        standen[home]!['gelijk'] += 1;
        standen[away]!['gelijk'] += 1;
        standen[home]!['punten'] += 1;
        standen[away]!['punten'] += 1;
      }
    }

    // Ook teams zonder gespeelde wedstrijden opnemen
    for (final team in alleTeams) {
      standen.putIfAbsent(team, _initStats);
    }

    // Doelsaldo
    for (final stats in standen.values) {
      stats['doelsaldo'] =
          (stats['doelpuntenVoor'] as int) - (stats['doelpuntenTegen'] as int);
    }

    // Sortering
    final gesorteerd = standen.entries.toList()
      ..sort((a, b) {
        final pa = a.value['punten'] as int;
        final pb = b.value['punten'] as int;
        if (pa != pb) return pb.compareTo(pa);

        final ga = a.value['gespeeld'] as int;
        final gb = b.value['gespeeld'] as int;
        if (ga != gb) return ga.compareTo(gb);

        final dsa = a.value['doelsaldo'] as int;
        final dsb = b.value['doelsaldo'] as int;
        if (dsa != dsb) return dsb.compareTo(dsa);

        final dva = a.value['doelpuntenVoor'] as int;
        final dvb = b.value['doelpuntenVoor'] as int;
        if (dva != dvb) return dvb.compareTo(dva);

        final dta = a.value['doelpuntenTegen'] as int;
        final dtb = b.value['doelpuntenTegen'] as int;
        if (dta != dtb) return dta.compareTo(dtb);

        return a.key.compareTo(b.key);
      });

    final divisieDocId = divisieCode.toUpperCase() == 'A' ? 'dda' : 'ddb';
    final periodeCollectionRef = _firestore
        .collection('periodestanden')
        .doc(divisieDocId)
        .collection('periode_$periode');

    // Oude docs weggooien (schone herberekening)
    final oudeDocs = await periodeCollectionRef.get();
    for (final d in oudeDocs.docs) {
      await d.reference.delete();
    }

    // Nieuwe standen opslaan
    int positie = 1;
    for (final entry in gesorteerd) {
      await periodeCollectionRef.doc(entry.key).set({
        'club': entry.key,  // displaynaam die de UI ook gebruikt
        'positie': positie,
        ...entry.value,
      });
      positie++;
    }
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
}
