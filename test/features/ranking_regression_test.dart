import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';

void main() {
  group('Ranglijst regressie', () {
    final users = <Map<String, dynamic>>[
      {
        'id': 'alice',
        'username': 'Alice',
        'punten_A': 12,
        'punten_B': 3,
        'totalen': 999,
      },
      {
        'id': 'bob',
        'username': 'Bob',
        'punten_A': 4,
        'punten_B': 15,
      },
      {
        'id': 'charlie',
        'username': 'Charlie',
      },
    ];

    test('globaal gebruikt beste divisiescore en negeert fout legacy totalen', () {
      final sorted = sortRanking<Map<String, dynamic>>(
        users,
        type: RankingType.global,
        dataOf: (user) => user,
        idOf: (user) => user['id'] as String,
      );

      expect(sorted.map((user) => user['id']), ['bob', 'alice', 'charlie']);
      expect(rankingScore(users.first, RankingType.global), 12);
    });

    test('Divisie A en B sorteren onafhankelijk', () {
      final a = sortRanking<Map<String, dynamic>>(
        users,
        type: RankingType.divisionA,
        dataOf: (user) => user,
        idOf: (user) => user['id'] as String,
      );
      final b = sortRanking<Map<String, dynamic>>(
        users,
        type: RankingType.divisionB,
        dataOf: (user) => user,
        idOf: (user) => user['id'] as String,
      );

      expect(a.map((user) => user['id']), ['alice', 'bob', 'charlie']);
      expect(b.map((user) => user['id']), ['bob', 'alice', 'charlie']);
    });

    test('ontbrekende rankingvelden zijn nul en verwijderen gebruiker niet', () {
      final charlie = users.last;
      expect(rankingScore(charlie, RankingType.global), 0);
      expect(rankingScore(charlie, RankingType.divisionA), 0);
      expect(rankingScore(charlie, RankingType.divisionB), 0);

      final sorted = sortRanking<Map<String, dynamic>>(
        users,
        type: RankingType.global,
        dataOf: (user) => user,
        idOf: (user) => user['id'] as String,
      );
      expect(sorted, hasLength(3));
      expect(sorted.last['id'], 'charlie');
    });
  });
}
