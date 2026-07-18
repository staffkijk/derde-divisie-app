import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/models/notification_collection_utils.dart';

void main() {
  const notifications = [
    UserNotificationRecord(
      id: 'missing-a',
      data: {'type': 'missing_predictions', 'read': false},
    ),
    UserNotificationRecord(
      id: 'missing-b',
      data: {'type': 'missing_predictions', 'read': false},
    ),
    UserNotificationRecord(
      id: 'other',
      data: {'type': 'announcement', 'read': false},
    ),
  ];

  test('selecteert beide missing prediction notificaties', () {
    expect(missingPredictionNotificationIds(notifications),
        ['missing-a', 'missing-b']);
  });

  test('laat andere notificatietypen ongemoeid', () {
    final removed = missingPredictionNotificationIds(notifications).toSet();
    final remaining =
        notifications.where((item) => !removed.contains(item.id)).toList();
    expect(remaining.map((item) => item.id), ['other']);
  });

  test('badge telt alleen resterende ongelezen notificaties', () {
    final removed = missingPredictionNotificationIds(notifications).toSet();
    final remaining = notifications.where((item) => !removed.contains(item.id));
    expect(unreadNotificationCount(notifications), 3);
    expect(unreadNotificationCount(remaining), 1);
  });
}
