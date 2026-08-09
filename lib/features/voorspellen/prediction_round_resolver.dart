import 'package:derde_divisie/data/models/wedstrijd.dart';

class PredictionRoundMatch {
  const PredictionRoundMatch({
    required this.round,
    required this.date,
    required this.division,
    this.status,
  });

  final int round;
  final DateTime date;
  final String division;
  final String? status;

  bool get isPlayed {
    final normalized = _normalizedStatus;
    return normalized == 'finished' ||
        normalized == 'played' ||
        normalized == 'gespeeld' ||
        normalized == 'processed' ||
        normalized == 'verwerkt';
  }

  bool isUnplayedAt(DateTime now) {
    final normalized = _normalizedStatus;
    if (isPlayed) return false;
    if (normalized == 'scheduled' ||
        normalized == 'postponed' ||
        normalized == 'uitgesteld') {
      return true;
    }

    return date.isAfter(now);
  }

  String get _normalizedStatus => status?.trim().toLowerCase() ?? '';
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

    final rounds = <int, _RoundState>{};
    for (final match in divisionMatches) {
      final deadline = deadlineFor(match.date);
      final existing = rounds[match.round];
      if (existing == null) {
        rounds[match.round] = _RoundState(
          round: match.round,
          earliestDeadline: deadline,
          earliestMatchDate: match.date,
          hasUnplayedMatch: match.isUnplayedAt(now),
        );
      } else {
        rounds[match.round] = existing.add(match, deadline, now);
      }
    }

    final sorted = rounds.values.toList()
      ..sort((a, b) {
        final deadlineCompare = a.earliestDeadline.compareTo(
          b.earliestDeadline,
        );
        if (deadlineCompare != 0) return deadlineCompare;
        return a.round.compareTo(b.round);
      });

    for (final round in sorted) {
      if (round.hasUnplayedMatch && !round.earliestDeadline.isBefore(now)) {
        return round.round;
      }
    }

    final byRound = [...sorted]..sort((a, b) => a.round.compareTo(b.round));

    for (final round in byRound) {
      if (round.hasUnplayedMatch) return round.round;
    }

    return byRound.last.round;
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
          status: _wedstrijdStatus(match),
        ),
    ];
  }

  static String _wedstrijdStatus(Wedstrijd match) {
    final dynamic dynamicMatch = match;
    try {
      return dynamicMatch.status?.toString() ?? '';
    } catch (_) {
      return '';
    }
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

class _RoundState {
  const _RoundState({
    required this.round,
    required this.earliestDeadline,
    required this.earliestMatchDate,
    required this.hasUnplayedMatch,
  });

  final int round;
  final DateTime earliestDeadline;
  final DateTime earliestMatchDate;
  final bool hasUnplayedMatch;

  _RoundState add(PredictionRoundMatch match, DateTime deadline, DateTime now) {
    return _RoundState(
      round: round,
      earliestDeadline:
          deadline.isBefore(earliestDeadline) ? deadline : earliestDeadline,
      earliestMatchDate: match.date.isBefore(earliestMatchDate)
          ? match.date
          : earliestMatchDate,
      hasUnplayedMatch: hasUnplayedMatch || match.isUnplayedAt(now),
    );
  }
}
