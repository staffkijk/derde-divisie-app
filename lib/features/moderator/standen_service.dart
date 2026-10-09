import 'package:cloud_functions/cloud_functions.dart';
import 'package:derde_divisie/data/config/season_config.dart';
class StandenService {
  Future<void> herberekenStandVoorDivisie(String divisieCode) async {
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('rebuildDivisionStandings').call<void>({
          'division': SeasonConfig.normalizeDivisionCode(divisieCode),
        });
  }
  Future<void> herberekenStandenVoorCompetitie(String competitieNaam) =>
      herberekenStandVoorDivisie(competitieNaam);
}
