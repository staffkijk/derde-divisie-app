import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy puntenverwerker is alleen een canonieke compatibiliteitslaag', () {
    final source = File(
      'lib/Puntensysteem/puntenverwerker.dart',
    ).readAsStringSync();

    expect(source, contains('GeneralPredictionPointsService().processMatch'));
    expect(source, contains('GeneralPredictionPointsService().rollbackMatch'));
    expect(source, contains('ResultProcessingService().saveFinishedResult'));
    expect(source, contains('ResultProcessingService().clearResultAndSetStatus'));

    expect(
      source,
      isNot(contains('FieldValue.increment')),
      reason: 'De compatibiliteitslaag mag userpunten niet zelfstandig muteren.',
    );
    expect(
      source,
      isNot(contains("collection('users')")),
      reason: 'Userpunten horen uitsluitend via de canonieke service te lopen.',
    );
    expect(
      File('lib/Puntensysteem/puntensysteemvoorspellen.dart').existsSync(),
      isFalse,
      reason: 'De oude parallelle puntenprocessor mag niet terugkomen.',
    );
  });
}
