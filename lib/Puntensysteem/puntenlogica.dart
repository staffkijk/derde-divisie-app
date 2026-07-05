import 'package:cloud_firestore/cloud_firestore.dart';

/// Puntenberekening op basis van voorspelling en werkelijke uitslag
int berekenPunten({
  required int voorspeldThuis,
  required int voorspeldUit,
  required int echtThuis,
  required int echtUit,
}) {
  // 1) Exacte uitslag
  if (voorspeldThuis == echtThuis && voorspeldUit == echtUit) {
    return 10;
  }

  final bool echtGelijk = echtThuis == echtUit;
  final bool voorspeldGelijk = voorspeldThuis == voorspeldUit;

  // 2) Gelijkspel goed (maar niet exact) = 7 (geen extra’s stapelen)
  if (echtGelijk && voorspeldGelijk) {
    return 7;
  }

  // 3) Overige gevallen: optellen volgens regels
  int punten = 0;

  // Winnaar goed (alleen bij winst/verlies)
  final int diffEcht = echtThuis - echtUit;
  final int diffVoorspeld = voorspeldThuis - voorspeldUit;
  final bool winnaarGoed =
      !echtGelijk && !voorspeldGelijk && (diffEcht.sign == diffVoorspeld.sign);

  if (winnaarGoed) punten += 5;

  // +2 per juist doelaantal
  if (voorspeldThuis == echtThuis) punten += 2;
  if (voorspeldUit == echtUit) punten += 2;

  // Max 10
  if (punten > 10) punten = 10;

  return punten;
}

/// Trek eerdere uitslag af van de stand
Future<void> corrigeerStand(String club, int oudeVoor, int oudeTegen) async {
  final doc = FirebaseFirestore.instance.collection('standen').doc(club);
  final snapshot = await doc.get();

  if (!snapshot.exists) return;

  final data = snapshot.data()!;
  int gespeeld = (data['gespeeld'] ?? 0) - 1;
  int gewonnen = data['gewonnen'] ?? 0;
  int gelijk = data['gelijk'] ?? 0;
  int verloren = data['verloren'] ?? 0;
  int doelpuntenVoor = (data['doelpuntenVoor'] ?? 0) - oudeVoor;
  int doelpuntenTegen = (data['doelpuntenTegen'] ?? 0) - oudeTegen;
  int punten = data['punten'] ?? 0;

  if (oudeVoor > oudeTegen) {
    gewonnen -= 1;
    punten -= 3;
  } else if (oudeVoor == oudeTegen) {
    gelijk -= 1;
    punten -= 1;
  } else {
    verloren -= 1;
  }

  await doc.update({
    'gespeeld': gespeeld,
    'gewonnen': gewonnen,
    'gelijk': gelijk,
    'verloren': verloren,
    'doelpuntenVoor': doelpuntenVoor,
    'doelpuntenTegen': doelpuntenTegen,
    'punten': punten,
  });
}

/// Verwerk nieuwe uitslag naar de stand
Future<void> verwerkStand(String club, int voor, int tegen) async {
  final doc = FirebaseFirestore.instance.collection('standen').doc(club);
  final snapshot = await doc.get();

  if (!snapshot.exists) return;

  final data = snapshot.data()!;
  int gespeeld = (data['gespeeld'] ?? 0) + 1;
  int gewonnen = data['gewonnen'] ?? 0;
  int gelijk = data['gelijk'] ?? 0;
  int verloren = data['verloren'] ?? 0;
  int doelpuntenVoor = (data['doelpuntenVoor'] ?? 0) + voor;
  int doelpuntenTegen = (data['doelpuntenTegen'] ?? 0) + tegen;
  int punten = data['punten'] ?? 0;

  if (voor > tegen) {
    gewonnen += 1;
    punten += 3;
  } else if (voor == tegen) {
    gelijk += 1;
    punten += 1;
  } else {
    verloren += 1;
  }

  await doc.update({
    'gespeeld': gespeeld,
    'gewonnen': gewonnen,
    'gelijk': gelijk,
    'verloren': verloren,
    'doelpuntenVoor': doelpuntenVoor,
    'doelpuntenTegen': doelpuntenTegen,
    'punten': punten,
  });
}
