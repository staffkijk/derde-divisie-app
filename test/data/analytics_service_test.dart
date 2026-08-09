import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/services/analytics_service.dart';

void main() {
  test('web visitors start with analytics disabled until consent is granted',
      () async {
    final client = _FakeAnalyticsClient();
    final store = _FakeConsentStore();
    final service = AnalyticsService(
      client: client,
      consentStore: store,
      isWeb: true,
    );

    await service.initialize();
    await service.trackEvent('prediction_saved');

    expect(service.shouldAskConsent, isTrue);
    expect(client.enabledStates, [false]);
    expect(client.events, isEmpty);

    await service.setConsent(true);
    await service.trackEvent('prediction_saved');

    expect(store.status, AnalyticsConsentStatus.granted);
    expect(client.enabledStates, [false, true]);
    expect(client.events.single.name, 'prediction_saved');
  });

  test('denied consent disables later events and resets screen tracking',
      () async {
    final client = _FakeAnalyticsClient();
    final store = _FakeConsentStore(
      initial: AnalyticsConsentStatus.granted,
    );
    final service = AnalyticsService(
      client: client,
      consentStore: store,
      isWeb: true,
    );

    await service.trackScreenView('home');
    await service.trackScreenView('home');
    await service.setConsent(false);
    await service.trackScreenView('program');

    expect(client.screenViews.map((event) => event.name), ['home']);
    expect(client.enabledStates, [true, false]);
  });

  test('screen views are de-duplicated until the screen changes', () async {
    final client = _FakeAnalyticsClient();
    final service = AnalyticsService(
      client: client,
      consentStore: _FakeConsentStore(
        initial: AnalyticsConsentStatus.granted,
      ),
      isWeb: true,
    );

    await service.trackScreenView('home', loggedIn: false);
    await service.trackScreenView('home', loggedIn: false);
    await service.trackScreenView('division_a', loggedIn: true);

    expect(client.screenViews.map((event) => event.name), [
      'home',
      'division_a',
    ]);
    expect(client.screenViews.last.parameters['logged_in'], isTrue);
  });

  test('first accepted consent logs the current screen view once', () async {
    final client = _FakeAnalyticsClient();
    final service = AnalyticsService(
      client: client,
      consentStore: _FakeConsentStore(),
      isWeb: true,
    );

    await service.trackScreenView('home', loggedIn: false);
    await service.setConsent(true);
    service.resetScreenTracking();
    await service.trackScreenView('home', loggedIn: false);
    await service.trackScreenView('home', loggedIn: false);

    expect(client.enabledStates, [false, true]);
    expect(client.screenViews.map((event) => event.name), ['home']);
    expect(client.screenViews.single.parameters['logged_in'], isFalse);
  });

  test('analytics failures never escape to app code', () async {
    final service = AnalyticsService(
      client: _ThrowingAnalyticsClient(),
      consentStore: _FakeConsentStore(
        initial: AnalyticsConsentStatus.granted,
      ),
      isWeb: true,
    );

    await service.initialize();
    await service.trackEvent('share_clicked');
    await service.setConsent(false);
  });

  test('parameters exclude direct identifiers and free text keys', () async {
    final client = _FakeAnalyticsClient();
    final service = AnalyticsService(
      client: client,
      consentStore: _FakeConsentStore(
        initial: AnalyticsConsentStatus.granted,
      ),
      isWeb: true,
    );

    await service.trackEvent(
      'favorite_club_selected',
      parameters: {
        'team': 'acv',
        'email': 'fan@example.com',
        'username': 'supporter',
        'free_text': 'zelf ingevuld',
      },
    );

    expect(client.events.single.parameters, {'team': 'acv'});
  });
}

class _FakeAnalyticsClient implements AnalyticsClient {
  final enabledStates = <bool>[];
  final events = <_RecordedEvent>[];
  final screenViews = <_RecordedEvent>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    events.add(_RecordedEvent(name, parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    required Map<String, Object> parameters,
  }) async {
    screenViews.add(_RecordedEvent(screenName, parameters));
  }
}

class _ThrowingAnalyticsClient implements AnalyticsClient {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    throw StateError('boom');
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    throw StateError('boom');
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    required Map<String, Object> parameters,
  }) async {
    throw StateError('boom');
  }
}

class _FakeConsentStore implements AnalyticsConsentStore {
  _FakeConsentStore({
    AnalyticsConsentStatus initial = AnalyticsConsentStatus.unknown,
  }) : status = initial;

  AnalyticsConsentStatus status;

  @override
  Future<AnalyticsConsentStatus> read() async => status;

  @override
  Future<void> write(AnalyticsConsentStatus status) async {
    this.status = status;
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}
