import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/general_prediction_points_service.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';

/// Legacy compatibiliteitslaag.
///
/// Algemene wedstrijdpunten mogen niet meer rechtstreeks via losse increments
/// worden verwerkt. Alle publieke helpers in dit bestand delegeren daarom naar
/// de canonieke transactionele services.

Future<void> verwerkVoorspellingenVoorWedstrijd(
  String wedstrijdId,
  int uitslagThuis,
  int uitslagUit,
  String veldnaam,
) async {
  await const GeneralPredictionPointsService().processMatch(
    matchId: wedstrijdId,
    homeScore: uitslagThuis,
    awayScore: uitslagUit,
    userPointsField: veldnaam,
  );
}

Future<void> draaiVoorspellingenVoorWedstrijdTerug(
  String wedstrijdId,
  String veldnaam,
) async {
  await const GeneralPredictionPointsService().rollbackMatch(
    matchId: wedstrijdId,
    userPointsField: veldnaam,
  );
}

Future<void> verwerkUitslagVoorWedstrijd(String wedstrijdId) async {
  final matchRef = SeasonPaths.currentSeasonMatches.doc(wedstrijdId);
  final snapshot = await matchRef.get();
  final data = snapshot.data();
  if (data == null) {
    throw StateError('Wedstrijd $wedstrijdId niet gevonden in actief seizoen.');
  }

  final homeScore = _firstIntOrNull(data, const [
    'homeScore',
    'uitslagThuis',
    'thuisScore',
  ]);
  final awayScore = _firstIntOrNull(data, const [
    'awayScore',
    'uitslagUit',
    'uitScore',
  ]);
  if (homeScore == null || awayScore == null) {
    throw StateError('Wedstrijd $wedstrijdId heeft geen volledige uitslag.');
  }

  final division = SeasonConfig.normalizeDivisionCode(
    (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '').toString(),
  );
  if (division != 'A' && division != 'B') {
    throw StateError('Divisie ontbreekt of is ongeldig voor $wedstrijdId.');
  }

  final round = _firstIntOrNull(data, const [
        'round',
        'speelronde',
        'ronde',
        'wedstrijdRonde',
      ]) ??
      0;
  final homeTeam = _firstString(data, const [
    'homeTeam',
    'thuisteam',
    'thuisTeam',
  ]);
  final awayTeam = _firstString(data, const [
    'awayTeam',
    'uitteam',
    'uitTeam',
  ]);
  if (homeTeam.isEmpty || awayTeam.isEmpty) {
    throw StateError('Teamgegevens ontbreken voor $wedstrijdId.');
  }

  final homeTeamSlug = _firstString(data, const [
    'homeTeamCode',
    'homeTeamSlug',
    'thuisteamSlug',
  ]);
  final awayTeamSlug = _firstString(data, const [
    'awayTeamCode',
    'awayTeamSlug',
    'uitteamSlug',
  ]);

  await const ResultProcessingService().saveFinishedResult(
    matchRef: matchRef,
    homeScore: homeScore,
    awayScore: awayScore,
    division: division,
    round: round,
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    homeTeamSlug: homeTeamSlug.isEmpty ? _slug(homeTeam) : homeTeamSlug,
    awayTeamSlug: awayTeamSlug.isEmpty ? _slug(awayTeam) : awayTeamSlug,
  );
}

Future<void> resetWedstrijd(String wedstrijdId) async {
  final matchRef = SeasonPaths.currentSeasonMatches.doc(wedstrijdId);
  final snapshot = await matchRef.get();
  if (!snapshot.exists) {
    throw StateError('Wedstrijd $wedstrijdId niet gevonden in actief seizoen.');
  }

  await const ResultProcessingService().clearResultAndSetStatus(
    matchRef: matchRef,
    status: 'scheduled',
  );
}

int? _firstIntOrNull(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

String _firstString(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _slug(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
