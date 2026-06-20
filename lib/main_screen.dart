import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

import 'helpers/announcement_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/stand_derde_divisie.dart';
import 'screens/profile_screen.dart';
import 'moderator/moderator_menu_screen.dart';
import 'poules/screens/poules_overzicht_screen.dart';
import 'screens/prediction_overview_screen.dart';
import 'Inloggen/login_screen.dart';


// Nieuw: import voor changelog
import 'loggboek/update_log_button.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool isModerator = false;
  bool _hasMelding = false;

  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    _checkModeratorStatus();
    _loadRemoteConfig();

    // Toon melding bij openen app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      AnnouncementService.maybeShow(context, isLoggedIn: loggedIn);
    });

    // Toon (nogmaals) zodra iemand inlogt
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        AnnouncementService.maybeShow(context, isLoggedIn: true);
        _checkModeratorStatus();
        _loadRemoteConfig();
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _checkModeratorStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final mod = userDoc.data()?['isModerator'] == true;
      if (mounted) {
        setState(() {
          isModerator = mod;
        });
      }
    } catch (e) {
      debugPrint('Fout bij laden moderatorstatus: $e');
    }
  }

  Future<void> _loadRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      if (mounted) {
        setState(() {
          _hasMelding = rc.getBool('hasMelding');
        });
      }
    } catch (e) {
      debugPrint('Fout bij laden remote config: $e');
      if (mounted) setState(() => _hasMelding = false);
    }
  }

  // ✅ NIEUWE INDELING: Dashboard als eerste tab
  static const List<Widget> _screens = [
    DashboardScreen(),
    StandDerdeDivisieScreen(),
    PredictionOverviewScreen(),
    PoulesOverzichtScreen(),
    ProfileScreen(),
  ];

  static const List<String> _titles = [
    'Dashboard',
    'Derde Divisie',
    'Voorspellen',
    'Poules',
    'Profiel',
  ];

  Future<void> _onItemTapped(int index) async {
    final loginNodig = index == 2 || index == 3 || index == 4;
    final ingelogd = FirebaseAuth.instance.currentUser != null;

    if (loginNodig && !ingelogd) {
      final gelukt = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      if (!mounted) return;

      if (gelukt == true || FirebaseAuth.instance.currentUser != null) {
        setState(() {
          _selectedIndex = index;
        });
      }

      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          // Updates-log
          UpdateLogButton(isAdmin: isModerator),

          // Meldingen-bel
          if (_hasMelding)
            IconButton(
              icon: const Icon(Icons.notifications_active),
              tooltip: 'Melding opnieuw tonen',
              onPressed: () {
                AnnouncementService.showAgain(context, isLoggedIn: loggedIn);
              },
            ),

          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.pushNamed(context, '/help'),
          ),

          if (isModerator)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Moderatorpaneel',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModeratorMenuScreen()),
                );
              },
            ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.house),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_chart),
            label: 'Derde Divisie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: 'Voorspellen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Poules',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profiel',
          ),
        ],
      ),
    );
  }
}
