import 'dart:async';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_voorspelling_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beide divisies hebben lokaal 18 clubs beschikbaar', () {
    expect(
      SeasonConfig.teamNamesForDivision(SeasonConfig.divisionA),
      hasLength(18),
    );
    expect(
      SeasonConfig.teamNamesForDivision(SeasonConfig.divisionB),
      hasLength(18),
    );
  });

  test('afgeronde prediction request wordt direct teruggegeven', () async {
    final result = await loadEindstandPredictionRequest(
      Future.value('opgeslagen voorspelling'),
      timeout: const Duration(milliseconds: 50),
    );

    expect(result, 'opgeslagen voorspelling');
  });

  test('trage prediction request eindigt met timeout', () async {
    final completer = Completer<String>();

    await expectLater(
      loadEindstandPredictionRequest(
        completer.future,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
