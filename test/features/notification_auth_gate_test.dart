import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/notifications/notification_auth_gate.dart';

Widget _bellWithBadge() {
  return const Stack(
    children: [
      IconButton(
        key: Key('notification-bell'),
        tooltip: 'Meldingen',
        onPressed: null,
        icon: Icon(Icons.notifications_active_outlined),
      ),
      Text('2', key: Key('notification-badge')),
    ],
  );
}

void main() {
  testWidgets('uitgelogd toont geen meldingenknop en geen badge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationAuthGate(
          loggedIn: false,
          child: _bellWithBadge(),
        ),
      ),
    );

    expect(find.byKey(const Key('notification-bell')), findsNothing);
    expect(find.byKey(const Key('notification-badge')), findsNothing);
  });

  testWidgets('ingelogd toont de meldingenknop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationAuthGate(
          loggedIn: true,
          child: _bellWithBadge(),
        ),
      ),
    );

    expect(find.byKey(const Key('notification-bell')), findsOneWidget);
  });

  testWidgets('uitloggen verbergt de knop en badge direct', (tester) async {
    final authStates = StreamController<bool>();
    addTearDown(authStates.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamBuilder<bool>(
          stream: authStates.stream,
          initialData: true,
          builder: (context, snapshot) => NotificationAuthGate(
            loggedIn: snapshot.data == true,
            child: _bellWithBadge(),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('notification-bell')), findsOneWidget);

    authStates.add(false);
    await tester.pump();

    expect(find.byKey(const Key('notification-bell')), findsNothing);
    expect(find.byKey(const Key('notification-badge')), findsNothing);
  });
}
