import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prediction, ledger en user worden in een transaction geschreven', () {
    final source = File(
      'lib/features/moderator/general_prediction_points_service.dart',
    ).readAsStringSync();
    final normalized = source.replaceAll('\r\n', '\n');
    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ');

    expect(compact, contains('runTransaction'));
    expect(compact, contains('transaction.set( predictionRef'));
    expect(compact, contains('transaction.set( ledgerRef'));
    expect(compact, contains('transaction.set( userRef'));
  });

  test('result processing markeert processing, processed en failed expliciet',
      () {
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

  test('rollback gebruikt canonieke algemene en poule services', () {
    final source = File(
      'lib/features/moderator/result_processing_service.dart',
    ).readAsStringSync();

    expect(source, contains('GeneralPredictionPointsService().rollbackMatch'));
    expect(source, contains('PoulePredictionRollbackService().rollbackMatch'));
    expect(source, isNot(contains('draaiVoorspellingenVoorWedstrijdTerug')));
  });
}
