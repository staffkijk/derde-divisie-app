import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

Future<void> hernoemDivisieNaarCompetitieInStanden() async {
  final firestore = FirebaseFirestore.instance;
  final collection = firestore.collection('standen');
  final snapshot = await collection.get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final docRef = doc.reference;

    if (data.containsKey('divisie')) {
      final waarde = data['divisie'];
      await docRef.update({
        'competitie': waarde,
        'divisie': FieldValue.delete(),
      });
      developer.log('✅ Veld "divisie" hernoemd naar "competitie" voor ${doc.id}');
    } else {
      developer.log('ℹ️ Geen "divisie"-veld gevonden in ${doc.id}, overslagen');
    }
  }

  developer.log('🎉 Alle documenten in "standen" gecontroleerd en aangepast waar nodig.');
}
