import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class PredictionReminderStatus {
  const PredictionReminderStatus({
    required this.division,
    required this.round,
    required this.totalRequired,
    required this.predicted,
    required this.missingMatchIds,
    this.deadline,
  });

  final String division;
  final int round;
  final int totalRequired;
  final int predicted;
  final List<String> missingMatchIds;
  final DateTime? deadline;

  int get missing => missingMatchIds.length;
  bool get complete => missing == 0 && totalRequired > 0;
  bool get expired => deadline != null && DateTime.now().isAfter(deadline!);
}

class PredictionReminderService {
  PredictionReminderService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> notificationsFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> unreadNotificationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return notificationsFor(uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      loadNotifications() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];
    final snap = await notificationsFor(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs;
  }

  Future<void> markRead(String notificationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await notificationsFor(uid).doc(notificationId).set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<PredictionReminderStatus?> evaluate({
    required String division,
    int? round,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final matchesSnap = await SeasonPaths.currentSeasonMatches.get();
    final matches = matchesSnap.docs
        .where((doc) => doc.id != '_meta')
        .map((doc) => _ReminderMatch.fromDoc(doc))
        .where((match) =>
            match.division == SeasonConfig.normalizeDivisionCode(division))
        .where((match) => match.isRequiredForPrediction)
        .toList()
      ..sort(_ReminderMatch.compare);

    if (matches.isEmpty) return null;
    final selectedRound =
        round ?? _firstOpenRound(matches) ?? matches.first.round;
    final roundMatches =
        matches.where((match) => match.round == selectedRound).toList();
    if (roundMatches.isEmpty) return null;

    final predictionsSnap = await _firestore
        .collection('voorspellingen')
        .where('gebruikerId', isEqualTo: uid)
        .get();
    final predictedMatchIds = predictionsSnap.docs
        .where((doc) =>
            doc.data()['scoreThuis'] != null && doc.data()['scoreUit'] != null)
        .map((doc) => doc.data()['wedstrijdId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final missing = roundMatches
        .where((match) => !predictedMatchIds.contains(match.id))
        .map((match) => match.id)
        .toList();
    final deadline = _deadlineFor(roundMatches);

    return PredictionReminderStatus(
      division: SeasonConfig.normalizeDivisionCode(division),
      round: selectedRound,
      totalRequired: roundMatches.length,
      predicted: roundMatches.length - missing.length,
      missingMatchIds: missing,
      deadline: deadline,
    );
  }

  Future<PredictionReminderStatus?> syncMissingPredictionNotification({
    required String division,
    int? round,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final status = await evaluate(division: division, round: round);
    if (status == null) return null;
    final id =
        'missing_predictions_${SeasonConfig.activeSeasonId}_${status.division}_${status.round}';
    final ref = notificationsFor(uid).doc(id);
    if (status.complete || status.expired) {
      await ref.set({
        'read': true,
        'resolved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return status;
    }
    await ref.set({
      'type': 'missing_predictions',
      'title': 'Voorspellingen ontbreken',
      'body':
          'Je hebt nog ${status.missing} wedstrijden niet voorspeld voor speelronde ${status.round}.',
      'seasonId': SeasonConfig.activeSeasonId,
      'division': status.division,
      'round': status.round,
      'missing': status.missing,
      'missingMatchIds': status.missingMatchIds,
      'read': false,
      'resolved': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return status;
  }

  static int? _firstOpenRound(List<_ReminderMatch> matches) {
    final now = DateTime.now();
    for (final match in matches) {
      final deadline = match.deadline;
      if (deadline == null || deadline.isAfter(now)) return match.round;
    }
    return null;
  }

  static DateTime? _deadlineFor(List<_ReminderMatch> matches) {
    final dates = matches.map((match) => match.deadline).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }
}

class _ReminderMatch {
  const _ReminderMatch({
    required this.id,
    required this.division,
    required this.round,
    required this.status,
    required this.data,
    this.dateTime,
  });

  final String id;
  final String division;
  final int round;
  final MatchStatus status;
  final Map<String, dynamic> data;
  final DateTime? dateTime;

  bool get isRequiredForPrediction {
    return status == MatchStatus.scheduled ||
        status == MatchStatus.postponed ||
        status == MatchStatus.finished;
  }

  DateTime? get deadline {
    final value = dateTime;
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day, 12);
  }

  factory _ReminderMatch.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _ReminderMatch(
      id: doc.id,
      division: SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['competitie'] ?? '').toString(),
      ),
      round: _int(data['round'] ?? data['speelronde']),
      status: parseMatchStatus(data['status']),
      data: data,
      dateTime: MatchDateTimeFormatter.dateTimeFromData(data),
    );
  }

  static int compare(_ReminderMatch a, _ReminderMatch b) {
    return MatchDateTimeFormatter.compare(a.data, b.data);
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
