import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AnalyticsConsentStatus {
  unknown,
  granted,
  denied,
}

abstract class AnalyticsClient {
  Future<void> setCollectionEnabled(bool enabled);

  Future<void> logEvent(String name, Map<String, Object> parameters);

  Future<void> logScreenView({
    required String screenName,
    required Map<String, Object> parameters,
  });
}

class FirebaseAnalyticsClient implements AnalyticsClient {
  FirebaseAnalyticsClient({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> setCollectionEnabled(bool enabled) {
    return _analytics.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    required Map<String, Object> parameters,
  }) {
    return _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
      parameters: parameters,
    );
  }
}

abstract class AnalyticsConsentStore {
  Future<AnalyticsConsentStatus> read();

  Future<void> write(AnalyticsConsentStatus status);
}

class SharedPreferencesAnalyticsConsentStore implements AnalyticsConsentStore {
  static const key = 'ga4_analytics_consent';

  @override
  Future<AnalyticsConsentStatus> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    switch (value) {
      case 'granted':
        return AnalyticsConsentStatus.granted;
      case 'denied':
        return AnalyticsConsentStatus.denied;
      default:
        return AnalyticsConsentStatus.unknown;
    }
  }

  @override
  Future<void> write(AnalyticsConsentStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, status.name);
  }
}

class AnalyticsService {
  AnalyticsService({
    AnalyticsClient? client,
    AnalyticsConsentStore? consentStore,
    bool? isWeb,
  })  : _client = client ?? FirebaseAnalyticsClient(),
        _consentStore =
            consentStore ?? SharedPreferencesAnalyticsConsentStore(),
        _isWeb = isWeb ?? kIsWeb;

  static final AnalyticsService instance = AnalyticsService();

  final AnalyticsClient _client;
  final AnalyticsConsentStore _consentStore;
  final bool _isWeb;

  bool _initialized = false;
  bool _collectionEnabled = false;
  AnalyticsConsentStatus _consentStatus = AnalyticsConsentStatus.unknown;
  String? _lastScreenName;

  AnalyticsConsentStatus get consentStatus => _consentStatus;

  bool get collectionEnabled => _collectionEnabled;

  bool get shouldAskConsent =>
      _isWeb && _consentStatus == AnalyticsConsentStatus.unknown;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _consentStatus = await _consentStore.read();
      final enabled = _isWeb
          ? _consentStatus == AnalyticsConsentStatus.granted
          : _consentStatus != AnalyticsConsentStatus.denied;
      await _setCollectionEnabled(enabled);
    } catch (error) {
      debugPrint('Analytics initialisatie overgeslagen: $error');
      _collectionEnabled = false;
    }
  }

  Future<void> setConsent(bool granted) async {
    final status = granted
        ? AnalyticsConsentStatus.granted
        : AnalyticsConsentStatus.denied;
    try {
      await _consentStore.write(status);
      _consentStatus = status;
      await _setCollectionEnabled(granted);
      if (!granted) resetScreenTracking();
    } catch (error) {
      debugPrint('Analytics toestemming niet opgeslagen: $error');
    }
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await _setCollectionEnabled(enabled);
      if (!enabled) resetScreenTracking();
    } catch (error) {
      debugPrint('Analytics collection toggle overgeslagen: $error');
    }
  }

  void resetScreenTracking() {
    _lastScreenName = null;
  }

  Future<void> trackScreenView(
    String screenName, {
    bool loggedIn = false,
    Map<String, Object?> parameters = const {},
  }) async {
    await initialize();
    if (!_collectionEnabled || _lastScreenName == screenName) return;
    _lastScreenName = screenName;

    await _safeCall(() {
      return _client.logScreenView(
        screenName: screenName,
        parameters: _safeParameters({
          ...parameters,
          'logged_in': loggedIn,
        }),
      );
    });
  }

  Future<void> trackPredictionSaved({
    required String division,
    required int round,
    required String matchId,
    String? source,
  }) {
    return trackEvent(
      'prediction_saved',
      parameters: {
        'division': division,
        'round': round,
        'match_id': matchId,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> trackPouleCreated({
    required String pouleType,
    required bool isPublic,
    required String predictionScope,
    String? division,
  }) {
    return trackEvent(
      'poule_created',
      parameters: {
        'source': 'poules',
        'poule_type': pouleType,
        'public': isPublic,
        'prediction_scope': predictionScope,
        if (division != null && division.isNotEmpty) 'division': division,
      },
    );
  }

  Future<void> trackPouleJoined({
    required String source,
    required bool public,
  }) {
    return trackEvent(
      'poule_joined',
      parameters: {
        'source': source,
        'public': public,
      },
    );
  }

  Future<void> trackFavoriteClubSelected({
    required String team,
    String? division,
    String? source,
  }) {
    return trackEvent(
      'favorite_club_selected',
      parameters: {
        'team': team,
        if (division != null && division.isNotEmpty) 'division': division,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> trackMatchOpened({
    required String matchId,
    String? division,
    int? round,
    String? source,
  }) {
    return trackEvent(
      'match_opened',
      parameters: {
        'match_id': matchId,
        if (division != null) 'division': division,
        if (round != null) 'round': round,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> trackStandingsViewed({
    required String division,
    String? source,
  }) {
    return trackEvent(
      'standings_viewed',
      parameters: {
        'division': division,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> trackHistoryViewed({
    required String division,
    required String season,
    String? source,
  }) {
    return trackEvent(
      'history_viewed',
      parameters: {
        'division': division,
        'season': season,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> trackShareClicked({
    required String source,
  }) {
    return trackEvent('share_clicked', parameters: {'source': source});
  }

  Future<void> trackIntroVideoStarted() {
    return trackEvent(
      'intro_video_started',
      parameters: {'source': 'intro_video'},
    );
  }

  Future<void> trackIntroVideoCompleted() {
    return trackEvent(
      'intro_video_completed',
      parameters: {'source': 'intro_video'},
    );
  }

  Future<void> trackEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    await initialize();
    if (!_collectionEnabled) return;

    await _safeCall(() {
      return _client.logEvent(name, _safeParameters(parameters));
    });
  }

  Future<void> _setCollectionEnabled(bool enabled) async {
    await _client.setCollectionEnabled(enabled);
    _collectionEnabled = enabled;
  }

  Future<void> _safeCall(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      debugPrint('Analytics event overgeslagen: $error');
    }
  }

  Map<String, Object> _safeParameters(Map<String, Object?> source) {
    const blockedKeys = {
      'email',
      'name',
      'display_name',
      'username',
      'user_name',
      'description',
      'password',
      'token',
      'free_text',
    };
    final result = <String, Object>{};

    for (final entry in source.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || blockedKeys.contains(key.toLowerCase())) continue;

      final value = entry.value;
      if (value == null) continue;

      if (value is bool || value is num) {
        result[key] = value;
      } else if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty && normalized.length <= 100) {
          result[key] = normalized;
        }
      }
    }

    return result;
  }
}
