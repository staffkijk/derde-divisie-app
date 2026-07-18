import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:derde_divisie/data/models/notification_preferences.dart';
import 'package:derde_divisie/data/models/notification_collection_utils.dart';

class NotificationPreferenceSaveResult {
  const NotificationPreferenceSaveResult({
    required this.preferencesSaved,
    required this.oldRemindersRemoved,
  });

  final bool preferencesSaved;
  final bool oldRemindersRemoved;
}

abstract class NotificationPreferencesStore {
  Stream<NotificationPreferences> watch();
  Future<NotificationPreferences> load();
  Future<NotificationPreferenceSaveResult> save(
    NotificationPreferences preferences, {
    required bool wasMissingPredictionRemindersEnabled,
  });
}

class NotificationPreferencesService implements NotificationPreferencesStore {
  NotificationPreferencesService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  @override
  Stream<NotificationPreferences> watch() {
    final uid = _uid;
    if (uid == null) return Stream.value(const NotificationPreferences());
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => NotificationPreferences.fromMap(
            doc.data()?['notificationPreferences'] as Map<String, dynamic>?,
          ),
        );
  }

  @override
  Future<NotificationPreferences> load() async {
    final uid = _uid;
    if (uid == null) return const NotificationPreferences();
    final doc = await _firestore.collection('users').doc(uid).get();
    return NotificationPreferences.fromMap(
      doc.data()?['notificationPreferences'] as Map<String, dynamic>?,
    );
  }

  @override
  Future<NotificationPreferenceSaveResult> save(
    NotificationPreferences preferences, {
    required bool wasMissingPredictionRemindersEnabled,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const NotificationPreferenceSaveResult(
        preferencesSaved: false,
        oldRemindersRemoved: false,
      );
    }

    final userRef = _firestore.collection('users').doc(uid);
    await userRef.set({
      'notificationPreferences': preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    var removed = true;
    if (wasMissingPredictionRemindersEnabled &&
        !preferences.missingPredictionReminders) {
      try {
        final reminders = await userRef
            .collection('notifications')
            .where('type', isEqualTo: 'missing_predictions')
            .get();
        final ids = missingPredictionNotificationIds(
          reminders.docs.map(
            (doc) => UserNotificationRecord(id: doc.id, data: doc.data()),
          ),
        );
        final batch = _firestore.batch();
        for (final id in ids) {
          batch.delete(userRef.collection('notifications').doc(id));
        }
        if (ids.isNotEmpty) await batch.commit();
      } catch (error, stack) {
        removed = false;
        debugPrint(
            'Oude voorspellingsherinneringen verwijderen mislukt: $error');
        debugPrintStack(stackTrace: stack);
      }
    }

    return NotificationPreferenceSaveResult(
      preferencesSaved: true,
      oldRemindersRemoved: removed,
    );
  }
}
