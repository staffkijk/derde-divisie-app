import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/services/activity_analytics.dart';
import 'package:derde_divisie/data/services/activity_event_utils.dart';

void main() {
  test('aggregeert moderator dashboard datasets', () {
    final now = DateTime(2026, 7, 13, 12);
    final events = [
      ActivityLogEntry(
        id: '1',
        eventType: 'login',
        canonicalEventType: ActivityEventKeys.login,
        createdAt: now,
        userId: 'u1',
      ),
      ActivityLogEntry(
        id: '2',
        eventType: 'prediction_saved',
        canonicalEventType: ActivityEventKeys.predictionSaved,
        createdAt: now.subtract(const Duration(days: 1)),
        userId: 'u1',
        metadata: const {'round': 3},
      ),
      ActivityLogEntry(
        id: '3',
        eventType: 'screen_view',
        canonicalEventType: ActivityEventKeys.screenView,
        createdAt: now.subtract(const Duration(days: 2)),
        userId: 'u2',
        metadata: const {'screenName': 'Programma'},
      ),
      ActivityLogEntry(
        id: '4',
        eventType: 'navigation_click',
        canonicalEventType: ActivityEventKeys.navigationClick,
        createdAt: now.subtract(const Duration(days: 8)),
        userId: 'u3',
        metadata: const {'destination': 'Voorspellen'},
      ),
    ];

    final summary = ActivityAnalytics.summarize(events, now: now);

    expect(summary.eventsToday, 1);
    expect(summary.eventsSevenDays, 3);
    expect(summary.uniqueUsers, 3);
    expect(summary.predictionsSaved, 1);
    expect(summary.logins, 1);
    expect(summary.screenViews, 1);
    expect(summary.screenViewsByName['Programma'], 1);
    expect(summary.navigationByDestination['Voorspellen'], 1);
    expect(summary.predictionsByRound['Ronde 3'], 1);
  });
}
