import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/models/notification_preferences.dart';
import 'package:derde_divisie/data/services/notification_preferences_service.dart';
import 'package:derde_divisie/features/notifications/notification_preference_gate.dart';

class _Store implements NotificationPreferencesStore {
  final controller =
      StreamController<NotificationPreferences>.broadcast(sync: true);

  @override
  Future<NotificationPreferences> load() async =>
      const NotificationPreferences();

  @override
  Future<NotificationPreferenceSaveResult> save(
    NotificationPreferences preferences, {
    required bool wasMissingPredictionRemindersEnabled,
  }) async =>
      const NotificationPreferenceSaveResult(
        preferencesSaved: true,
        oldRemindersRemoved: true,
      );

  @override
  Stream<NotificationPreferences> watch() => controller.stream;
}

void main() {
  testWidgets('bell reacts realtime to master preference', (tester) async {
    final store = _Store();
    addTearDown(store.controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationPreferenceGate(
          service: store,
          builder: (_, __) => const Icon(
            Icons.notifications_none,
            key: Key('notification-bell'),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('notification-bell')), findsNothing);

    store.controller.add(const NotificationPreferences());
    await tester.pump();
    expect(find.byKey(const Key('notification-bell')), findsOneWidget);

    store.controller.add(
      const NotificationPreferences(missingPredictionReminders: false),
    );
    await tester.pump();
    expect(find.byKey(const Key('notification-bell')), findsNothing);

    store.controller.add(const NotificationPreferences());
    await tester.pump();
    expect(find.byKey(const Key('notification-bell')), findsOneWidget);
  });
}
