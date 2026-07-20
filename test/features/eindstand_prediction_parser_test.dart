import 'package:derde_divisie/features/voorspellen/eindstand_prediction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final teams = List.generate(18, (index) => 'Club ${index + 1}');
  const season = '2026-2027';

  EindstandPredictionState parse(Map<String, dynamic>? data) =>
      parseEindstandPrediction(
        data: data,
        configuredTeams: teams,
        activeSeasonId: season,
      );

  test('nieuw account zonder voorspelling krijgt alle huidige clubs', () {
    final result = parse(null);
    expect(result.clubs, teams);
    expect(result.hasValidSavedPrediction, isFalse);
    expect(result.points, 0);
  });

  test('bestaand account behoudt een geldige actuele voorspelling', () {
    final ranking = teams.reversed.toList();
    final result = parse({
      'seasonId': season,
      'voorspelling': ranking,
      'punten': 12,
    });
    expect(result.clubs, ranking);
    expect(result.hasValidSavedPrediction, isTrue);
    expect(result.points, 12);
  });

  test('oud account met ontbrekende velden valt veilig terug', () {
    final result = parse({'gebruikerId': 'legacy'});
    expect(result.clubs, teams);
    expect(result.hasValidSavedPrediction, isFalse);
  });

  test('oude voorspelling zonder seasonId wordt niet als actueel geladen', () {
    final result = parse({'voorspelling': teams.reversed.toList()});
    expect(result.clubs, teams);
    expect(result.hasValidSavedPrediction, isFalse);
  });

  test('onvolledige ranking behoudt bekende volgorde en vult clubs aan', () {
    final result = parse({
      'seasonId': season,
      'voorspelling': ['Club 3', 'Club 1'],
    });
    expect(result.clubs, hasLength(18));
    expect(result.clubs.take(2), ['Club 3', 'Club 1']);
    expect(result.clubs.toSet(), teams.toSet());
    expect(result.hasValidSavedPrediction, isFalse);
  });

  test('onbekende en dubbele clubs worden verwijderd en aangevuld', () {
    final result = parse({
      'seasonId': season,
      'voorspelling': ['Verdwenen FC', 'Club 2', 'Club 2'],
    });
    expect(result.clubs, hasLength(18));
    expect(result.clubs.first, 'Club 2');
    expect(result.clubs.toSet(), teams.toSet());
    expect(result.hasValidSavedPrediction, isFalse);
  });

  test('voorspelling uit oud seizoen valt terug op huidige clubs', () {
    final result = parse({
      'seasonId': '2025-2026',
      'voorspelling': teams.reversed.toList(),
      'punten': 99,
    });
    expect(result.clubs, teams);
    expect(result.points, 0);
    expect(result.hasValidSavedPrediction, isFalse);
  });

  test('corrupte datatypes veroorzaken geen exception', () {
    for (final data in <Map<String, dynamic>>[
      {'seasonId': season, 'voorspelling': 'geen lijst', 'punten': '12'},
      {
        'seasonId': season,
        'voorspelling': [1, null, true]
      },
      {
        'seasonId': season,
        'voorspelling': {'Club 1': 1}
      },
    ]) {
      final result = parse(data);
      expect(result.clubs, teams);
      expect(result.points, 0);
      expect(result.hasValidSavedPrediction, isFalse);
    }
  });
}
