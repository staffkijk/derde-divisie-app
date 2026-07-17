import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/models/notification_preferences.dart';

void main() {
  test('prediction reminders can be disabled entirely', () {
    const preferences = NotificationPreferences(
      predictionRemindersEnabled: false,
    );

    expect(preferences.allowsDivision('A'), isFalse);
    expect(
      preferences.allowsMatchTeams(division: 'A', matchTeamIds: ['acv']),
      isFalse,
    );
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
