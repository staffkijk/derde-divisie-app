import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final users = <Map<String, dynamic>>[
    {
      'id': 'both',
      'username': 'Both',
      'punten_A': 8,
      'punten_B': 12,
      'totalen': 12
    },
    {'id': 'missing', 'username': 'Missing'},
    {'id': 'a', 'username': 'Only A', 'punten_A': 9},
    {'id': 'b', 'username': 'Only B', 'punten_B': 10},
    {'id': 'zero1', 'username': 'Alpha', 'punten_A': 0, 'punten_B': 0},
    {'id': 'zero2', 'username': 'Beta', 'punten_A': 0, 'punten_B': 0},
  ];

  List<Map<String, dynamic>> ranked(RankingType type) => sortRanking(
        users,
        type: type,
        dataOf: (user) => user,
        idOf: (user) => user['id'] as String,
      );

  test('ontbrekende, enkele en expliciete nulvelden worden als nul gelezen',
      () {
    expect(rankingScore(users[0], RankingType.global), 12);
    expect(rankingScore(users[1], RankingType.global), 0);
    expect(rankingScore(users[2], RankingType.divisionB), 0);
    expect(rankingScore(users[3], RankingType.divisionA), 0);
    expect(rankingScore(users[4], RankingType.global), 0);
  });

  test('globaal sorteert op beste score uit A of B en behoudt nulgebruikers',
      () {
    expect(ranked(RankingType.global).map((u) => u['id']),
        ['both', 'b', 'a', 'zero1', 'zero2', 'missing']);
  });

  test('Divisie A sorteert A-only correct en bevat B-only met nul', () {
    expect(ranked(RankingType.divisionA).map((u) => u['id']).take(3),
        ['a', 'both', 'zero1']);
    expect(ranked(RankingType.divisionA).any((u) => u['id'] == 'b'), isTrue);
  });

  test('Divisie B sorteert B-only correct en bevat A-only met nul', () {
    expect(ranked(RankingType.divisionB).map((u) => u['id']).take(3),
        ['both', 'b', 'zero1']);
    expect(ranked(RankingType.divisionB).any((u) => u['id'] == 'a'), isTrue);
  });

  test('nieuwe gebruikers krijgen alle rankingvelden', () {
    expect(initialRankingFields, {'punten_A': 0, 'punten_B': 0, 'totalen': 0});
  });

  test('globale score vertrouwt niet op een verouderd totalenveld', () {
    expect(bestDivisionScore({'punten_A': 4, 'punten_B': 7, 'totalen': 99}), 7);
  });
}
