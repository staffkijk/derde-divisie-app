import '../models/wedstrijd.dart';
import 'wedstrijden_dda.dart';
import 'wedstrijden_ddb.dart';

List<Wedstrijd> getWedstrijden(String divisie) {
  List<Wedstrijd> wedstrijden;

  switch (divisie.toLowerCase()) {
    case 'a':
    case 'dda':
      wedstrijden = wedstrijdenDerdeDivisieA;
      break;
    case 'b':
    case 'ddb':
      wedstrijden = wedstrijdenDerdeDivisieB;
      break;
    default:
      wedstrijden = [];
      break;
  }

  wedstrijden.sort((a, b) => a.datum.compareTo(b.datum));
  return wedstrijden;
}
