import 'package:logging/logging.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/periodestand_service.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';
import 'package:derde_divisie/features/moderator/standen_service.dart';

final Logger _log = Logger('SpeelrondeResetService');

class SpeelrondeResetService {
  const SpeelrondeResetService();

  /// Reset alle wedstrijden van [speelronde] in divisie A of B via de
  /// canonieke resultaatverwerker. Daardoor worden algemene voorspellerspunten
  /// transactioneel teruggedraaid en kan de legacy puntenverwerker niet meer
  /// buiten de contribution-ledger om usertotalen aanpassen.
  Future<void> resetSpeelronde(String divisie, int speelronde) async {
    final normalizedDivision = SeasonConfig.normalizeDivisionCode(divisie);
    if (normalizedDivision != 'A' && normalizedDivision != 'B') {
      throw ArgumentError.value(divisie, 'divisie');
    }

    try {
      final snapshot = await SeasonPaths.currentSeasonMatches.get();
      final matches = snapshot.docs.where((doc) {
        final data = doc.data();
        final rawDivision =
            data['division'] ?? data['divisie'] ?? data['competitie'] ?? '';
        final matchDivision =
            SeasonConfig.normalizeDivisionCode(rawDivision.toString());
        final rawRound = data['round'] ??
            data['speelronde'] ??
            data['ronde'] ??
            data['wedstrijdRonde'];
        final matchRound = rawRound is num
            ? rawRound.toInt()
            : int.tryParse(rawRound?.toString() ?? '');
        return matchDivision == normalizedDivision && matchRound == speelronde;
      }).toList();

      if (matches.isEmpty) {
        _log.info(
          'Geen wedstrijden voor divisie $normalizedDivision, speelronde $speelronde',
        );
        return;
      }

      const processor = ResultProcessingService();
      for (final match in matches) {
        await processor.clearResultAndSetStatus(
          matchRef: match.reference,
          status: 'scheduled',
        );
        _log.info('Wedstrijd ${match.id} canoniek gereset');
      }

      await StandenService().herberekenStandVoorDivisie(normalizedDivision);
      await PeriodestandService()
          .herberekenAllePeriodesVoorDivisie(normalizedDivision);

      _log.info(
        'Speelronde $speelronde, divisie $normalizedDivision volledig gereset',
      );
    } catch (error, stackTrace) {
      _log.severe('Fout bij resetten speelronde: $error', error, stackTrace);
      rethrow;
    }
  }
}
