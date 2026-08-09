import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/standings_calculator.dart';

class PeriodestandService {
  Future<void> herberekenAllePeriodesVoorDivisie(String divisieCode) async {
    final division = SeasonConfig.normalizeDivisionCode(divisieCode);
    final snapshot = await SeasonPaths.currentSeasonMatches
        .where('division', isEqualTo: division)
        .get();

    for (var period = 1; period <= 3; period++) {
      await _recalculate(division, period, snapshot.docs);
    }
  }

  Future<void> _recalculate(
    String division,
    int period,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> matches,
  ) async {
    final sorted = StandingsCalculator.calculatePeriodStandings(
      division: division,
      period: period,
      matches: matches.map((doc) => doc.data()),
    );

    final prefix = '${division}_P${period}_';
    final existing = await SeasonPaths.currentSeasonPeriodStandings
        .where('division', isEqualTo: division)
        .where('period', isEqualTo: period)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var index = 0; index < sorted.length; index++) {
      final entry = sorted[index];
      final data = entry;
      batch.set(
        SeasonPaths.currentSeasonPeriodStandings.doc(
          '$prefix${data['teamId']}',
        ),
        {
          ...data,
          'position': index + 1,
          'updatedAt': FieldValue.serverTimestamp(),
          // Compatibiliteit voor de bestaande periodestand-widget.
          'club': data['teamName'],
          'positie': index + 1,
          'gespeeld': data['played'],
          'gewonnen': data['wins'],
          'gelijk': data['draws'],
          'verloren': data['losses'],
          'doelpuntenVoor': data['goalsFor'],
          'doelpuntenTegen': data['goalsAgainst'],
          'doelsaldo': data['goalDifference'],
          'punten': data['points'],
        },
      );
    }
    await batch.commit();
  }
}
