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

  test('alle bekende legacy reminder types worden opgeschoond', () {
    final legacy = <UserNotificationRecord>[
      for (final type in predictionReminderNotificationTypes)
        UserNotificationRecord(id: 'legacy-$type', data: {'type': type}),
      const UserNotificationRecord(
        id: 'missing_predictions_2025_A_1',
        data: {},
      ),
      const UserNotificationRecord(
        id: 'missing-predictions_2025_1',
        data: {},
      ),
      const UserNotificationRecord(
        id: 'real-announcement',
        data: {'type': 'announcement'},
      ),
    ];

    final removed = missingPredictionNotificationIds(legacy);
    expect(removed, hasLength(predictionReminderNotificationTypes.length + 2));
    expect(removed, isNot(contains('real-announcement')));
  });

  test('badge wordt nul wanneer alleen reminders overblijven voor cleanup', () {
    final removed = missingPredictionNotificationIds(notifications).toSet();
    final remindersOnly = notifications.take(2);
    final remaining = remindersOnly.where((item) => !removed.contains(item.id));
    expect(unreadNotificationCount(remaining), 0);
  });

  test('reeds gelezen en opgeloste reminders blijven in de historie', () {
    const history = UserNotificationRecord(
      id: 'missing_predictions_2025_A_1',
      data: {
        'type': 'missing_predictions',
        'read': true,
        'resolved': true,
      },
    );

    expect(missingPredictionNotificationIds([history]), isEmpty);
  });

  test('cleanup verwijdert moderne en metadata-arme legacy reminder en badge',
      () {
    const existing = [
      UserNotificationRecord(
        id: 'missing_predictions_2026-2027_A_1',
        data: {
          'type': 'missing_predictions',
          'division': 'A',
          'round': 1,
          'read': false,
          'resolved': false,
        },
      ),
      UserNotificationRecord(
        id: 'legacy-random-document-id',
        data: {
          'title': 'Voorspellingen ontbreken',
          'body': 'Je hebt nog 9 wedstrijden niet voorspeld voor speelronde 1.',
          'read': false,
        },
      ),
    ];

    final removed = missingPredictionNotificationIds(existing).toSet();
    final remaining = existing.where((item) => !removed.contains(item.id));

    expect(removed, {
      'missing_predictions_2026-2027_A_1',
      'legacy-random-document-id',
    });
    expect(remaining, isEmpty);
    expect(unreadNotificationCount(remaining), 0);
  });
}
