import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';

class CsvExportService {
  const CsvExportService();

  Future<int> exportMatches({required bool resultsOnly}) async {
    if (!kIsWeb) {
      throw UnsupportedError(
          'CSV-download is momenteel alleen op web beschikbaar.');
    }
    final snapshot = await SeasonPaths.currentSeasonMatches.get();
    final rows = snapshot.docs.where((doc) {
      if (doc.id == '_meta') return false;
      if (!resultsOnly) return true;
      return (doc.data()['status'] ?? '').toString() == 'finished';
    }).map((doc) {
      final data = doc.data();
      return [
        doc.id,
        data['division'],
        data['round'],
        data['date'],
        data['kickoffTime'],
        data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam'],
        data['awayTeamName'] ?? data['awayTeam'] ?? data['uitteam'],
        data['homeScore'] ?? data['uitslagThuis'],
        data['awayScore'] ?? data['uitslagUit'],
        data['status'],
        data['processed'] ?? data['verwerkt'],
        data['processedAt'],
      ];
    }).toList();
    rows.sort((a, b) {
      final division = '${a[1]}'.compareTo('${b[1]}');
      if (division != 0) return division;
      final roundA = int.tryParse('${a[2]}') ?? 999;
      final roundB = int.tryParse('${b[2]}') ?? 999;
      if (roundA != roundB) return roundA.compareTo(roundB);
      final date = '${a[3]}'.compareTo('${b[3]}');
      if (date != 0) return date;
      return '${a[4]}'.compareTo('${b[4]}');
    });

    final csv = [
      [
        'matchId',
        'division',
        'round',
        'date',
        'kickoffTime',
        'homeTeam',
        'awayTeam',
        'homeScore',
        'awayScore',
        'status',
        'processed',
        'processedAt',
      ],
      ...rows,
    ].map((row) => row.map(_escape).join(',')).join('\r\n');

    final filename =
        resultsOnly ? 'derddiv-resultaten.csv' : 'derddiv-programma.csv';
    final blob = html.Blob([csv], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);

    await ActivityLogService().log(
      eventType: ActivityEventType.exportCreated,
      entityType: resultsOnly ? 'results' : 'matches',
      metadata: {'rowCount': rows.length},
    );
    return rows.length;
  }

  String _escape(dynamic value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }
}
