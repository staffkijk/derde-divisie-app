import 'package:cloud_firestore/cloud_firestore.dart';

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = (v ?? '').toString().trim().replaceAll('\u2212', '-'); // U+2212 -> '-'
  return int.tryParse(s) ?? 0;
}

String _str(dynamic v) => (v ?? '').toString();

/// Berekent voor een divisie de doelpunten vóór/tegen per club uit 'matches'
/// en schrijft die naar 'standen' (incl. doelsaldo = DV - DT).
/// - divisie: 'Derde Divisie A' of 'Derde Divisie B'
/// - dryRun: eerst true draaien om alleen te loggen; daarna false om te schrijven.
Future<void> backfillDvDt({required String divisie, bool dryRun = true}) async {
  final db = FirebaseFirestore.instance;

  // 1) Stan­den-docs ophalen (club -> docRef)
  final standSnap = await db.collection('standen')
      .where('competitie', isEqualTo: divisie).get();
  final Map<String, DocumentReference> standRefs = {
    for (final d in standSnap.docs) _str(d['club']): d.reference
  };

  // 2) Wedstrijden van deze divisie ophalen (veldnaam tolerant)
  final divCode = divisie.endsWith('A') ? 'A' : 'B';
  final q1 = db.collection('matches').where('competitie', isEqualTo: divisie).get();
  final q2 = db.collection('matches').where('division', isEqualTo: divCode).get();
  final res = await Future.wait([q1, q2]);

  // Unieke matches samenvoegen op id
  final Map<String, Map<String, dynamic>> matches = {};
  for (final s in res) {
    for (final doc in s.docs) {
      matches[doc.id] = (doc.data() as Map<String, dynamic>);
    }
  }

  // 3) Tellen per club
  final Map<String, Map<String, int>> agg = {};
  Map<String, int> stats(String team) =>
      agg.putIfAbsent(team, () => {'dv': 0, 'dt': 0});

  for (final m in matches.values) {
    final homeTeam = _str(m['homeTeam'] ?? m['thuis'] ?? m['home'] ?? m['teamHome']);
    final awayTeam = _str(m['awayTeam'] ?? m['uit']   ?? m['away'] ?? m['teamAway']);

    // Scores (tolerant op veldnamen)
    final hg = _toInt(m['homeGoals'] ?? m['hg'] ?? m['thuisGoals'] ?? m['scoreHome']);
    final ag = _toInt(m['awayGoals'] ?? m['ag'] ?? m['uitGoals']   ?? m['scoreAway']);

    // Alleen gespeelde wedstrijden met geldige teams
    final played = (m['played'] == true) || (hg >= 0 && ag >= 0);
    if (homeTeam.isEmpty || awayTeam.isEmpty || !played) continue;

    stats(homeTeam)['dv'] = stats(homeTeam)['dv']! + hg;
    stats(homeTeam)['dt'] = stats(homeTeam)['dt']! + ag;
    stats(awayTeam)['dv'] = stats(awayTeam)['dv']! + ag;
    stats(awayTeam)['dt'] = stats(awayTeam)['dt']! + hg;
  }

  // 4) Batch update naar 'standen' (alleen clubs die we kennen)
  final batch = db.batch();
  int updates = 0, missing = 0;

  agg.forEach((team, s) {
    final ref = standRefs[team];
    final dv = s['dv'] ?? 0;
    final dt = s['dt'] ?? 0;
    final ds = dv - dt;

    if (ref == null) {
      missing++;
      // ignore: avoid_print
      print('[BACKFILL] Geen stand-doc voor club "$team" (DV=$dv, DT=$dt)');
      return;
    }

    // Log wat er zou gebeuren
    // ignore: avoid_print
    print('[BACKFILL] ${ref.path}  ->  DV=$dv  DT=$dt  DS=$ds');

    if (!dryRun) {
      batch.update(ref, {
        'doelpuntenVoor': dv,
        'doelpuntenTegen': dt,
        'doelsaldo': ds,
      });
    }
    updates++;
  });

  if (!dryRun && updates > 0) {
    await batch.commit();
  }
  // ignore: avoid_print
  print('[BACKFILL] divisie="$divisie" updates=$updates missing=$missing dryRun=$dryRun');
}
