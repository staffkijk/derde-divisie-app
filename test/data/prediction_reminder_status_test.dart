import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/services/prediction_reminder_service.dart';

void main() {
  test('herkent geen voorspellingen ingevuld', () {
    const status = PredictionReminderStatus(
      division: 'A',
      round: 1,
      totalRequired: 9,
      predicted: 0,
      missingMatchIds: ['1', '2', '3'],
    );

    expect(status.complete, isFalse);
    expect(status.missing, 3);
  });

  test('herkent gedeeltelijk en volledig ingevuld', () {
    const partial = PredictionReminderStatus(
      division: 'B',
      round: 2,
      totalRequired: 9,
      predicted: 6,
      missingMatchIds: ['7', '8', '9'],
    );
    const complete = PredictionReminderStatus(
      division: 'B',
      round: 2,
      totalRequired: 9,
      predicted: 9,
      missingMatchIds: [],
    );

    expect(partial.complete, isFalse);
    expect(complete.complete, isTrue);
  });

  test('verlopen deadline wordt herkend', () {
    final status = PredictionReminderStatus(
      division: 'A',
      round: 1,
      totalRequired: 9,
      predicted: 5,
      missingMatchIds: const ['1'],
      deadline: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(status.expired, isTrue);
  });
}
