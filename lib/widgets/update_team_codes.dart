import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/utils/team_code_mapping.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('TeamcodeUpdater');


Future<void> updateTeamCodesInMatches() async {
  final firestore = FirebaseFirestore.instance;
  final matches = await firestore.collection('matches').get();

  int updated = 0;

  for (final doc in matches.docs) {
    final data = doc.data();
    final home = (data['thuisteam'] ?? '').toString().trim();
    final away = (data['uitteam'] ?? '').toString().trim();

    final newHomeCode = teamCodeMapping[home] ?? home.replaceAll(RegExp(r'\W'), '').toLowerCase();
    final newAwayCode = teamCodeMapping[away] ?? away.replaceAll(RegExp(r'\W'), '').toLowerCase();

    await doc.reference.update({
      'homeTeamCode': newHomeCode,
      'awayTeamCode': newAwayCode,
    });

    updated++;
  }

  _log.info('✅ Bijwerken voltooid: $updated wedstrijden voorzien van teamcodes');
}
