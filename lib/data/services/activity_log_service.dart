import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/services/activity_event_utils.dart';

abstract class ActivityEventType {
  static const login = ActivityEventKeys.login;
  static const register = ActivityEventKeys.register;
  static const predictionSaved = ActivityEventKeys.predictionSaved;
  static const predictionCompleted = ActivityEventKeys.predictionCompleted;
  static const predictionScreenOpened =
      ActivityEventKeys.predictionScreenOpened;
  static const finalStandingPredictionSaved = 'final_standing_prediction_saved';
  static const favoriteTeamChanged = ActivityEventKeys.favoriteTeamChanged;
  static const screenView = ActivityEventKeys.screenView;
  static const navigationClick = ActivityEventKeys.navigationClick;
  static const roundSelected = ActivityEventKeys.roundSelected;
  static const divisionSelected = ActivityEventKeys.divisionSelected;
  static const notificationOpened = ActivityEventKeys.notificationOpened;
  static const socialCardGenerated = ActivityEventKeys.socialCardGenerated;
  static const pouleCreated = 'poule_created';
  static const pouleJoined = 'poule_joined';
  static const pouleSettingsUpdated = 'poule_settings_updated';
  static const resultSavedByModerator = 'result_saved_by_moderator';
  static const resultProcessed = 'result_processed';
  static const exportCreated = 'export_created';
  static const updateRead = 'update_read';
}

class ActivityLogService {
  ActivityLogService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> log({
    required String eventType,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('activityLogs').add({
        'uid': user.uid,
        if ((user.displayName ?? '').trim().isNotEmpty)
          'displayName': user.displayName!.trim(),
        'eventType': ActivityEventUtils.canonicalKey(eventType),
        'createdAt': FieldValue.serverTimestamp(),
        'seasonId': SeasonConfig.activeSeasonId,
        'platform': kIsWeb ? 'web' : 'app',
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        if (metadata.isNotEmpty) 'metadata': _safeMetadata(metadata),
      });
    } catch (error) {
      // Activiteitsregistratie mag nooit een login of kernactie blokkeren.
      debugPrint('Activity log overgeslagen: $error');
    }
  }

  Map<String, dynamic> _safeMetadata(Map<String, dynamic> source) {
    const blockedKeys = {
      'password',
      'token',
      'email',
      'userAgent',
      'authorization',
    };
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (blockedKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value == null || value is String || value is num || value is bool) {
        result[entry.key] = value;
      }
    }
    return result;
  }
}
