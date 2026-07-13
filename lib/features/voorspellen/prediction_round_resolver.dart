import 'package:derde_divisie/data/models/wedstrijd.dart';

class PredictionRoundMatch {
  const PredictionRoundMatch({
    required this.round,
    required this.date,
    required this.division,
  });

  final int round;
  final DateTime date;
  final String division;
}

class PredictionRoundResolver {
  const PredictionRoundResolver._();

  static int? resolve({
    required Iterable<PredictionRoundMatch> matches,
    required String division,
    required DateTime now,
  }) {
    final divisionMatches = matches
        .where((match) => _sameDivision(match.division, division))
        .where((match) => match.round > 0)
        .toList()
      ..sort((a, b) {
        final deadlineCompare = deadlineFor(a.date).compareTo(
          deadlineFor(b.date),
        );
        if (deadlineCompare != 0) return deadlineCompare;
        return a.round.compareTo(b.round);
      });

    if (divisionMatches.isEmpty) return null;

    final rounds = <int, DateTime>{};
    for (final match in divisionMatches) {
      final deadline = deadlineFor(match.date);
      final existing = rounds[match.round];
      if (existing == null || deadline.isBefore(existing)) {
        rounds[match.round] = deadline;
      }
    }

    final sorted = rounds.entries.toList()
      ..sort((a, b) {
        final deadlineCompare = a.value.compareTo(b.value);
        if (deadlineCompare != 0) return deadlineCompare;
        return a.key.compareTo(b.key);
      });

    for (final entry in sorted) {
      if (!entry.value.isBefore(now)) return entry.key;
    }

    return sorted.last.key;
  }

  static DateTime deadlineFor(DateTime matchDate) {
    final local = matchDate.toLocal();
    return DateTime(local.year, local.month, local.day, 12);
  }

  static List<PredictionRoundMatch> fromWedstrijden(
    Iterable<Wedstrijd> matches,
    String division,
  ) {
    return [
      for (final match in matches)
        PredictionRoundMatch(
          round: match.speelronde,
          date: match.datum,
          division: division,
        ),
    ];
  }

  static bool _sameDivision(String a, String b) {
    String normalize(String value) {
      final lower = value.trim().toLowerCase();
      if (lower == 'a' || lower == 'dda' || lower.endsWith(' a')) return 'a';
      if (lower == 'b' || lower == 'ddb' || lower.endsWith(' b')) return 'b';
      return lower;
    }

    return normalize(a) == normalize(b);
  }
}
