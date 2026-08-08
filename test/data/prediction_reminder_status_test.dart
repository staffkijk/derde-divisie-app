import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/services/prediction_reminder_service.dart';

void main() {
  test('A reminder noemt Derde Divisie A', () {
    expect(
      missingPredictionReminderBody(missing: 9, division: 'A', round: 1),
      'Je hebt nog 9 wedstrijden niet voorspeld voor Derde Divisie A, speelronde 1.',
    );
  });

  test('B reminder noemt Derde Divisie B', () {
    expect(
      missingPredictionReminderBody(missing: 9, division: 'B', round: 1),
      'Je hebt nog 9 wedstrijden niet voorspeld voor Derde Divisie B, speelronde 1.',
    );
  });

  test('A en B bestaan naast elkaar met deterministische unieke ids', () {
    final a = missingPredictionReminderId(
      seasonId: '2026-2027',
      division: 'A',
      round: 1,
    );
    final b = missingPredictionReminderId(
      seasonId: '2026-2027',
      division: 'B',
      round: 1,
    );

    expect(a, isNot(b));
    expect(
      missingPredictionReminderId(
        seasonId: '2026-2027',
        division: 'A',
        round: 1,
      ),
      a,
    );
  });

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

  test('A volledig en B onvolledig opent B met de juiste ronde', () {
    final target = PredictionReminderTargetResolver.resolve(
      incompleteStatuses: const [
        PredictionReminderStatus(
          division: 'A',
          round: 4,
          totalRequired: 9,
          predicted: 9,
          missingMatchIds: [],
        ),
        PredictionReminderStatus(
          division: 'B',
          round: 5,
          totalRequired: 9,
          predicted: 8,
          missingMatchIds: ['b1'],
        ),
      ],
    );
    expect(target.division, 'B');
    expect(target.round, 5);
  });

  test('B volledig en A onvolledig opent A met de juiste ronde', () {
    final target = PredictionReminderTargetResolver.resolve(
      incompleteStatuses: const [
        PredictionReminderStatus(
          division: 'A',
          round: 6,
          totalRequired: 9,
          predicted: 7,
          missingMatchIds: ['a1', 'a2'],
        ),
        PredictionReminderStatus(
          division: 'B',
          round: 6,
          totalRequired: 9,
          predicted: 9,
          missingMatchIds: [],
        ),
      ],
    );
    expect(target.division, 'A');
    expect(target.round, 6);
  });

  test('expliciete melding voor B wint wanneer beide incompleet zijn', () {
    final target = PredictionReminderTargetResolver.resolve(
      notificationDivision: 'B',
      notificationRound: 7,
      incompleteStatuses: const [],
    );
    expect(target.division, 'B');
    expect(target.round, 7);
  });

  test('legacy melding zonder divisie kiest eerste incomplete status', () {
    final target = PredictionReminderTargetResolver.resolve(
      incompleteStatuses: const [
        PredictionReminderStatus(
          division: 'B',
          round: 8,
          totalRequired: 9,
          predicted: 4,
          missingMatchIds: ['b'],
        ),
      ],
    );
    expect(target.division, 'B');
    expect(target.round, 8);
  });

  test('oude melding terwijl alles compleet is valt veilig terug', () {
    final target = PredictionReminderTargetResolver.resolve(
      incompleteStatuses: const [],
    );
    expect(target.division, 'A');
    expect(target.round, 1);
  });
}
