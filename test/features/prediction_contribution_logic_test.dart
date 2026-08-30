import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/Puntensysteem/prediction_contribution_logic.dart';
import 'package:derde_divisie/Puntensysteem/puntenlogica.dart';

void main() {
  group('berekenPunten regressie', () {
    test('exact is 10', () {
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

    test('juiste winnaar is 5', () {
      expect(
        berekenPunten(
          voorspeldThuis: 2,
          voorspeldUit: 1,
          echtThuis: 4,
          echtUit: 3,
        ),
        5,
      );
    });

    test('juiste winnaar plus een exact doelaantal is 7', () {
      expect(
        berekenPunten(
          voorspeldThuis: 2,
          voorspeldUit: 1,
          echtThuis: 3,
          echtUit: 1,
        ),
        7,
      );
    });
  });

  group('canonieke bijdrage', () {
    test('eerste verwerking kent bijdrage eenmaal toe', () {
      final transition = planPredictionContribution(
        newPoints: 7,
        resultKey: '3-1',
      );
      expect(transition.previousPoints, 0);
      expect(transition.delta, 7);
    });

    test('dezelfde uitslag opnieuw verwerken heeft delta nul', () {
      final transition = planPredictionContribution(
        newPoints: 7,
        resultKey: '3-1',
        ledger: const PredictionContributionState(
          points: 7,
          resultKey: '3-1',
          processed: true,
        ),
      );
      expect(transition.delta, 0);
    });

    test('twee retries convergeren zonder dubbele bijdrage', () {
      var ledger = const PredictionContributionState(
        points: 0,
        resultKey: '',
        processed: false,
      );
      var userPoints = 0;
      for (var attempt = 0; attempt < 2; attempt++) {
        final transition = planPredictionContribution(
          newPoints: 7,
          resultKey: '3-1',
          ledger: ledger,
        );
        userPoints += transition.delta;
        ledger = PredictionContributionState(
          points: transition.nextPoints,
          resultKey: transition.resultKey,
          processed: true,
        );
      }
      expect(userPoints, 7);
    });

    test('gewijzigde uitslag vervangt oude bijdrage', () {
      final transition = planPredictionContribution(
        newPoints: 2,
        resultKey: '1-1',
        ledger: const PredictionContributionState(
          points: 7,
          resultKey: '3-1',
          processed: true,
        ),
      );
      expect(transition.delta, -5);
      expect(20 + transition.delta, 15);
    });

    test('bestaande verwerkte productieprediction wordt zonder dubbeling geadopteerd', () {
      final transition = planPredictionContribution(
        newPoints: 7,
        resultKey: '3-1',
        prediction: const PredictionContributionState(
          points: 7,
          resultKey: '3-1',
          processed: true,
        ),
      );
      expect(transition.adoptsExistingContribution, isTrue);
      expect(transition.delta, 0);
    });

    test('root en season prediction gebruiken dezelfde deterministische ledger-id', () {
      final first = predictionContributionDocumentId(
        division: 'B',
        userId: 'user-1',
        matchId: 'b_03_04',
      );
      final second = predictionContributionDocumentId(
        division: 'B',
        userId: 'user-1',
        matchId: 'b_03_04',
      );
      expect(first, second);
    });
  });

  group('read-only herberekening', () {
    test('A en B blijven onafhankelijk en totalen is max', () {
      final totals = rebuildPredictionTotals(const [
        PredictionContributionValue(division: 'A', points: 10),
        PredictionContributionValue(division: 'A', points: 2),
        PredictionContributionValue(division: 'B', points: 7),
      ]);
      expect(totals.pointsA, 12);
      expect(totals.pointsB, 7);
      expect(totals.totalen, 12);
    });
  });
}
