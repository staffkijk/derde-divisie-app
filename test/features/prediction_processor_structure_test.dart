import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prediction, ledger en user worden in een transaction geschreven', () {
    final source = File(
      'lib/features/moderator/general_prediction_points_service.dart',
    ).readAsStringSync();

    expect(source, contains('runTransaction'));
    expect(source, contains('transaction.set(\n          predictionRef'));
    expect(source, contains('transaction.set(\n          ledgerRef'));
    expect(source, contains('transaction.set(\n          userRef'));
  });

  test('result processing markeert processing, processed en failed expliciet', () {
    final source = File(
      'lib/features/moderator/result_processing_service.dart',
    ).readAsStringSync();

    final process = source.indexOf('.processMatch(');
    final processed = source.indexOf("'processed': true", process);
    expect(process, greaterThanOrEqualTo(0));
    expect(processed, greaterThan(process));
    expect(source, contains("'processingStatus': 'processing'"));
    expect(source, contains("'processingStatus': 'processed'"));
    expect(source, contains("'processingStatus': 'failed'"));
    expect(source, contains("'processingFailedAt'"));
  });

  test('rollback gebruikt dezelfde canonieke service', () {
    final source = File(
      'lib/features/moderator/result_processing_service.dart',
    ).readAsStringSync();

    expect(source, contains('GeneralPredictionPointsService().rollbackMatch'));
    expect(source, isNot(contains('draaiVoorspellingenVoorWedstrijdTerug')));
  });
}
