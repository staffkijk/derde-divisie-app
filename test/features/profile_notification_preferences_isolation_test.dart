import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('algemene profielopslag schrijft notificationPreferences niet', () {
    final source =
        File('lib/features/profiel/profile_screen.dart').readAsStringSync();

    expect(source, isNot(contains("'notificationPreferences':")));
    expect(source, contains('const PredictionReminderPreferencesPanel()'));
  });
}
