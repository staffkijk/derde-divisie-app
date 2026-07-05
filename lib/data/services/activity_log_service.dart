import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:derde_divisie/data/config/season_config.dart';

abstract class ActivityEventType {
  static const login = 'login';
  static const register = 'register';
  static const predictionSaved = 'prediction_saved';
  static const finalStandingPredictionSaved = 'final_standing_prediction_saved';
  static const favoriteTeamChanged = 'favorite_team_changed';
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
        'eventType': eventType,
        'createdAt': FieldValue.serverTimestamp(),
        'seasonId': SeasonConfig.activeSeasonId,
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
