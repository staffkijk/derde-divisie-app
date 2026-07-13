import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/services/activity_event_utils.dart';

void main() {
  group('ActivityEventUtils', () {
    final events = [
      ActivityLogEntry.fromMap('1', {'eventType': 'login'}),
      ActivityLogEntry.fromMap('2', {'eventType': ' Prediction_Saved '}),
      ActivityLogEntry.fromMap('3', {'eventType': 'LOGIN'}),
      ActivityLogEntry.fromMap('4', <String, dynamic>{}),
    ];

    test('toont alle events', () {
      expect(
        ActivityEventUtils.applyFilter(events, ActivityEventKeys.all),
        hasLength(4),
      );
    });

    test('filtert logins lokaal', () {
      final filtered = ActivityEventUtils.applyFilter(
        events,
        ActivityEventKeys.login,
      );

      expect(filtered, hasLength(2));
      expect(filtered.every((event) => event.canonicalEventType == 'login'),
          isTrue);
    });

    test('filtert voorspellingen lokaal', () {
      final filtered = ActivityEventUtils.applyFilter(
        events,
        ActivityEventKeys.predictionSaved,
      );

      expect(filtered.map((event) => event.id), ['2']);
    });

    test('normaliseert hoofdletterverschillen', () {
      expect(ActivityEventUtils.canonicalKey('LOGIN'), ActivityEventKeys.login);
      expect(
        ActivityEventUtils.canonicalKey(' Prediction Saved '),
        ActivityEventKeys.predictionSaved,
      );
    });

    test('crasht niet op ontbrekende eventvelden', () {
      final event = ActivityLogEntry.fromMap('missing', <String, dynamic>{});

      expect(event.eventType, 'onbekend');
      expect(event.canonicalEventType, 'unknown');
      expect(event.userId, isEmpty);
    });

    test('geeft lege resultaten terug als niets matcht', () {
      expect(
        ActivityEventUtils.applyFilter(
            events, ActivityEventKeys.socialCardGenerated),
        isEmpty,
      );
    });
  });
}
