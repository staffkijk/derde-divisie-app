import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('EindstandVerwerker');

/// Normaliseer clubnamen zodat we voorspellingen en matches betrouwbaar kunnen vergelijken.
String _norm(String s) => (s)
    .replaceAll('’', '')
    .replaceAll("'", '')
    .replaceAll(' ', '')
    .replaceAll('/', '')
    .toUpperCase();

/// Bereken en verwerk eindstand-punten voor één divisie ('A' of 'B').
/// Idempotent: we schrijven NIET hard het totaal weg, maar verhogen users.punten_X met de delta t.o.v. vorige eindstandpunten.
Future<void> verwerkEindstandPunten(String divisieLetter) async {
  assert(divisieLetter == 'A' || divisieLetter == 'B');
  final firestore = FirebaseFirestore.instance;
  final competitieNaam = 'Derde Divisie $divisieLetter';

  // 1) Alle matches met uitslag ophalen
  final matchesSnapshot = await firestore
      .collection('matches')
      .where('competitie', isEqualTo: competitieNaam)
      .get();

  final matches = matchesSnapshot.docs.where((doc) {
    final d = doc.data();
    return d['uitslagThuis'] is int && d['uitslagUit'] is int;
  }).toList();

  // 2) Eindstand opbouwen
  final Map<String, Map<String, int>> clubPunten = {};
  void initClub(String norm) {
    clubPunten.putIfAbsent(norm, () => {
          'punten': 0,
          'doelsaldo': 0,
          'gespeeld': 0,
          'doelpuntenVoor': 0,
        });
  }

  for (final m in matches) {
    final data = m.data();
    final thuisRaw = (data['thuisteam'] ?? '') as String;
    final uitRaw = (data['uitteam'] ?? '') as String;
    if (thuisRaw.isEmpty || uitRaw.isEmpty) continue;

    final home = _norm(thuisRaw);
    final away = _norm(uitRaw);

    final h = data['uitslagThuis'] as int;
    final a = data['uitslagUit'] as int;

    initClub(home);
    initClub(away);

    clubPunten[home]!['gespeeld'] = clubPunten[home]!['gespeeld']! + 1;
    clubPunten[away]!['gespeeld'] = clubPunten[away]!['gespeeld']! + 1;

    clubPunten[home]!['doelpuntenVoor'] =
        clubPunten[home]!['doelpuntenVoor']! + h;
    clubPunten[away]!['doelpuntenVoor'] =
        clubPunten[away]!['doelpuntenVoor']! + a;

    clubPunten[home]!['doelsaldo'] =
        clubPunten[home]!['doelsaldo']! + (h - a);
    clubPunten[away]!['doelsaldo'] =
        clubPunten[away]!['doelsaldo']! + (a - h);

    if (h > a) {
      clubPunten[home]!['punten'] = clubPunten[home]!['punten']! + 3;
    } else if (h < a) {
      clubPunten[away]!['punten'] = clubPunten[away]!['punten']! + 3;
    } else {
      clubPunten[home]!['punten'] = clubPunten[home]!['punten']! + 1;
      clubPunten[away]!['punten'] = clubPunten[away]!['punten']! + 1;
    }
  }

  // 3) Sorteren volgens tiebreakers
  final ranking = clubPunten.entries.toList()
    ..sort((a, b) {
      final A = a.value, B = b.value;
      final av = (A['punten']! * 1000000) +
          ((1000 - A['gespeeld']!) * 10000) +
          (A['doelsaldo']! * 100) +
          A['doelpuntenVoor']!;
      final bv = (B['punten']! * 1000000) +
          ((1000 - B['gespeeld']!) * 10000) +
          (B['doelsaldo']! * 100) +
          B['doelpuntenVoor']!;
      return bv.compareTo(av);
    });

  // genormaliseerde club -> 0-based positie
  final Map<String, int> posByNorm = {
    for (int i = 0; i < ranking.length; i++) ranking[i].key: i,
  };

  // 4) Eindstand-voorspellingen voor deze divisie
  final voorspellingenSnapshot = await firestore
      .collection('eindstand_voorspellingen')
      .where('divisie', isEqualTo: divisieLetter)
      .get();

  // 5) Verwerking per voorspelling
  for (final doc in voorspellingenSnapshot.docs) {
    final data = doc.data();
    final uid = (data['gebruikerId'] ?? '') as String;
    final List<String> voorspelling =
        List<String>.from(data['voorspelling'] ?? const []);
    if (uid.isEmpty || voorspelling.isEmpty) continue;

    // Bereken nieuw puntenaantal
    int nieuw = 0;
    for (int i = 0; i < voorspelling.length; i++) {
      final clubNorm = _norm(voorspelling[i]);
      final echteIndex = posByNorm[clubNorm];
      if (echteIndex == null) continue;

      if (echteIndex == 0 && i == 0) {
        nieuw += 30;
      } else if (echteIndex == i) {
        nieuw += 10;
      } else if ((echteIndex - i).abs() == 1) {
        nieuw += 6;
      } else if ((echteIndex - i).abs() == 2) {
        nieuw += 2;
      }
    }

    // Vorige eindstandpunten ophalen uit dit doc (A of B)
    final prevFromDoc = divisieLetter == 'A'
        ? (data['eindstand_A_punten'] ?? 0)
        : (data['eindstand_B_punten'] ?? 0);
    final oud = (prevFromDoc is int)
        ? prevFromDoc
        : int.tryParse('$prevFromDoc') ?? 0;

    final delta = nieuw - oud; // wat er bij/af moet

    final userRef = firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final u = userSnap.data() ?? {};

    final veldnaam = divisieLetter == 'A' ? 'punten_A' : 'punten_B';
    final awardFlag =
        divisieLetter == 'A' ? 'eindstandA_awarded' : 'eindstandB_awarded';
    final markerVeld = 'eindstand_${divisieLetter}_punten';

    // 6) Users-punten verhogen met delta (idempotent)
    if (delta != 0) {
      await userRef.update({veldnaam: FieldValue.increment(delta)});
    }
    await userRef.set({awardFlag: true}, SetOptions(merge: true));

    // 7) totalen bijwerken op basis van nieuwe A/B waarden
    int puntenA = (u['punten_A'] ?? 0) as int;
    int puntenB = (u['punten_B'] ?? 0) as int;
    if (divisieLetter == 'A') {
      puntenA += delta;
    } else {
      puntenB += delta;
    }
    final hoogste = puntenA > puntenB ? puntenA : puntenB;
    await userRef.set({'totalen': hoogste}, SetOptions(merge: true));

    // 8) Logging in voorspel_punten (zet actuele eindstandpunten)
    await firestore.collection('voorspel_punten').doc(uid).set({
      markerVeld: nieuw,
    }, SetOptions(merge: true));

    // 9) Marker in eindstand_voorspellingen updaten (zodat volgende run de delta correct is)
    await doc.reference.set({
      markerVeld: nieuw,
      if (divisieLetter == 'A') 'eindstand_A_punten': nieuw,
      if (divisieLetter == 'B') 'eindstand_B_punten': nieuw,
    }, SetOptions(merge: true));

    _log.info(
      '✅ eindstandpunten $nieuw (delta $delta) toegepast voor $uid (divisie $divisieLetter)',
    );
  }
}

/// Wrapper voor beide divisies
Future<void> verwerkEindstandPuntenBeide() async {
  _log.info('▶️ Start verwerking eindstandpunten voor A en B...');
  await verwerkEindstandPunten('A');
  await verwerkEindstandPunten('B');
  _log.info('✅ Verwerking A en B afgerond');
}
