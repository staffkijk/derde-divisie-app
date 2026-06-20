import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> initVorigeScores() async {
  final firestore = FirebaseFirestore.instance;

  final matchesSnapshot = await firestore.collection('matches').get();

  for (final doc in matchesSnapshot.docs) {
    final data = doc.data();

    final huidigeThuis = data['uitslagThuis'] ?? 0;
    final huidigeUit = data['uitslagUit'] ?? 0;

    await doc.reference.update({
      'vorigeUitslagThuis': huidigeThuis,
      'vorigeUitslagUit': huidigeUit,
    });
  }

  debugPrint('Alle matches bijgewerkt met vorige uitslagen.');
}
