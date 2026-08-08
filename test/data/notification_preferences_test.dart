import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/models/notification_preferences.dart';

void main() {
  test('registratie legt de gekozen reminder voorkeur expliciet vast', () {
    expect(
      initialNotificationPreferences(missingPredictionReminders: false)[
          'missingPredictionReminders'],
      isFalse,
    );
    expect(
      initialNotificationPreferences(missingPredictionReminders: true)[
          'missingPredictionReminders'],
      isTrue,
    );
  });

  test('missing field allows missing prediction reminders', () {
    final preferences = NotificationPreferences.fromMap(const {});

    expect(preferences.missingPredictionReminders, isTrue);
    expect(preferences.allowsDivision('A'), isTrue);
  });

  test('explicit true allows missing prediction reminders', () {
    final preferences = NotificationPreferences.fromMap(
      const {'missingPredictionReminders': true},
    );

    expect(preferences.allowsDivision('A'), isTrue);
  });

  test('explicit false blocks missing prediction reminders', () {
    const preferences = NotificationPreferences(
      missingPredictionReminders: false,
    );

    expect(preferences.allowsDivision('A'), isFalse);
    expect(
      preferences.allowsMatchTeams(division: 'A', matchTeamIds: ['acv']),
      isFalse,
    );
  });

  test('copyWith can disable and enable reminders again', () {
    const preferences = NotificationPreferences();

    final disabled = preferences.copyWith(missingPredictionReminders: false);
    final enabled = disabled.copyWith(missingPredictionReminders: true);

    expect(disabled.toMap()['missingPredictionReminders'], isFalse);
    expect(enabled.toMap()['missingPredictionReminders'], isTrue);
  });

  test('other notification preferences remain intact when reminders are off',
      () {
    const preferences = NotificationPreferences(
      missingPredictionReminders: false,
      divisionA: false,
      divisionB: true,
      teamScope: NotificationTeamScope.selected,
      selectedTeamIds: ['acv'],
    );

    final map = preferences.toMap();
    expect(map['divisionB'], isTrue);
    expect(map['teamScope'], 'selected');
    expect(map['selectedTeamIds'], ['acv']);
  });

  test('division filters block disabled competitions', () {
    const preferences = NotificationPreferences(divisionB: false);

    expect(preferences.allowsDivision('A'), isTrue);
    expect(preferences.allowsDivision('B'), isFalse);
  });

  test('favorite team scope only allows favorite club matches', () {
    const preferences = NotificationPreferences(
      teamScope: NotificationTeamScope.favorite,
    );

    expect(
      preferences.allowsMatchTeams(
        division: 'A',
        matchTeamIds: ['acv', 'ado20'],
        favoriteTeamId: 'acv',
      ),
      isTrue,
    );
    expect(
      preferences.allowsMatchTeams(
        division: 'A',
        matchTeamIds: ['dovo'],
        favoriteTeamId: 'acv',
      ),
      isFalse,
    );
  });

  test('selected team scope only allows selected teams', () {
    const preferences = NotificationPreferences(
      teamScope: NotificationTeamScope.selected,
      selectedTeamIds: ['dovo', 'acv'],
    );

    expect(
      preferences.allowsMatchTeams(
        division: 'A',
        matchTeamIds: ['acv'],
      ),
      isTrue,
    );
    expect(
      preferences.allowsMatchTeams(
        division: 'A',
        matchTeamIds: ['ado20'],
      ),
      isFalse,
    );
  });
}
