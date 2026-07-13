import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEventKeys {
  const ActivityEventKeys._();

  static const all = 'all';
  static const login = 'login';
  static const register = 'register';
  static const predictionSaved = 'prediction_saved';
  static const predictionCompleted = 'prediction_completed';
  static const predictionScreenOpened = 'prediction_screen_opened';
  static const favoriteTeamChanged = 'favorite_team_changed';
  static const screenView = 'screen_view';
  static const navigationClick = 'navigation_click';
  static const roundSelected = 'round_selected';
  static const divisionSelected = 'division_selected';
  static const notificationOpened = 'notification_opened';
  static const socialCardGenerated = 'social_card_generated';
}

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.eventType,
    required this.canonicalEventType,
    this.createdAt,
    this.userId = '',
    this.displayName = '',
    this.entityId = '',
    this.metadata = const {},
  });

  final String id;
  final String eventType;
  final String canonicalEventType;
  final DateTime? createdAt;
  final String userId;
  final String displayName;
  final String entityId;
  final Map<String, dynamic> metadata;

  factory ActivityLogEntry.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ActivityLogEntry.fromMap(doc.id, doc.data());
  }

  factory ActivityLogEntry.fromMap(String id, Map<String, dynamic> data) {
    final rawEvent = (data['eventType'] ?? data['type'] ?? '').toString();
    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};
    return ActivityLogEntry(
      id: id,
      eventType: rawEvent.trim().isEmpty ? 'onbekend' : rawEvent.trim(),
      canonicalEventType: ActivityEventUtils.canonicalKey(rawEvent),
      createdAt:
          ActivityEventUtils.dateTime(data['createdAt'] ?? data['timestamp']),
      userId: (data['uid'] ?? data['userId'] ?? '').toString(),
      displayName: (data['displayName'] ?? data['username'] ?? '').toString(),
      entityId: (data['entityId'] ?? '').toString(),
      metadata: metadata,
    );
  }
}

class ActivityEventUtils {
  const ActivityEventUtils._();

  static const canonicalLabels = {
    ActivityEventKeys.all: 'Alle events',
    ActivityEventKeys.login: 'Login',
    ActivityEventKeys.register: 'Registratie',
    ActivityEventKeys.predictionSaved: 'Voorspelling opgeslagen',
    ActivityEventKeys.predictionCompleted: 'Ronde compleet',
    ActivityEventKeys.predictionScreenOpened: 'Voorspelscherm geopend',
    ActivityEventKeys.favoriteTeamChanged: 'Favoriete club gewijzigd',
    ActivityEventKeys.screenView: 'Schermweergave',
    ActivityEventKeys.navigationClick: 'Navigatieklik',
    ActivityEventKeys.roundSelected: 'Speelronde gekozen',
    ActivityEventKeys.divisionSelected: 'Divisie gekozen',
    ActivityEventKeys.notificationOpened: 'Notificatie geopend',
    ActivityEventKeys.socialCardGenerated: 'Sociale kaart gemaakt',
  };

  static const filterKeys = [
    ActivityEventKeys.all,
    ActivityEventKeys.login,
    ActivityEventKeys.predictionSaved,
    ActivityEventKeys.favoriteTeamChanged,
    ActivityEventKeys.screenView,
    ActivityEventKeys.navigationClick,
    ActivityEventKeys.roundSelected,
    ActivityEventKeys.divisionSelected,
    ActivityEventKeys.notificationOpened,
    ActivityEventKeys.socialCardGenerated,
  ];

  static String canonicalKey(dynamic value) {
    final normalized = value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_') ??
        '';
    switch (normalized) {
      case '':
        return 'unknown';
      case 'prediction':
      case 'prediction_save':
      case 'prediction_saved':
      case 'voorspelling':
      case 'voorspelling_opgeslagen':
        return ActivityEventKeys.predictionSaved;
      case 'favorite_team':
      case 'favorite_team_changed':
      case 'favoriete_club':
        return ActivityEventKeys.favoriteTeamChanged;
      case 'screen':
      case 'screen_view':
      case 'page_view':
        return ActivityEventKeys.screenView;
      case 'navigation':
      case 'navigation_click':
      case 'nav_click':
        return ActivityEventKeys.navigationClick;
      case 'round':
      case 'round_selected':
      case 'speelronde':
        return ActivityEventKeys.roundSelected;
      case 'division':
      case 'division_selected':
      case 'divisie':
        return ActivityEventKeys.divisionSelected;
      case 'notification':
      case 'notification_opened':
        return ActivityEventKeys.notificationOpened;
      case 'social_card':
      case 'social_card_generated':
        return ActivityEventKeys.socialCardGenerated;
      default:
        return normalized;
    }
  }

  static String labelFor(String key) => canonicalLabels[key] ?? key;

  static List<ActivityLogEntry> applyFilter(
    List<ActivityLogEntry> events,
    String filterKey,
  ) {
    final canonical = canonicalKey(filterKey);
    if (canonical == ActivityEventKeys.all) return List.unmodifiable(events);
    return List.unmodifiable(
      events.where((event) => event.canonicalEventType == canonical),
    );
  }

  static DateTime? dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value > 1000000000000 ? value : value * 1000,
      );
    }
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }
}
