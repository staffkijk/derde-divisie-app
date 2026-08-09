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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late FirebaseAuth auth;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
  });

  tearDownAll(() async {
    if (auth.currentUser != null) await auth.signOut();
  });

  testWidgets('gebruiker voorspelt en wijzigt dezelfde wedstrijd via de UI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WedstrijdenSchermDerdeDivisieA(
          divisie: 'A',
          initialRound: 1,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('ACV'), findsWidgets);
    expect(find.text('ADO20'), findsWidgets);

    final homeScore = find.bySemanticsLabel(
      'Voorspelling ACV tegen ADO20 thuisscore',
    );
    expect(homeScore, findsOneWidget);

    await tester.tap(homeScore);
    await tester.pumpAndSettle();
    expect(find.text('Kies uitslag'), findsOneWidget);
    await tester.tap(find.text('2-1'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('1-2'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    prediction = (await predictionRef.get()).data();
    expect(prediction!['scoreThuis'], 1);
    expect(prediction['scoreUit'], 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const MaterialApp(
        home: WedstrijdenSchermDerdeDivisieA(
          divisie: 'A',
          initialRound: 1,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    final reopened = (await predictionRef.get()).data()!;
    expect(reopened['scoreThuis'], 1);
    expect(reopened['scoreUit'], 2);
  });

  testWidgets('profiel opslaan blijft na opnieuw openen bewaard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    final descriptionField =
        find.widgetWithText(TextFormField, 'Profielbeschrijving');
    final cityField = find.widgetWithText(TextFormField, 'Woonplaats');

    expect(descriptionField, findsOneWidget);
    expect(cityField, findsOneWidget);

    await tester.enterText(descriptionField, 'Profiel uit automatische regressietest');
    await tester.enterText(cityField, 'Harderwijk');

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
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    final savedUser =
        (await db.collection('users').doc('regression-alice').get()).data()!;
    expect(savedUser['profileDescription'], 'Profiel uit automatische regressietest');
    expect(savedUser['woonplaats'], 'Harderwijk');
  });
}
