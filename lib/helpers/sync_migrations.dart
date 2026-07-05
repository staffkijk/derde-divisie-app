// lib/tools/sync_migrations.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncMigrations {
  static const _kBatchLimit = 400; // ruim onder 500 write-limit per batch

  /// Zet bij alle bestaande deelnemers in alle poules:
  ///   - 'syncEnabled' op false (alleen als het veld nog niet bestaat)
  ///   - 'syncStartAt' op null   (alleen als het veld nog niet bestaat)
  /// Overschrijft niets als de velden al bestaan.
  /// Geeft tellingen terug in een Map.
  static Future<Map<String, int>> ensureSyncFlagsForAllParticipants({
    bool dryRun = false,
  }) async {
    final db = FirebaseFirestore.instance;

    int poolsScanned = 0;
    int participantsScanned = 0;
    int participantsUpdated = 0;

    QueryDocumentSnapshot<Map<String, dynamic>>? lastPool;
    while (true) {
      Query<Map<String, dynamic>> q =
          db.collection('poules').orderBy(FieldPath.documentId).limit(200);

      if (lastPool != null) {
        q = q.startAfter([lastPool.id]);
      }

      final pools = await q.get();
      if (pools.docs.isEmpty) break;

      for (final pool in pools.docs) {
        poolsScanned++;

        QueryDocumentSnapshot<Map<String, dynamic>>? lastMember;
        while (true) {
          Query<Map<String, dynamic>> dq = db
              .collection('poules')
              .doc(pool.id)
              .collection('deelnemers')
              .orderBy(FieldPath.documentId)
              .limit(_kBatchLimit);

          if (lastMember != null) {
            dq = dq.startAfter([lastMember.id]);
          }

          final members = await dq.get();
          if (members.docs.isEmpty) break;

          WriteBatch? batch = dryRun ? null : db.batch();
          int writes = 0;

          for (final m in members.docs) {
            participantsScanned++;
            final data = m.data();
            final hasEnabled = data.containsKey('syncEnabled');
            final hasStart = data.containsKey('syncStartAt');

            if (!hasEnabled || !hasStart) {
              participantsUpdated++;
              if (!dryRun) {
                batch!.set(
                  m.reference,
                  {
                    if (!hasEnabled) 'syncEnabled': false,
                    if (!hasStart) 'syncStartAt': null,
                  },
                  SetOptions(merge: true),
                );
                writes++;
              }
            }
          }

          if (!dryRun && writes > 0) {
            await batch!.commit();
          }

          if (members.docs.length < _kBatchLimit) break;
          lastMember = members.docs.last;
        }
      }

      if (pools.docs.length < 200) break;
      lastPool = pools.docs.last;
    }

    return {
      'poolsScanned': poolsScanned,
      'participantsScanned': participantsScanned,
      'participantsUpdated': participantsUpdated,
    };
  }
}
