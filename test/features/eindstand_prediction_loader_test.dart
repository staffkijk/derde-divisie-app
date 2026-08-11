import 'dart:async';

import 'package:derde_divisie/features/voorspellen/eindstand_prediction_loader.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_prediction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final teams = List.generate(18, (index) => 'Club ${index + 1}');
  const season = '2026-2027';

  Future<EindstandPredictionState> load(
    EindstandPredictionRead readPrediction, {
    Duration timeout = const Duration(milliseconds: 20),
  }) {
    return loadEindstandPrediction(
      readPrediction: readPrediction,
      configuredTeams: teams,
      activeSeasonId: season,
      timeout: timeout,
    );
  }

  test('behoudt exact de opgeslagen actuele volgorde', () async {
    final ranking = teams.reversed.toList();

    final result = await load(() async => {
          'seasonId': season,
          'voorspelling': ranking,
          'punten': 7,
        });

    expect(result.clubs, ranking);
    expect(result.hasValidSavedPrediction, isTrue);
    expect(result.points, 7);
  });

  test('ontbrekend document gebruikt configuredTeams als nieuwe voorspelling',
      () async {
    final result = await load(() async => null);

    expect(result.clubs, teams);
    expect(result.hasValidSavedPrediction, isFalse);
  });

  test('onvoltooide read eindigt met een timeout', () async {
    final neverCompletes = Completer<Map<String, dynamic>?>();

    await expectLater(
      load(
        () => neverCompletes.future,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('readfout wordt doorgegeven en niet als ontbrekend document behandeld',
      () async {
    final error = StateError('netwerkfout');

    await expectLater(load(() async => throw error), throwsA(same(error)));
  });

  test('nieuwe laadpoging kan na een readfout alsnog slagen', () async {
    var attempts = 0;

    Future<Map<String, dynamic>?> readPrediction() async {
      attempts++;
      if (attempts == 1) throw StateError('tijdelijk niet beschikbaar');
      return {
        'seasonId': season,
        'voorspelling': teams,
      };
    }

    await expectLater(load(readPrediction), throwsStateError);
    final result = await load(readPrediction);

    expect(attempts, 2);
    expect(result.clubs, teams);
    expect(result.hasValidSavedPrediction, isTrue);
  });
}
