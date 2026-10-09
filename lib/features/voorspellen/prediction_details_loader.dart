import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class PredictionDocument {
  const PredictionDocument(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class PredictionDetails {
  const PredictionDetails(this.predictions, this.matches);
  final Map<String, Map<String, dynamic>> predictions;
  final Map<String, Map<String, dynamic>> matches;
}

typedef PredictionPageReader = Future<List<PredictionDocument>> Function(
    String source, String owner, String user, String? cursor);
typedef PredictionMatchReader = Future<Map<String, Map<String, dynamic>>>
    Function(List<String> ids);

class PredictionDetailsLoader {
  PredictionDetailsLoader(
      {PredictionPageReader? pageReader, PredictionMatchReader? matchReader})
      : _pageReader = pageReader ?? _readPage,
        _matchReader = matchReader ?? _readMatches;
  final PredictionPageReader _pageReader;
  final PredictionMatchReader _matchReader;
  static const pageSize = 200;
  static Future<List<PredictionDocument>> _readPage(
      String source, String owner, String user, String? cursor) async {
    final collection = source == 'season'
        ? SeasonPaths.currentSeasonPredictions
        : FirebaseFirestore.instance.collection('voorspellingen');
    Query<Map<String, dynamic>> query = collection
        .where(owner, isEqualTo: user)
        .orderBy(FieldPath.documentId)
        .limit(pageSize);
    if (cursor != null) query = query.startAfter([cursor]);
    final page = await query.get();
    return page.docs.map((d) => PredictionDocument(d.id, d.data())).toList();
  }

  static Future<Map<String, Map<String, dynamic>>> _readMatches(
      List<String> ids) async {
    final page = await SeasonPaths.currentSeasonMatches
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return {for (final d in page.docs) d.id: d.data()};
  }

  Future<PredictionDetails> load(String user) async {
    final requests = <Future<List<PredictionDocument>>>[];
    for (final source in ['legacy', 'season']) {
      for (final owner in ['gebruikerId', 'userId', 'uid']) {
        requests.add(_all(source, owner, user));
      }
    }
    final pages = await Future.wait(requests);
    final byMatch = <String, Map<String, dynamic>>{},
        paths = <String, String>{};
    for (var source = 0; source < pages.length; source++) {
      for (final doc in pages[source]) {
        final id =
            (doc.data['wedstrijdId'] ?? doc.data['matchId'] ?? '').toString();
        if (id.isEmpty) continue;
        final path =
                '${source >= 3 ? 'seasons/2026-2027/predictions' : 'voorspellingen'}/${doc.id}',
            old = byMatch[id];
        int time(Map<String, dynamic>? p) => p?['timestamp'] is Timestamp
            ? (p!['timestamp'] as Timestamp).millisecondsSinceEpoch
            : 0;
        if (old == null ||
            time(doc.data) > time(old) ||
            (time(doc.data) == time(old) && path.compareTo(paths[id]!) < 0)) {
          byMatch[id] = doc.data;
          paths[id] = path;
        }
      }
    }
    final ids = byMatch.keys.toList(),
        matches = <String, Map<String, dynamic>>{};
    // Four independent requests at a time; never one request per prediction.
    for (var offset = 0; offset < ids.length; offset += 120) {
      final group = <Future<Map<String, Map<String, dynamic>>>>[];
      for (var i = offset; i < ids.length && i < offset + 120; i += 30) {
        group.add(_matchReader(ids.sublist(i, (i + 30).clamp(0, ids.length)))
            .timeout(const Duration(seconds: 20)));
      }
      for (final page in await Future.wait(group)) {
        matches.addAll(page);
      }
    }
    return PredictionDetails(byMatch, matches);
  }

  Future<List<PredictionDocument>> _all(
      String source, String owner, String user) async {
    final docs = <PredictionDocument>[];
    String? cursor;
    while (true) {
      final page = await _pageReader(source, owner, user, cursor)
          .timeout(const Duration(seconds: 20));
      docs.addAll(page);
      if (page.length < pageSize) return docs;
      final next = page.last.id;
      if (next == cursor) {
        throw StateError('Voorspellingenpagina herhaalt dezelfde cursor.');
      }
      cursor = next;
    }
  }
}
