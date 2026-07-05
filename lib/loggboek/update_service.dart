import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_update.dart';

class UpdateService {
  static const _guestLastSeenKey = 'last_seen_update_millis';
  static final _guestSeenChanges = StreamController<Timestamp?>.broadcast();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _updatesCol => _db.collection('app_updates');

  DocumentReference? get _maybeUserDoc {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _db.collection('users').doc(user.uid);
  }

  Stream<List<AppUpdate>> streamUpdates({int limit = 50}) {
    return _updatesCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppUpdate.fromDoc(d)).toList());
  }

  /// Meest recente update
  Stream<AppUpdate?> streamLatestUpdate() {
    return _updatesCol
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return AppUpdate.fromDoc(snap.docs.first);
    });
  }

  /// Timestamp van "laatst gezien" voor ingelogde user (of null als niet ingelogd)
  Stream<Timestamp?> streamUserLastSeen() {
    final doc = _maybeUserDoc;
    if (doc == null) {
      return (() async* {
        yield await _guestLastSeen();
        yield* _guestSeenChanges.stream;
      })();
    }
    return doc.snapshots().map((s) {
      final data = s.data() as Map<String, dynamic>?;
      return data?['lastSeenUpdateAt'] as Timestamp?;
    });
  }

  /// Markeer updates als gezien t/m 'upTo'
  Future<void> markUpdatesSeen({required Timestamp upTo}) async {
    final doc = _maybeUserDoc;
    if (doc == null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        _guestLastSeenKey,
        upTo.millisecondsSinceEpoch,
      );
      _guestSeenChanges.add(upTo);
      return;
    }
    await doc.set({'lastSeenUpdateAt': upTo}, SetOptions(merge: true));
  }

  Future<Timestamp?> _guestLastSeen() async {
    final preferences = await SharedPreferences.getInstance();
    final millis = preferences.getInt(_guestLastSeenKey);
    return millis == null ? null : Timestamp.fromMillisecondsSinceEpoch(millis);
  }

  /// Nieuwe update toevoegen (admin)
  Future<void> addUpdate({
    required String version,
    required String title,
    required String body,
    String type = 'notice',
  }) async {
    await _updatesCol.add({
      'version': version,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
