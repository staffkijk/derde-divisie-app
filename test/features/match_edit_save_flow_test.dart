import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/derde_divisie/program_screen.dart';

void main() {
  test('tijdswijziging alleen vereist geen resultaatverwerking', () {
    expect(
      matchResultNeedsProcessing(
        initialStatus: 'scheduled',
        newStatus: 'scheduled',
        initialHomeScore: null,
        initialAwayScore: null,
        newHomeScore: null,
        newAwayScore: null,
      ),
      isFalse,
    );
  });

  test('status- of scorewijziging vereist resultaatverwerking', () {
    expect(
      matchResultNeedsProcessing(
        initialStatus: 'scheduled',
        newStatus: 'finished',
        initialHomeScore: null,
        initialAwayScore: null,
        newHomeScore: 2,
        newAwayScore: 1,
      ),
      isTrue,
    );
    expect(
      matchResultNeedsProcessing(
        initialStatus: 'finished',
        newStatus: 'finished',
        initialHomeScore: 2,
        initialAwayScore: 1,
        newHomeScore: 3,
        newAwayScore: 1,
      ),
      isTrue,
    );
  });
}
