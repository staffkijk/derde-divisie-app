import 'package:derde_divisie/features/voorspellen/user_display_name.dart';

enum RankingType { global, divisionA, divisionB }

class RankingDestination {
  const RankingDestination(this.label, this.type);

  final String label;
  final RankingType type;
}

const rankingDestinations = [
  RankingDestination('Globale ranglijst', RankingType.global),
  RankingDestination('Ranking Divisie A', RankingType.divisionA),
  RankingDestination('Ranking Divisie B', RankingType.divisionB),
];

String rankingTitle(RankingType type) {
  switch (type) {
    case RankingType.global:
      return 'Globale ranglijst';
    case RankingType.divisionA:
      return 'Ranglijst Divisie A';
    case RankingType.divisionB:
      return 'Ranglijst Divisie B';
  }
}

String rankingContextType(RankingType type) {
  switch (type) {
    case RankingType.global:
      return 'algemeen';
    case RankingType.divisionA:
      return 'A';
    case RankingType.divisionB:
      return 'B';
  }
}

const Map<String, int> initialRankingFields = {
  'punten_A': 0,
  'punten_B': 0,
  'totalen': 0,
};

int rankingInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int bestDivisionScore(Map<String, dynamic> user) {
  final a = rankingInt(user['punten_A']);
  final b = rankingInt(user['punten_B']);
  return a > b ? a : b;
}

int rankingScore(Map<String, dynamic> user, RankingType type) {
  switch (type) {
    case RankingType.divisionA:
      return rankingInt(user['punten_A']);
    case RankingType.divisionB:
      return rankingInt(user['punten_B']);
    case RankingType.global:
      // De productdefinitie is expliciet: de beste score uit A of B. Door dit
      // af te leiden blijft de UI ook correct als een legacy `totalen` mist.
      return bestDivisionScore(user);
  }
}

List<T> sortRanking<T>(
  Iterable<T> users, {
  required RankingType type,
  required Map<String, dynamic> Function(T user) dataOf,
  required String Function(T user) idOf,
}) {
  final result = users.toList();
  result.sort((left, right) {
    final leftData = dataOf(left);
    final rightData = dataOf(right);
    final byScore =
        rankingScore(rightData, type).compareTo(rankingScore(leftData, type));
    if (byScore != 0) return byScore;

    final leftName = resolveUserDisplayName(leftData).toLowerCase();
    final rightName = resolveUserDisplayName(rightData).toLowerCase();
    final byName = leftName.compareTo(rightName);
    return byName != 0 ? byName : idOf(left).compareTo(idOf(right));
  });
  return result;
}
