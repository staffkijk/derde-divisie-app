import 'package:derde_divisie/features/moderator/standen_service.dart';
class PeriodestandService {
  Future<void> herberekenAllePeriodesVoorDivisie(String divisieCode) =>
      StandenService().herberekenStandVoorDivisie(divisieCode);
}
