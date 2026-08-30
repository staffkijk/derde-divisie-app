import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:derde_divisie/Puntensysteem/prediction_contribution_logic.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';
import 'package:derde_divisie/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late FirebaseAuth auth;
  const processor = ResultProcessingService();
  const matchId = 'A_REGRESSION_01';

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';

    db = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
    db.useFirestoreEmulator(host, 8080);
    await auth.useAuthEmulator(host, 9099);

    await auth.signInWithEmailAndPassword(
      email: 'moderator@regression.test',
      password: 'Regression123!',
    );
  });

  tearDownAll(() async {
    await auth.signOut();
  });

  testWidgets('uitslag verwerken, rerunnen, wijzigen en terugdraaien blijft consistent',
      (tester) async {
    final matchRef = SeasonPaths.currentSeasonMatches.doc(matchId);

    await processor.saveFinishedResult(
      matchRef: matchRef,
      homeScore: 2,
      awayScore: 1,
      division: 'A',
      round: 1,
      homeTeam: 'ACV',
      awayTeam: 'ADO20',
      homeTeamSlug: 'acv',
      awayTeamSlug: 'ado20',
    );

    var match = (await matchRef.get()).data()!;
    expect(match['status'], 'finished');
    expect(match['homeScore'], 2);
    expect(match['awayScore'], 1);
    expect(match['processed'], true);
    expect(match['verwerkt'], true);
    expect(match['processingStatus'], 'processed');

    var acv = (await SeasonPaths.currentSeasonStandings.doc('A_acv').get()).data()!;
    var ado = (await SeasonPaths.currentSeasonStandings.doc('A_ado20').get()).data()!;
    expect(acv['played'], 1);
    expect(acv['points'], 3);
    expect(acv['goalsFor'], 2);
    expect(acv['goalsAgainst'], 1);
    expect(ado['played'], 1);
    expect(ado['points'], 0);

    var periodAcv = (await SeasonPaths.currentSeasonPeriodStandings
            .doc('A_P1_acv')
            .get())
        .data()!;
    expect(periodAcv['played'], 1);
    expect(periodAcv['points'], 3);

    var alice = (await db.collection('users').doc('regression-alice').get()).data()!;
    var bob = (await db.collection('users').doc('regression-bob').get()).data()!;
    expect(alice['punten_A'], 10);
    expect(alice['totalen'], 10);
    expect(bob['punten_A'], 0);

    final aliceLedgerId = predictionContributionDocumentId(
      division: 'A',
      userId: 'regression-alice',
      matchId: matchId,
    );
    var aliceLedger = (await SeasonPaths.currentSeasonPredictionContributions
            .doc(aliceLedgerId)
            .get())
        .data()!;
    expect(aliceLedger['points'], 10);
    expect(aliceLedger['resultKey'], '2-1');
    expect(aliceLedger['processed'], true);

    await processor.saveFinishedResult(
      matchRef: matchRef,
      homeScore: 2,
      awayScore: 1,
      division: 'A',
      round: 1,
      homeTeam: 'ACV',
      awayTeam: 'ADO20',
      homeTeamSlug: 'acv',
      awayTeamSlug: 'ado20',
    );

    alice = (await db.collection('users').doc('regression-alice').get()).data()!;
    expect(
      alice['punten_A'],
      10,
      reason: 'dezelfde uitslag opnieuw verwerken mag geen punten verdubbelen',
    );

    await processor.saveFinishedResult(
      matchRef: matchRef,
      homeScore: 0,
      awayScore: 3,
      division: 'A',
      round: 1,
      homeTeam: 'ACV',
      awayTeam: 'ADO20',
      homeTeamSlug: 'acv',
      awayTeamSlug: 'ado20',
    );

    acv = (await SeasonPaths.currentSeasonStandings.doc('A_acv').get()).data()!;
    ado = (await SeasonPaths.currentSeasonStandings.doc('A_ado20').get()).data()!;
    expect(acv['played'], 1, reason: 'gewijzigde uitslag mag niet dubbel tellen');
    expect(acv['points'], 0);
    expect(acv['goalsFor'], 0);
    expect(acv['goalsAgainst'], 3);
    expect(ado['played'], 1);
    expect(ado['points'], 3);

    alice = (await db.collection('users').doc('regression-alice').get()).data()!;
    bob = (await db.collection('users').doc('regression-bob').get()).data()!;
    expect(alice['punten_A'], 0, reason: 'oude 10 punten moeten zijn afgeboekt');
    expect(bob['punten_A'], 7, reason: '0-2 voorspeld bij 0-3 levert 7 punten op');
    expect(bob['totalen'], 7);

    aliceLedger = (await SeasonPaths.currentSeasonPredictionContributions
            .doc(aliceLedgerId)
            .get())
        .data()!;
    expect(aliceLedger['points'], 0);
    expect(aliceLedger['resultKey'], '0-3');
    expect(aliceLedger['processed'], true);

    var pouleParticipant = (await db
            .doc('poules/regression-poule/deelnemers/regression-alice')
            .get())
        .data()!;
    var poulePrediction =
        (await db.doc('poule_predictions/regression-poule-alice-A1').get())
            .data()!;
    expect(pouleParticipant['punten'], 7);
    expect(poulePrediction['punten'], 7);
    expect(poulePrediction['verwerkt'], true);

    await processor.clearResultAndSetStatus(
      matchRef: matchRef,
      status: 'scheduled',
    );

    match = (await matchRef.get()).data()!;
    expect(match['status'], 'scheduled');
    expect(match.containsKey('homeScore'), isFalse);
    expect(match.containsKey('awayScore'), isFalse);
    expect(match['processed'], false);
    expect(match['processingStatus'], 'not_processed');

    acv = (await SeasonPaths.currentSeasonStandings.doc('A_acv').get()).data()!;
    ado = (await SeasonPaths.currentSeasonStandings.doc('A_ado20').get()).data()!;
    expect(acv['played'], 0);
    expect(acv['points'], 0);
    expect(ado['played'], 0);
    expect(ado['points'], 0);

    periodAcv = (await SeasonPaths.currentSeasonPeriodStandings
            .doc('A_P1_acv')
            .get())
        .data()!;
    expect(periodAcv['played'], 0);
    expect(periodAcv['points'], 0);

    alice = (await db.collection('users').doc('regression-alice').get()).data()!;
    bob = (await db.collection('users').doc('regression-bob').get()).data()!;
    expect(alice['punten_A'], 0);
    expect(alice['totalen'], 0);
    expect(bob['punten_A'], 0, reason: 'punten van gewijzigde uitslag moeten rollbacken');
    expect(bob['totalen'], 0);

    aliceLedger = (await SeasonPaths.currentSeasonPredictionContributions
            .doc(aliceLedgerId)
            .get())
        .data()!;
    expect(aliceLedger['points'], 0);
    expect(aliceLedger['processed'], false);

    pouleParticipant = (await db
            .doc('poules/regression-poule/deelnemers/regression-alice')
            .get())
        .data()!;
    poulePrediction =
        (await db.doc('poule_predictions/regression-poule-alice-A1').get())
            .data()!;
    expect(pouleParticipant['punten'], 0);
    expect(poulePrediction['punten'], 0);
    expect(poulePrediction['verwerkt'], false);
    expect(poulePrediction.containsKey('verwerktVoorUitslag'), isFalse);
  });
}
