// lib/services/prediction_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PredictionSyncService {
  PredictionSyncService(this._db);
  final FirebaseFirestore _db;

  // === Collections ===
  static const String poulesCol = 'poules';
  static const String deelnemersSubCol = 'deelnemers';
  static const String poulePredictionsSubCol = 'voorspellingen'; // poules/{pouleId}/voorspellingen/{autoId}

  // Root collecties waar voorspellingen kunnen staan
  static const String generalPredictionsCol = 'voorspellingen';          // algemeen
  static const String rootPoulePredictionsCol1 = 'poule_predictions';    // DDA
  static const String rootPoulePredictionsCol2 = 'poule_voorspellingen'; // DDB
  static const String rootPoulePredictionsCol3 = 'predictions';          // één-team poules

  // System flags / logging
  static const String systemCol = 'system';
  static const String syncFlagsDoc = 'sync_flags';
  static const String flagBackfillDoneField = 'oneTimeUserIdBackfillDone'; // nieuwe flag
  static const String syncLogsCol = 'sync_logs';
  static const String backfillLogDoc = 'userId_backfill';

  /// Draai 1x: vul ontbrekende `gebruikerId` aan op basis van `userId` of `GebruikerID`.
  /// - dryRun:true => alleen tellen/loggen
  /// - force:true  => negeer system-flag
  Future<void> runOneTimeSync({bool dryRun = false, bool force = false}) async {
    // Check vlag
    final sysRef = _db.collection(systemCol).doc(syncFlagsDoc);
    final sysSnap = await sysRef.get();
    final alreadyDone = sysSnap.data()?[flagBackfillDoneField] == true;
    if (alreadyDone && !force) {
      throw StateError(
        'Eenmalige gebruikerId-backfill is al uitgevoerd. (Zet force:true om te forceren.)',
      );
    }

    final runId = DateTime.now().toIso8601String();
    final stats = _BackfillStats(runId: runId, dryRun: dryRun);

    // Batch helper
    WriteBatch? batch;
    int batchOps = 0;
    Future<void> commitBatch() async {
      if (batch != null && batchOps > 0 && !dryRun) {
        await batch!.commit();
      }
      batch = _db.batch();
      batchOps = 0;
    }

    await commitBatch();

    // ---- A) Root collecties
    for (final col in [
      generalPredictionsCol,
      rootPoulePredictionsCol1,
      rootPoulePredictionsCol2,
      rootPoulePredictionsCol3,
    ]) {
      final qs = await _db.collection(col).get(const GetOptions(source: Source.server));
      await _patchSnapshot(
        qs.docs,
        stats,
        addWrite: (ref, data) {
          if (!dryRun) {
            batch!.set(ref, data, SetOptions(merge: true));
            batchOps++;
          }
        },
      );
      if (batchOps >= 450) await commitBatch();
    }

    // ---- B) Subcollecties /poules/*/voorspellingen
    final cg = await _db
        .collectionGroup(poulePredictionsSubCol)
        .get(const GetOptions(source: Source.server));
    // Filter: we willen alleen de subcollecties onder /poules/*
    final subDocs = cg.docs.where((d) => d.reference.path.contains('/$poulesCol/'));
    await _patchSnapshot(
      subDocs,
      stats,
      addWrite: (ref, data) {
        if (!dryRun) {
          batch!.set(ref, data, SetOptions(merge: true));
          batchOps++;
        }
      },
    );
    if (batchOps >= 450) await commitBatch();

    await commitBatch();

    // Vlag zetten
    if (!dryRun) {
      await sysRef.set({flagBackfillDoneField: true}, SetOptions(merge: true));
    }

    // Loggen
    await _db
        .collection(syncLogsCol)
        .doc(backfillLogDoc)
        .collection('runs')
        .doc(stats.runId)
        .set(stats.toJson());

    if (kDebugMode) {
      debugPrint('BACKFILL klaar: ${stats.toJson()}');
    }
  }

  // ---------------- Helpers ----------------

  /// Doorloop docs en vul ontbrekende `gebruikerId` aan op basis van `userId`/`GebruikerID`.
  Future<void> _patchSnapshot(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    _BackfillStats stats, {
    required void Function(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) addWrite,
  }) async {
    for (final d in docs) {
      stats.scanned++;

      final data = d.data();
      final gebruikerId = _asNonEmptyString(data['gebruikerId']);
      final userId = _asNonEmptyString(data['userId']);
      final gebruikerID = _asNonEmptyString(data['GebruikerID']);

      // al OK?
      if (gebruikerId != null) {
        stats.alreadyOk++;
        continue;
      }

      // kies bron (alleen 1 richting: naar 'gebruikerId')
      final source = userId ?? gebruikerID;

      if (source == null) {
        stats.skippedNoSource++;
        continue;
      }

      // als beide bestaan en verschillend (en 'gebruikerId' ontbreekt), noteer conflict maar schrijf toch vanuit `userId ?? GebruikerID`
      if (userId != null && gebruikerID != null && userId != gebruikerID) {
        stats.conflicts++;
      }

      // schrijf merge
      addWrite(d.reference, {'gebruikerId': source});
      stats.updated++;
    }
  }

  String? _asNonEmptyString(dynamic v) {
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }
}

// --- Stats model -------------------------------------------------------------

class _BackfillStats {
  _BackfillStats({required this.runId, required this.dryRun});
  final String runId;
  final bool dryRun;

  int scanned = 0;
  int updated = 0;
  int alreadyOk = 0;
  int skippedNoSource = 0;
  int conflicts = 0;

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'dryRun': dryRun,
        'scanned': scanned,
        'updated': updated,
        'alreadyOk': alreadyOk,
        'skippedNoSource': skippedNoSource,
        'conflicts': conflicts,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
