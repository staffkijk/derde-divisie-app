import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/models/wedstrijd.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/voorspellen/prediction_round_resolver.dart';

/// Keeps the initial Firestore-based round and a user's later manual choice
/// separate. Snapshot refreshes may update the available rounds, but never
/// overwrite a manual selection.
class PredictionRoundSelection {
  PredictionRoundSelection({required this.division});

  final String division;
  int? _selectedRound;
  bool _manuallySelected = false;
  List<PredictionRoundMatch> _seasonMatches = const [];

  int? get selectedRound => _selectedRound;
  bool get manuallySelected => _manuallySelected;

  Future<int> initializeFromCurrentSeason({
    required Iterable<Wedstrijd> fallbackMatches,
    required DateTime now,
  }) async {
    try {
      final snapshot = await SeasonPaths.currentSeasonMatches.get();
      return initialize(
        firestoreMatches: snapshot.docs
            .where((doc) => doc.id != '_meta')
            .map((doc) => doc.data()),
        fallbackMatches: fallbackMatches,
        now: now,
      );
    } catch (_) {
      return initialize(
        firestoreMatches: const [],
        fallbackMatches: fallbackMatches,
        now: now,
      );
    }
  }

  List<int> get availableRounds {
    final rounds = _seasonMatches
        .where((match) => _sameDivision(match.division, division))
        .map((match) => match.round)
        .where((round) => round > 0)
        .toSet()
        .toList()
      ..sort();
    return rounds;
  }

  int initialize({
    required Iterable<Map<String, dynamic>> firestoreMatches,
    required Iterable<Wedstrijd> fallbackMatches,
    required DateTime now,
  }) {
    final currentSeason = parseFirestoreMatches(firestoreMatches);
    _seasonMatches = currentSeason.isNotEmpty
        ? currentSeason
        : PredictionRoundResolver.fromWedstrijden(fallbackMatches, division);
    _selectedRound = PredictionRoundResolver.resolve(
          matches: _seasonMatches,
          division: division,
          now: now,
        ) ??
        1;
    return _selectedRound!;
  }

  void updateFromSnapshot(Iterable<Map<String, dynamic>> firestoreMatches) {
    final currentSeason = parseFirestoreMatches(firestoreMatches);
    if (currentSeason.isEmpty) return;
    _seasonMatches = currentSeason;
  }

  void selectManually(int round) {
    _selectedRound = round;
    _manuallySelected = true;
  }

  List<PredictionRoundMatch> parseFirestoreMatches(
    Iterable<Map<String, dynamic>> documents,
  ) {
    final result = <PredictionRoundMatch>[];
    for (final data in documents) {
      if (!_matchesDivision(data)) continue;
      final round = _readInt(data['round'] ?? data['speelronde']);
      final date = _readDate(data['date'] ?? data['datum'], data);
      if (round == null || round <= 0 || date == null) continue;
      result.add(
        PredictionRoundMatch(
          round: round,
          date: date,
          division: division,
          status: (data['status'] ?? '').toString(),
        ),
      );
    }
    return result;
  }

  bool _matchesDivision(Map<String, dynamic> data) {
    final value = (data['division'] ??
            data['divisie'] ??
            data['competition'] ??
            data['competitie'] ??
            '')
        .toString();
    return _sameDivision(value, division);
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

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDate(
    dynamic value,
    Map<String, dynamic> data,
  ) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value != null) {
      date = DateTime.tryParse(value.toString());
    }
    if (date == null) return null;

    final kickoff = (data['kickoffTime'] ?? data['tijd'] ?? '').toString();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(kickoff);
    if (match == null) return date;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return date;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
