import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/services/moderator_ga4_analytics_service.dart';

void main() {
  test('parses GA4 moderator response', () {
    final analytics = ModeratorGa4Analytics.fromMap({
      'configured': true,
      'visitorsToday': '3',
      'visitorsSevenDays': 21,
      'visitorsThirtyDays': 58,
      'activeUsersNow': 2,
      'sessionsThirtyDays': 74,
      'newUsersThirtyDays': 41,
      'returningUsersThirtyDays': 17,
      'topPages': [
        {'label': 'Home', 'value': '20'},
      ],
      'deviceCategories': [
        {'label': 'mobile', 'value': 14},
      ],
      'trafficSources': [
        {'label': 'Organic Search', 'value': 9},
      ],
    });

    expect(analytics.configured, isTrue);
    expect(analytics.visitorsToday, 3);
    expect(analytics.visitorsSevenDays, 21);
    expect(analytics.activeUsersNow, 2);
    expect(analytics.topPages.single.label, 'Home');
    expect(analytics.topPages.single.value, 20);
  });

  test('parses missing backend configuration', () {
    final analytics = ModeratorGa4Analytics.fromMap({
      'configured': false,
      'message': 'GA4 rapportagedata nog niet geconfigureerd',
    });

    expect(analytics.configured, isFalse);
    expect(analytics.message, 'GA4 rapportagedata nog niet geconfigureerd');
    expect(analytics.visitorsThirtyDays, 0);
  });
}
