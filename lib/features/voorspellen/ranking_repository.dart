import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';

class RankingEntry {
  const RankingEntry(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class RankingPage {
  const RankingPage(this.entries, this.hasMore, {this.cursor});
  final List<RankingEntry> entries;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class OwnRankingPosition {
  const OwnRankingPosition(this.entry, this.position);
  final RankingEntry entry;
  final int position;
}

class RankingRepository {
  String field(RankingType type) => type == RankingType.divisionA
      ? 'punten_A'
      : type == RankingType.divisionB
          ? 'punten_B'
          : 'totalen';
  Future<RankingPage> load(RankingType type,
      {DocumentSnapshot<Map<String, dynamic>>? after}) async {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .orderBy(field(type), descending: true)
        .orderBy('rankingName')
        .orderBy(FieldPath.documentId)
        .limit(50);
    if (after != null) q = q.startAfterDocument(after);
    final page = await q.get().timeout(const Duration(seconds: 20));
    return RankingPage(
        page.docs.map((d) => RankingEntry(d.id, d.data())).toList(),
        page.docs.length == 50,
        cursor: page.docs.isEmpty ? after : page.docs.last);
  }

  Future<OwnRankingPosition?> ownPosition(RankingType type, String uid) async {
    final collection = FirebaseFirestore.instance.collection('users');
    final own = await collection.doc(uid).get();
    if (!own.exists) return null;
    final data = own.data()!,
        score = rankingScore(data, type),
        name = (data['rankingName'] ?? '').toString();
    final counts = await Future.wait([
      collection.where(field(type), isGreaterThan: score).count().get(),
      collection
          .where(field(type), isEqualTo: score)
          .where('rankingName', isLessThan: name)
          .count()
          .get(),
      collection
          .where(field(type), isEqualTo: score)
          .where('rankingName', isEqualTo: name)
          .where(FieldPath.documentId, isLessThan: uid)
          .count()
          .get(),
    ]);
    return OwnRankingPosition(RankingEntry(uid, data),
        1 + counts.fold<int>(0, (total, c) => total + (c.count ?? 0)));
  }
}
