import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/Puntensysteem/puntenlogica.dart';
import 'package:derde_divisie/Puntensysteem/punten_rollback.dart';

void main() {
  group('berekenPunten', () {
    test('geeft 10 punten voor exacte uitslag', () {
      expect(
        berekenPunten(
          voorspeldThuis: 2,
          voorspeldUit: 1,
          echtThuis: 2,
          echtUit: 1,
        ),
        10,
      );
    });

    test('geeft 5 punten voor juiste winnaar met verkeerde uitslag', () {
      expect(
        berekenPunten(
          voorspeldThuis: 3,
          voorspeldUit: 1,
          echtThuis: 2,
          echtUit: 0,
        ),
        5,
      );
    });

    test('geeft 7 punten voor correct gelijkspel met verkeerde score', () {
      expect(
        berekenPunten(
          voorspeldThuis: 1,
          voorspeldUit: 1,
          echtThuis: 2,
          echtUit: 2,
        ),
        7,
      );
    });

    test('geeft deelpunten voor losse juiste doelaantallen', () {
      expect(
        berekenPunten(
          voorspeldThuis: 2,
          voorspeldUit: 3,
          echtThuis: 2,
          echtUit: 0,
        ),
        2,
      );
    });

    test('geeft 0 punten voor volledig verkeerde voorspelling', () {
      expect(
        berekenPunten(
          voorspeldThuis: 0,
          voorspeldUit: 2,
          echtThuis: 3,
          echtUit: 1,
        ),
        0,
      );
    });

    test('herberekening is idempotent bij dezelfde uitslag', () {
      final first = _recalculatePrediction(
        _PredictionState(
          predictedHome: 2,
          predictedAway: 1,
          currentPoints: 0,
          processed: false,
          processedResult: '',
          userTotal: 0,
        ),
        actualHome: 2,
        actualAway: 1,
      );
      final second = _recalculatePrediction(
        first,
        actualHome: 2,
        actualAway: 1,
      );

      expect(first.currentPoints, 10);
      expect(first.userTotal, 10);
      expect(second.currentPoints, 10);
      expect(second.userTotal, 10);
    });

    test(
        'gewijzigde uitslag vervangt eerdere punten in plaats van op te tellen',
        () {
      final exact = _recalculatePrediction(
        _PredictionState(
          predictedHome: 2,
          predictedAway: 1,
          currentPoints: 0,
          processed: false,
          processedResult: '',
          userTotal: 0,
        ),
        actualHome: 2,
        actualAway: 1,
      );
      final changed = _recalculatePrediction(
        exact,
        actualHome: 3,
        actualAway: 1,
      );

      expect(exact.currentPoints, 10);
      expect(changed.currentPoints, 7);
      expect(changed.userTotal, 7);
    });

    test('eerder toegekende punten worden teruggedraaid', () {
      final rollback = rollbackProcessedPrediction({
        'punten': 10,
        'verwerkt': true,
        'verwerktVoorUitslag': '2-1',
      });

      expect(rollback.pointsDelta, -10);
      expect(rollback.nextPoints, 0);
      expect(rollback.nextProcessed, isFalse);
      expect(rollback.clearProcessedResult, isTrue);
    });

    test('dezelfde rollback twee keer veroorzaakt geen dubbele aftrek', () {
      final first = rollbackProcessedPrediction({
        'punten': 10,
        'verwerkt': true,
        'verwerktVoorUitslag': '2-1',
      });
      final second = rollbackProcessedPrediction({
        'punten': first.nextPoints,
        'verwerkt': first.nextProcessed,
      });

      expect(first.pointsDelta, -10);
      expect(second.pointsDelta, 0);
    });
  });
}

class _PredictionState {
  const _PredictionState({
    required this.predictedHome,
    required this.predictedAway,
    required this.currentPoints,
    required this.processed,
    required this.processedResult,
    required this.userTotal,
  });

  final int predictedHome;
  final int predictedAway;
  final int currentPoints;
  final bool processed;
  final String processedResult;
  final int userTotal;
}

_PredictionState _recalculatePrediction(
  _PredictionState state, {
  required int actualHome,
  required int actualAway,
}) {
  final resultKey = '$actualHome-$actualAway';
  if (state.processed && state.processedResult == resultKey) return state;

  final nextPoints = berekenPunten(
    voorspeldThuis: state.predictedHome,
    voorspeldUit: state.predictedAway,
    echtThuis: actualHome,
    echtUit: actualAway,
  );
  final previousPoints = state.processed ? state.currentPoints : 0;

  return _PredictionState(
    predictedHome: state.predictedHome,
    predictedAway: state.predictedAway,
    currentPoints: nextPoints,
    processed: true,
    processedResult: resultKey,
    userTotal: state.userTotal - previousPoints + nextPoints,
  );
}
