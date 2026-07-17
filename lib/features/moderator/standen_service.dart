import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/standings_calculator.dart';

class StandenService {
  Future<void> herberekenStandVoorDivisie(String divisieCode) async {
    final division = SeasonConfig.normalizeDivisionCode(divisieCode);
    final matches = await SeasonPaths.currentSeasonMatches
        .where('division', isEqualTo: division)
        .get();
    final standings = StandingsCalculator.calculateDivisionStandings(
      division: division,
      matches: matches.docs.map((doc) => doc.data()),
    );

    final existing = await SeasonPaths.currentSeasonStandings
        .where('division', isEqualTo: division)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final entry in standings) {
      batch.set(
        SeasonPaths.currentSeasonStandings.doc(
          '${division}_${entry['teamId']}',
        ),
        {
          ...entry,
          'updatedAt': FieldValue.serverTimestamp(),
          // Tijdelijke leescompatibiliteit met bestaande stand-widgets.
          'club': entry['teamName'],
          'competitie': 'Derde Divisie $division',
          'gespeeld': entry['played'],
          'gewonnen': entry['wins'],
          'gelijk': entry['draws'],
          'verloren': entry['losses'],
          'doelpuntenVoor': entry['goalsFor'],
          'doelpuntenTegen': entry['goalsAgainst'],
          'doelsaldo': entry['goalDifference'],
          'punten': entry['points'],
        },
      );
    }
    await batch.commit();
  }

  Future<void> herberekenStandenVoorCompetitie(String competitieNaam) {
    return herberekenStandVoorDivisie(
      SeasonConfig.normalizeDivisionCode(competitieNaam),
    );
  }
}
