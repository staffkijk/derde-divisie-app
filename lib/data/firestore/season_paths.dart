import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/data/config/season_config.dart';

class SeasonPaths {
  const SeasonPaths._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get seasons {
    return _db.collection('seasons');
  }

  static DocumentReference<Map<String, dynamic>> get currentSeasonDoc {
    return seasonDoc(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>> get currentSeasonTeams {
    return teams(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>> get currentSeasonMatches {
    return matches(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>> get currentSeasonStandings {
    return standings(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>>
      get currentSeasonPeriodStandings {
    return periodStandings(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>>
      get currentSeasonPredictions {
    return predictions(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>>
      get currentSeasonPredictionContributions {
    return predictionContributions(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>> get currentSeasonPoules {
    return poules(SeasonConfig.activeSeasonId);
  }

  static CollectionReference<Map<String, dynamic>> get currentSeasonSettings {
    return settings(SeasonConfig.activeSeasonId);
  }

  static DocumentReference<Map<String, dynamic>> get systemCurrentSeasonDoc {
    return _db.collection('system').doc('current_season');
  }

  static CollectionReference<Map<String, dynamic>> get standingsArchive {
    return _db.collection('standings_archive');
  }

  static CollectionReference<Map<String, dynamic>> get seasonArchives {
    return _db.collection('season_archives');
  }

  static DocumentReference<Map<String, dynamic>> seasonDoc(String seasonId) {
    return seasons.doc(seasonId);
  }

  static CollectionReference<Map<String, dynamic>> teams(String seasonId) {
    return seasonDoc(seasonId).collection('teams');
  }

  static CollectionReference<Map<String, dynamic>> matches(String seasonId) {
    return seasonDoc(seasonId).collection('matches');
  }

  static CollectionReference<Map<String, dynamic>> standings(String seasonId) {
    return seasonDoc(seasonId).collection('standings');
  }

  static CollectionReference<Map<String, dynamic>> periodStandings(
    String seasonId,
  ) {
    return seasonDoc(seasonId).collection('periodStandings');
  }

  static CollectionReference<Map<String, dynamic>> predictions(
    String seasonId,
  ) {
    return seasonDoc(seasonId).collection('predictions');
  }

  static CollectionReference<Map<String, dynamic>> predictionContributions(
    String seasonId,
  ) {
    return seasonDoc(seasonId).collection('predictionContributions');
  }

  static CollectionReference<Map<String, dynamic>> poules(String seasonId) {
    return seasonDoc(seasonId).collection('poules');
  }

  static CollectionReference<Map<String, dynamic>> settings(String seasonId) {
    return seasonDoc(seasonId).collection('settings');
  }
}
