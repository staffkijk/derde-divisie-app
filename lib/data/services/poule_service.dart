import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';
import '../models/poule_model.dart';

int berekenPuntenVoorVoorspelling({
  required int voorspeldHome,
  required int voorspeldAway,
  required int echtHome,
  required int echtAway,
}) {
  if (voorspeldHome == echtHome && voorspeldAway == echtAway) return 10;
  if (echtHome == echtAway && voorspeldHome == voorspeldAway) return 7;

  int punten = 0;
  final winnaarEcht = echtHome.compareTo(echtAway);
  final winnaarVoorspeld = voorspeldHome.compareTo(voorspeldAway);

  if (winnaarEcht == winnaarVoorspeld && winnaarEcht != 0) {
    punten = 5;
    if (voorspeldHome == echtHome) punten += 2;
    if (voorspeldAway == echtAway) punten += 2;
  } else {
    if (voorspeldHome == echtHome) punten += 2;
    if (voorspeldAway == echtAway) punten += 2;
  }

  return punten;
}

class PouleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkUniqueName(String name) async {
    final snapshot = await _firestore
        .collection('poules')
        .where('name', isEqualTo: name)
        .get();
    return snapshot.docs.isEmpty;
  }

  Future<void> createPoule(Poule poule) async {
    final pouleRef = _firestore.collection('poules').doc(poule.id);
    await pouleRef.set(poule.toMap());

    await pouleRef.collection('deelnemers').doc(poule.ownerId).set({
      'rol': 'eigenaar',
      'joinedAt': Timestamp.now(),
      'punten': 0,
    });
  }

  Future<void> verwerkPuntenVoorPouleVoorspellingen({
    required String pouleId, required String matchId,
    required int echteHome, required int echteAway,
  }) => ResultProcessingService.requestProcessing(matchId);
}
