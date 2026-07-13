import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/voorspellen/prediction_round_resolver.dart';

void main() {
  group('PredictionRoundResolver', () {
    final matches = [
      PredictionRoundMatch(
        round: 2,
        date: DateTime(2026, 8, 22, 14, 30),
        division: 'A',
      ),
      PredictionRoundMatch(
        round: 1,
        date: DateTime(2026, 8, 15, 14, 30),
        division: 'A',
      ),
      PredictionRoundMatch(
        round: 1,
        date: DateTime(2026, 8, 16, 14, 30),
        division: 'B',
      ),
      PredictionRoundMatch(
        round: 34,
        date: DateTime(2027, 5, 23, 14, 30),
        division: 'A',
      ),
    ];

    test('12 juli 2026 selecteert speelronde 1', () {
      expect(
        PredictionRoundResolver.resolve(
          matches: matches,
          division: 'A',
          now: DateTime(2026, 7, 12, 10),
        ),
        1,
      );
    });

    test('een minuut voor deadline blijft ronde 1 geselecteerd', () {
      expect(
        PredictionRoundResolver.resolve(
          matches: matches,
          division: 'A',
          now: DateTime(2026, 8, 15, 11, 59),
        ),
        1,
      );
    });

    test('een minuut na deadline selecteert volgende open ronde', () {
      expect(
        PredictionRoundResolver.resolve(
          matches: matches,
          division: 'A',
          now: DateTime(2026, 8, 15, 12, 1),
        ),
        2,
      );
    });

    test('na de laatste deadline selecteert laatste ronde', () {
      expect(
        PredictionRoundResolver.resolve(
          matches: matches,
          division: 'A',
          now: DateTime(2027, 6, 1),
        ),
        34,
      );
    });

    test('lege wedstrijdlijst geeft geen ronde terug', () {
      expect(
        PredictionRoundResolver.resolve(
          matches: const [],
          division: 'A',
          now: DateTime(2026, 7, 12),
        ),
        isNull,
      );
    });

    test('filtert per divisie', () {
      expect(
        PredictionRoundResolver.resolve(
          matches: matches,
          division: 'B',
          now: DateTime(2026, 7, 12),
        ),
        1,
      );
    });

    test('selecteert midden in het seizoen de eerste open ronde', () {
      final unorderedMatches = [
        PredictionRoundMatch(
          round: 5,
          date: DateTime(2026, 9, 12, 14, 30),
          division: 'A',
        ),
        PredictionRoundMatch(
          round: 3,
          date: DateTime(2026, 8, 29, 14, 30),
          division: 'A',
        ),
        PredictionRoundMatch(
          round: 4,
          date: DateTime(2026, 9, 5, 14, 30),
          division: 'A',
        ),
      ];

      expect(
        PredictionRoundResolver.resolve(
          matches: unorderedMatches,
          division: 'A',
          now: DateTime(2026, 8, 29, 12, 1),
        ),
        4,
      );
    });
  });
}
