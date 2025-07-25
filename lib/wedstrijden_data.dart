import 'wedstrijd.dart';
import 'wedstrijden_dda.dart';
import 'wedstrijden_ddb.dart';

List<Wedstrijd> getWedstrijden(String divisie) {
  List<Wedstrijd> wedstrijden;

  switch (divisie) {
    case 'A':
      wedstrijden = wedstrijdenDerdeDivisieA;
      break;
    case 'B':
      wedstrijden = wedstrijdenDerdeDivisieB;
      break;
    case 'AB':
      wedstrijden = [...wedstrijdenDerdeDivisieA, ...wedstrijdenDerdeDivisieB];
      break;
    default:
      wedstrijden = [];
      break;
  }

  // Sorteer wedstrijden op datum
  wedstrijden.sort((a, b) => a.datum.compareTo(b.datum));
  return wedstrijden;
}
