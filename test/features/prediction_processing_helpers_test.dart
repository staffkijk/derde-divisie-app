import 'package:flutter_test/flutter_test.dart';
import 'package:derde_divisie/Puntensysteem/prediction_processing_helpers.dart';

void main() {
  group('prediction score mapping', () {
    test('legacy score fields', () {
      final data = {'scoreThuis': 2, 'scoreUit': 1};
      expect(predictionHomeScore(data), 2);
      expect(predictionAwayScore(data), 1);
    });
    test('synthetic English score fields', () {
      final data = {'homeScore': 4, 'awayScore': 2};
      expect(predictionHomeScore(data), 4);
      expect(predictionAwayScore(data), 2);
    });
    test('synthetic Dutch score fields', () {
      final data = {'thuisScore': 3, 'uitScore': 0};
      expect(predictionHomeScore(data), 3);
      expect(predictionAwayScore(data), 0);
    });
    test('user id variants', () {
      expect(predictionUserId({'gebruikerId': 'a'}), 'a');
      expect(predictionUserId({'userId': 'b'}), 'b');
      expect(predictionUserId({'uid': 'c'}), 'c');
    });
  });

  group('mixed source selection', () {
    test('season and root users are both retained', () {
      final selected = selectLatestPredictionPerUser(const [
        PredictionCandidate(
            path: 'seasons/2026-2027/predictions/syn_match',
            data: {'userId': 'syn'},
            timestampMillis: 1),
        PredictionCandidate(
            path: 'voorspellingen/real_match',
            data: {'gebruikerId': 'real'},
            timestampMillis: 1),
      ]);
      expect(selected.map((item) => predictionUserId(item.data)).toSet(),
          {'syn', 'real'});
    });
    test('duplicate path is included once', () {
      final selected = selectLatestPredictionPerUser(const [
        PredictionCandidate(
            path: 'voorspellingen/u_match',
            data: {'gebruikerId': 'u', 'scoreThuis': 1},
            timestampMillis: 1),
        PredictionCandidate(
            path: 'voorspellingen/u_match',
            data: {'gebruikerId': 'u', 'scoreThuis': 2},
            timestampMillis: 2),
      ]);
      expect(selected, hasLength(1));
      expect(predictionHomeScore(selected.single.data), 2);
    });
    test('latest user prediction wins across sources', () {
      final selected = selectLatestPredictionPerUser(const [
        PredictionCandidate(
            path: 'seasons/2026-2027/predictions/u_match',
            data: {'userId': 'u', 'homeScore': 1},
            timestampMillis: 10),
        PredictionCandidate(
            path: 'voorspellingen/u_match',
            data: {'gebruikerId': 'u', 'scoreThuis': 3},
            timestampMillis: 20),
      ]);
      expect(selected, hasLength(1));
      expect(predictionHomeScore(selected.single.data), 3);
    });
  });
}
