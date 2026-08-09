import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logging/logging.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_options.dart';
import 'main_screen.dart';
import 'package:derde_divisie/features/faq/help_screen.dart';
import 'package:derde_divisie/data/services/analytics_service.dart';
import 'package:derde_divisie/core/config/main_navigation_config.dart';
import 'package:derde_divisie/core/widgets/ranking_app_bar.dart';
import 'screens/loading_screen.dart';

// Optioneel: backfill (alleen als je lib/admin/backfill.dart hebt)
import 'admin/backfill.dart';

// ⬇️ NIEUW: auto-reloader (luistert op system/ui.reloadAt en herlaadt web-clients)
import 'utils/app_reloader.dart';

final Color derdeDivisieGroen = const Color(0xFF3BAE5D);

// ------------------- Flags (run-time via --dart-define) -----------------------

// Gebruik emulators? Default = false (dus productie).
// Zet aan met: flutter run -d chrome --dart-define=USE_EMULATORS=true
const bool kUseEmulators =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

// Backfill flags (standaard UIT). Alleen draaien als BACKFILL_DIV is gezet.
// Dry-run: flutter run -d chrome --release
//   --dart-define=BACKFILL_DIV="Derde Divisie A" --dart-define=BACKFILL_WRITE=false
// Schrijven: idem met BACKFILL_WRITE=true
const String kBackfillDiv =
    String.fromEnvironment('BACKFILL_DIV', defaultValue: '');
const bool kBackfillWrite =
    bool.fromEnvironment('BACKFILL_WRITE', defaultValue: false);

// -----------------------------------------------------------------------------

void main() {
  _setupLogging();
  runApp(const SplashWrapper());
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '[${record.level.name}] ${record.loggerName}: ${record.message}');
  });
}

/// In DEBUG koppel je alléén aan de emulators als USE_EMULATORS=true is gezet.
/// - Web & desktop: host = localhost
/// - Android emulator: host = 10.0.2.2
Future<void> _connectToEmulatorsIfDebug() async {
  if (!kDebugMode || !kUseEmulators) return;

  final host =
      kIsWeb ? 'localhost' : (Platform.isAndroid ? '10.0.2.2' : 'localhost');

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);

  // ignore: avoid_print
  print('[Firebase] Connected to local emulators @ $host '
      '(FS=8080, Auth=9099, Storage=9199)');
}

class SplashWrapper extends StatelessWidget {
  const SplashWrapper({super.key});

  Future<void> _initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1) Firebase init met productieconfig
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // 2) In DEBUG optioneel naar emulators (alleen als USE_EMULATORS==true)
    await _connectToEmulatorsIfDebug();

    await AnalyticsService.instance.initialize();

    // 3) (optioneel) Eenmalige backfill via flags (standaard niks)
    if (kBackfillDiv.isNotEmpty) {
      // dryRun = !kBackfillWrite
      await backfillDvDt(divisie: kBackfillDiv, dryRun: !kBackfillWrite);
    }

    // 4) NL-locale
    await initializeDateFormatting('nl');

    // 5) ⬅️ NIEUW: start onzichtbare UI auto-reloader (alleen effect op web)
    //    Luistert op system/ui.reloadAt en doet een harde reload bij wijziging.
    AppReloader.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoadingScreen(),
          );
        }
        return const MyApp();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DerdeDiv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: derdeDivisieGroen,
          primary: derdeDivisieGroen,
          secondary: const Color(0xFF153B2A),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6F1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF153B2A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE3EADF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7E1D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: derdeDivisieGroen, width: 1.6),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: derdeDivisieGroen,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: derdeDivisieGroen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF153B2A),
            side: const BorderSide(color: Color(0xFFD7E1D2)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const MainScreen(),
      routes: {
        '/help': (context) => const HelpScreen(),
        predictionsRankingsRoute: (context) => const MainScreen(
              initialIndex: MainNavigationConfig.predictIndex,
              predictionInitialTabIndex: 3,
            ),
        poulesOverviewRoute: (context) => const MainScreen(
              initialIndex: MainNavigationConfig.poulesIndex,
            ),
      },
    );
  }
}
