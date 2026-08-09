import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/models/wedstrijd.dart';
import 'package:derde_divisie/features/voorspellen/prediction_round_selection.dart';

Map<String, dynamic> match({
  required int round,
  required DateTime date,
  String division = 'A',
  String status = 'scheduled',
}) {
  return {
    'round': round,
    'date': date,
    'kickoffTime': '14:30',
    'division': division,
    'status': status,
  };
}

Wedstrijd fallback(int round, DateTime date) => Wedstrijd(
      id: 'fallback-$round',
      speelronde: round,
      datum: date,
      thuis: 'Oud thuisteam',
      uit: 'Oud uitteam',
    );

void main() {
  group('PredictionRoundSelection-integratie', () {
    test('actief seizoen 2026/2027 voor de start selecteert ronde 1', () {
      final selection = PredictionRoundSelection(division: 'A');

      expect(
        selection.initialize(
          firestoreMatches: [
            match(round: 2, date: DateTime(2026, 8, 22)),
            match(round: 1, date: DateTime(2026, 8, 15)),
          ],
          fallbackMatches: [fallback(34, DateTime(2025, 5, 24))],
          now: DateTime(2026, 7, 18),
        ),
        1,
      );
    });

    test('Firestore wint van verouderde statische fallbackdata', () {
      final selection = PredictionRoundSelection(division: 'B');

      expect(
        selection.initialize(
          firestoreMatches: [
            match(
              round: 1,
              date: DateTime(2026, 8, 16),
              division: 'Derde Divisie B',
            ),
          ],
          fallbackMatches: [fallback(34, DateTime(2025, 5, 24))],
          now: DateTime(2026, 7, 18),
        ),
        1,
      );
    });

    test('ronde 1 gespeeld en ronde 2 toekomst selecteert ronde 2', () {
      final selection = PredictionRoundSelection(division: 'A');

      expect(
        selection.initialize(
          firestoreMatches: [
            match(
              round: 1,
              date: DateTime(2026, 8, 15),
              status: 'finished',
            ),
            match(round: 2, date: DateTime(2026, 8, 22)),
          ],
          fallbackMatches: const [],
          now: DateTime(2026, 8, 16),
        ),
        2,
      );
    });

    test('uitgestelde eerdere ronde blijft relevant', () {
      final selection = PredictionRoundSelection(division: 'A');

      expect(
        selection.initialize(
          firestoreMatches: [
            match(
              round: 2,
              date: DateTime(2026, 8, 22),
              status: 'postponed',
            ),
            match(
              round: 3,
              date: DateTime(2026, 8, 29),
              status: 'finished',
            ),
          ],
          fallbackMatches: const [],
          now: DateTime(2026, 9, 1),
        ),
        2,
      );
    });

    test('handmatige ronde 5 blijft staan na snapshot-update', () {
      final selection = PredictionRoundSelection(division: 'A');
      selection.initialize(
        firestoreMatches: [match(round: 1, date: DateTime(2026, 8, 15))],
        fallbackMatches: const [],
        now: DateTime(2026, 7, 18),
      );

      selection.selectManually(5);
      selection.updateFromSnapshot([
        match(round: 1, date: DateTime(2026, 8, 15)),
        match(round: 2, date: DateTime(2026, 8, 22)),
      ]);

      expect(selection.selectedRound, 5);
      expect(selection.manuallySelected, isTrue);
    });
  });
}
