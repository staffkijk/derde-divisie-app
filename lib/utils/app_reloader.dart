// lib/utils/app_reloader.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_reloader_impl_stub.dart'
  if (dart.library.html) 'app_reloader_impl_web.dart';

final AppReloaderImpl _impl = getAppReloader();

class AppReloader {
  AppReloader._();
  static final AppReloader instance = AppReloader._();

  static const _kPrefKey = 'dd_lastReloadAt_ms';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  int? _lastMs; // persistent

  Future<void> start() async {
    // 1) lees laatst verwerkte trigger uit persistent storage
    final prefs = await SharedPreferences.getInstance();
    _lastMs = prefs.getInt(_kPrefKey);

    // 2) luister naar Firestore
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('system')
        .doc('ui')
        .snapshots()
        .listen((snap) async {
      final ts = (snap.data()?['reloadAt'] as Timestamp?)?.toDate();
      if (ts == null) return;

      final ms = ts.millisecondsSinceEpoch;

      // Als we deze trigger al hebben verwerkt, niets doen
      if (_lastMs != null && ms <= _lastMs!) return;

      // Vooraf opslaan (zodat een reload niet opnieuw triggert)
      _lastMs = ms;
      await prefs.setInt(_kPrefKey, ms);

      // Eventueel throttle (veiligheid): max 1x per 5 sec
      // if (_lastMs != null && DateTime.now().millisecondsSinceEpoch - _lastMs! < 5000) return;

      // Harde reload (web) / noop (non-web)
      unawaited(_impl.hardReload());
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Moderator-actie: stuur een reload-signaal naar alle clients
  static Future<void> pushReloadToAllClients() {
    return FirebaseFirestore.instance
        .collection('system')
        .doc('ui')
        .set({'reloadAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
