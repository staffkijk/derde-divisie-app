import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

// Gebruik dezelfde paden als in jouw project
import 'package:derde_divisie/Puntensysteem/puntenverwerker.dart';
import 'package:derde_divisie/features/moderator/standen_service.dart';
import 'package:derde_divisie/features/moderator/periodestand_service.dart';

final Logger _log = Logger('SpeelrondeResetService');

class SpeelrondeResetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reset alle wedstrijden van [speelronde] in divisie 'A' of 'B'.
  /// - Draait punten van alle betrokken voorspellingen terug (algemeen + alle poules)
  /// - Leegt de wedstrijdvelden
  /// - Corrigeert standen & periodestanden
  /// - Herberekent competitie- en periodestanden
  Future<void> resetSpeelronde(String divisie, int speelronde) async {
    try {
      final competitieNaam =
          divisie == 'A' ? 'Derde Divisie A' : 'Derde Divisie B';
      final periodeCode =
          divisie == 'A' ? 'dda' : 'ddb'; // <- vereist door PeriodestandService

      final wedstrijdenSnapshot = await _firestore
          .collection('matches')
          .where('competitie', isEqualTo: competitieNaam)
          .where('speelronde', isEqualTo: speelronde)
          .get();

      if (wedstrijdenSnapshot.docs.isEmpty) {
        _log.info(
            'ℹ️ Geen wedstrijden voor $competitieNaam – speelronde $speelronde');
        return;
      }

      // Per wedstrijd resetten via puntenverwerker.resetWedstrijd()
      for (final w in wedstrijdenSnapshot.docs) {
        await resetWedstrijd(w.id);
        _log.info('🔁 Wedstrijd ${w.id} gereset via resetWedstrijd()');
      }

      // Herbereken competitie-stand (service verwacht hier jouw eigen divisie-indicatie)
      await StandenService().herberekenStandVoorDivisie(divisie);

      // Herbereken periodestanden (service verwacht 'dda' of 'ddb')
      await PeriodestandService()
          .herberekenAllePeriodesVoorDivisie(periodeCode);

      _log.info('✅ Speelronde $speelronde ($competitieNaam) volledig gereset.');
    } catch (e, st) {
      _log.severe('❌ Fout bij resetten speelronde: $e');
      _log.severe(st.toString());
      rethrow;
    }
  }
}
