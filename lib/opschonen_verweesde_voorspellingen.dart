import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

final _firestore = FirebaseFirestore.instance;
final _log = Logger('VerwijderVerweesdeVoorspellingen');

/// Verwijder alle voorspellingen waarvan de gebruiker niet meer bestaat.
Future<void> verwijderVerweesdeVoorspellingen() async {
  final voorspellingen = await _firestore.collection('voorspellingen').get();
  int verwijderd = 0;

  for (final doc in voorspellingen.docs) {
    final data = doc.data();
    final gebruikerId = data['gebruikerId'];

    if (gebruikerId == null || gebruikerId.toString().isEmpty) {
      await doc.reference.delete();
      verwijderd++;
      continue;
    }

    final gebruikerSnapshot = await _firestore.collection('users').doc(gebruikerId).get();
    if (!gebruikerSnapshot.exists) {
      await doc.reference.delete();
      verwijderd++;
    }
  }

  _log.info('✅ Aantal verwijderde verweesde voorspellingen: $verwijderd');
}
