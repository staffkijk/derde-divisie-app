import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:derde_divisie/features/derde_divisie/wedstrijden_scherm_derde_divisie_a.dart';
import 'package:derde_divisie/features/profiel/profile_screen.dart';
import 'package:derde_divisie/firebase_options.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tapScoreChoice(
  WidgetTester tester,
  String label,
) async {
  final choice = find.widgetWithText(ChoiceChip, label);
  expect(choice, findsOneWidget);
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late FirebaseAuth auth;

  setUpAll(() async {
    // Android heeft een native default app via google-services.json. Die moet
    // door FlutterFire worden opgehaald in plaats van opnieuw aangemaakt.
    // Web en iOS gebruiken de door FlutterFire CLI gegenereerde Dart-opties.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await initializeDateFormatting('nl');

    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';

    db = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
    db.useFirestoreEmulator(host, 8080);
    await auth.useAuthEmulator(host, 9099);
  });

  setUp(() async {
    if (auth.currentUser != null) await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: 'alice@regression.test',
      password: 'Regression123!',
    );

    // Bewijs eerst dat deze device-run werkelijk tegen dezelfde gezaaide
    // Firebase-emulator praat. Zo onderscheiden we connectiviteitsfouten van
    // langzamere UI-opbouw op echte mobiele runners.
    expect(auth.currentUser?.uid, 'regression-alice');

    final userFixture =
        await db.collection('users').doc('regression-alice').get();
    expect(userFixture.exists, isTrue);
    expect(userFixture.data()?['username'], 'Alice Regression');

    final matchFixture = await db
        .collection('seasons')
        .doc('2026-2027')
        .collection('matches')
        .doc('A_REGRESSION_01')
        .get();
    expect(matchFixture.exists, isTrue);
    expect(matchFixture.data()?['homeTeamName'], 'ACV');
  });

  tearDownAll(() async {
    if (auth.currentUser != null) await auth.signOut();
  });

  testWidgets('gebruiker voorspelt en wijzigt dezelfde wedstrijd via de UI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WedstrijdenSchermDerdeDivisieA(
            divisie: 'A',
            initialRound: 1,
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('ACV'));
    expect(find.text('ACV'), findsWidgets);
    expect(find.text('ADO20'), findsWidgets);

    final homeScore = find.bySemanticsLabel(
      'Voorspelling ACV tegen ADO20 thuisscore',
    );
    expect(homeScore, findsOneWidget);

    await tester.tap(homeScore);
    await tester.pumpAndSettle();
    expect(find.text('Kies uitslag'), findsOneWidget);
    await _tapScoreChoice(tester, '2-1');
    await tester.pump(const Duration(milliseconds: 500));

    final predictionRef =
        db.collection('voorspellingen').doc('regression-alice_A_REGRESSION_01');
    var prediction = (await predictionRef.get()).data();
    expect(prediction, isNotNull);
    expect(prediction!['gebruikerId'], 'regression-alice');
    expect(prediction['wedstrijdId'], 'A_REGRESSION_01');
    expect(prediction['scoreThuis'], 2);
    expect(prediction['scoreUit'], 1);

    await tester.tap(homeScore);
    await tester.pumpAndSettle();
    expect(find.text('Kies uitslag'), findsOneWidget);
    await _tapScoreChoice(tester, '1-2');
    await tester.pump(const Duration(milliseconds: 500));

    prediction = (await predictionRef.get()).data();
    expect(prediction!['scoreThuis'], 1);
    expect(prediction['scoreUit'], 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WedstrijdenSchermDerdeDivisieA(
            divisie: 'A',
            initialRound: 1,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('ACV'));

    final reopened = (await predictionRef.get()).data()!;
    expect(reopened['scoreThuis'], 1);
    expect(reopened['scoreUit'], 2);
  });

  testWidgets('profiel opslaan blijft na opnieuw openen bewaard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    final descriptionField =
        find.widgetWithText(TextFormField, 'Profielbeschrijving');
    final cityField = find.widgetWithText(TextFormField, 'Woonplaats');

    await _pumpUntilFound(tester, descriptionField);
    expect(descriptionField, findsOneWidget);
    expect(cityField, findsOneWidget);

    await tester.enterText(
      descriptionField,
      'Profiel uit automatische regressietest',
    );
    await tester.enterText(cityField, 'Harderwijk');
    await tester.pumpAndSettle();

    final citySuggestion = find.text('Harderwijk');
    expect(citySuggestion, findsWidgets);
    await tester.tap(citySuggestion.last);
    await tester.pumpAndSettle();

    final saveButton = find.text('Opslaan');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump(const Duration(seconds: 1));

    final user = (await db.collection('users').doc('regression-alice').get()).data()!;
    expect(user['profileDescription'], 'Profiel uit automatische regressietest');
    expect(user['woonplaats'], 'Harderwijk');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    final reopenedDescriptionField =
        find.widgetWithText(TextFormField, 'Profielbeschrijving');
    await _pumpUntilFound(tester, reopenedDescriptionField);
    expect(reopenedDescriptionField, findsOneWidget);

    final savedUser =
        (await db.collection('users').doc('regression-alice').get()).data()!;
    expect(savedUser['profileDescription'], 'Profiel uit automatische regressietest');
    expect(savedUser['woonplaats'], 'Harderwijk');
  });
}
