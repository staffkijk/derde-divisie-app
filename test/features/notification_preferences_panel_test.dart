import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/models/notification_preferences.dart';
import 'package:derde_divisie/data/services/notification_preferences_service.dart';
import 'package:derde_divisie/features/notifications/prediction_reminder_preferences_panel.dart';

class _FakePreferencesStore implements NotificationPreferencesStore {
  final _controller =
      StreamController<NotificationPreferences>.broadcast(sync: true);
  NotificationPreferences value = const NotificationPreferences();
  int removedMissingPredictionReminders = 0;
  int saveCalls = 0;

  void emit() => _controller.add(value);

  @override
  Future<NotificationPreferences> load() async => value;

  @override
  Future<NotificationPreferenceSaveResult> save(
    NotificationPreferences preferences, {
    required bool wasMissingPredictionRemindersEnabled,
  }) async {
    saveCalls++;
    if (wasMissingPredictionRemindersEnabled &&
        !preferences.missingPredictionReminders) {
      removedMissingPredictionReminders = 2;
    }
    value = preferences;
    emit();
    return const NotificationPreferenceSaveResult(
      preferencesSaved: true,
      oldRemindersRemoved: true,
    );
  }

  @override
  Stream<NotificationPreferences> watch() => _controller.stream;

  Future<void> close() => _controller.close();
}

void main() {
  testWidgets('profiel en meldingsinstellingen delen direct dezelfde voorkeur',
      (tester) async {
    final store = _FakePreferencesStore();
    addTearDown(store.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: PredictionReminderPreferencesPanel(service: store),
              ),
              Expanded(
                child: PredictionReminderPreferencesPanel(service: store),
              ),
            ],
          ),
        ),
      ),
    );
    store.emit();
    await tester.pump();

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    expect(tester.widget<Switch>(switches.first).value, isTrue);
    expect(tester.widget<Switch>(switches.last).value, isTrue);

    await tester.tap(switches.first);
    await tester.pump();

    expect(store.value.missingPredictionReminders, isFalse);
    expect(store.removedMissingPredictionReminders, 2);
    expect(tester.widget<Switch>(switches.first).value, isFalse);
    expect(tester.widget<Switch>(switches.last).value, isFalse);
  });

  testWidgets('uitgeschakelde reminderfilters blijven zichtbaar maar disabled',
      (tester) async {
    final store = _FakePreferencesStore();
    store.value = const NotificationPreferences(
      missingPredictionReminders: false,
    );
    addTearDown(store.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionReminderPreferencesPanel(service: store),
        ),
      ),
    );
    store.emit();
    await tester.pump();

    expect(find.text('Derde Divisie A'), findsOneWidget);
    expect(find.text('Derde Divisie B'), findsOneWidget);
    expect(find.text('Teamvoorkeur'), findsOneWidget);
    final disabledArea = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AnimatedOpacity && widget.opacity == 0.45,
      ),
      matching: find.byType(IgnorePointer),
    );
    expect(tester.widget<IgnorePointer>(disabledArea.first).ignoring, isTrue);
  });

  testWidgets('alle voorkeurvelden slaan direct op en overleven navigeren',
      (tester) async {
    final store = _FakePreferencesStore();
    addTearDown(store.close);

    Future<void> showPanel() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PredictionReminderPreferencesPanel(service: store),
            ),
          ),
        ),
      );
      store.emit();
      await tester.pumpAndSettle();
    }

    await showPanel();
    await tester.tap(find.text('Derde Divisie A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Derde Divisie B'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle teams / alle wedstrijden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Specifieke geselecteerde teams').last);
    await tester.pumpAndSettle();

    final firstTeam = SeasonConfig.teamsInListOrder.first;
    await tester.ensureVisible(find.text(firstTeam.listLabel));
    await tester.tap(find.text(firstTeam.listLabel));
    await tester.pumpAndSettle();

    expect(store.value.divisionA, isFalse);
    expect(store.value.divisionB, isFalse);
    expect(store.value.teamScope, NotificationTeamScope.selected);
    expect(store.value.selectedTeamIds, contains(firstTeam.id));
    expect(store.saveCalls, 4);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await showPanel();

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(chips.elementAt(0).selected, isFalse);
    expect(chips.elementAt(1).selected, isFalse);
    expect(store.value.teamScope, NotificationTeamScope.selected);
    expect(store.value.selectedTeamIds, contains(firstTeam.id));
  });
}
