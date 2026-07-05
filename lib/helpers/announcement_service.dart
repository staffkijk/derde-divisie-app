import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Announcement {
  final String id;
  final String message;
  final bool active;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool requireLogin;
  final String type; // dialog | banner | snackbar
  final bool dismissible;
  final bool repeat; // <- nieuw: bij elk app-open tonen

  Announcement({
    required this.id,
    required this.message,
    required this.active,
    required this.startAt,
    required this.endAt,
    required this.requireLogin,
    required this.type,
    required this.dismissible,
    required this.repeat,
  });
}

class AnnouncementService {
  static const _kId = 'rc_announcement_id';
  static const _kActive = 'rc_announcement_active';
  static const _kMsg = 'rc_announcement_message';
  static const _kStart = 'rc_announcement_start'; // epoch ms
  static const _kEnd = 'rc_announcement_end'; // epoch ms
  static const _kRequireLogin = 'rc_announcement_require_login';
  static const _kType = 'rc_announcement_type'; // dialog|banner|snackbar
  static const _kDismissible = 'rc_announcement_dismissible';
  static const _kRepeat = 'rc_announcement_repeat'; // <- nieuw

  static const _prefsKeyLastSeen = 'last_announcement_id';

  static Future<Announcement?> _fetchConfig() async {
    final rc = FirebaseRemoteConfig.instance;

    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval:
          const Duration(minutes: 0), // tijdens testen evt. op 0 zetten
    ));

    await rc.setDefaults({
      _kId: '',
      _kActive: false,
      _kMsg: '',
      _kStart: 0,
      _kEnd: 0,
      _kRequireLogin: false,
      _kType: 'dialog',
      _kDismissible: true,
      _kRepeat: false, // default: NIET elke keer tonen
    });

    await rc.fetchAndActivate();

    final id = rc.getString(_kId).trim();
    final active = rc.getBool(_kActive);
    final msg = rc.getString(_kMsg).trim();
    final startMs = rc.getInt(_kStart);
    final endMs = rc.getInt(_kEnd);
    final requireLogin = rc.getBool(_kRequireLogin);
    final type = rc.getString(_kType).trim().toLowerCase();
    final dismissible = rc.getBool(_kDismissible);
    final repeat = rc.getBool(_kRepeat);

    if (!active || id.isEmpty || msg.isEmpty) return null;

    DateTime? startAt =
        startMs > 0 ? DateTime.fromMillisecondsSinceEpoch(startMs) : null;
    DateTime? endAt =
        endMs > 0 ? DateTime.fromMillisecondsSinceEpoch(endMs) : null;
    final now = DateTime.now();

    if (startAt != null && now.isBefore(startAt)) return null;
    if (endAt != null && now.isAfter(endAt)) return null;

    final normalizedType =
        (type == 'banner' || type == 'snackbar') ? type : 'dialog';

    return Announcement(
      id: id,
      message: msg,
      active: active,
      startAt: startAt,
      endAt: endAt,
      requireLogin: requireLogin,
      type: normalizedType,
      dismissible: dismissible,
      repeat: repeat,
    );
  }

  static Future<bool> _hasSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final key = uid != null ? '$_prefsKeyLastSeen-$uid' : _prefsKeyLastSeen;
    return prefs.getString(key) == id;
  }

  static Future<void> _markSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final key = uid != null ? '$_prefsKeyLastSeen-$uid' : _prefsKeyLastSeen;
    await prefs.setString(key, id);
  }

  /// Toon automatisch (bij app-open of direct na login).
  /// - Houdt rekening met 'repeat' en 'requireLogin'.
  static Future<void> maybeShow(BuildContext context,
      {required bool isLoggedIn}) async {
    final ann = await _fetchConfig();
    if (ann == null) return;
    if (ann.requireLogin && !isLoggedIn) return;

    if (!ann.repeat && await _hasSeen(ann.id)) return;

    await _present(context, ann);
    if (!ann.repeat) await _markSeen(ann.id);
  }

  /// Handmatige "opnieuw tonen" knop.
  /// - Negeert de "gezien"-vlag, maar respecteert active/timing en requireLogin.
  static Future<void> showAgain(BuildContext context,
      {required bool isLoggedIn}) async {
    final ann = await _fetchConfig();
    if (ann == null) {
      _toast(context, 'Er is momenteel geen actieve melding.');
      return;
    }
    if (ann.requireLogin && !isLoggedIn) {
      _toast(context, 'Melding is alleen zichtbaar na inloggen.');
      return;
    }
    await _present(context, ann);
  }

  // --- Presenters -----------------------------------------------------------

  static Future<void> _present(BuildContext context, Announcement ann) async {
    switch (ann.type) {
      case 'banner':
        _showBanner(context, ann);
        break;
      case 'snackbar':
        _showSnack(context, ann);
        break;
      case 'dialog':
      default:
        await _showDialog(context, ann);
        break;
    }
  }

  static Future<void> _showDialog(
      BuildContext context, Announcement ann) async {
    await showDialog(
      context: context,
      barrierDismissible: ann.dismissible,
      builder: (ctx) {
        // Optioneel: back-knop blokkeren als niet dismissible
        return PopScope(
          canPop: ann.dismissible,
          child: AlertDialog(
            title: const Text('Melding'),
            content: Text(ann.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showBanner(BuildContext context, Announcement ann) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(ann.message),
        actions: [
          TextButton(
            onPressed: () => messenger.clearMaterialBanners(),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
    // Auto-hide na 6s
    Future.delayed(const Duration(seconds: 6), () {
      if (context.mounted) ScaffoldMessenger.of(context).clearMaterialBanners();
    });
  }

  static void _showSnack(BuildContext context, Announcement ann) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
          content: Text(ann.message), duration: const Duration(seconds: 4)),
    );
  }

  static void _toast(BuildContext context, String msg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
}
