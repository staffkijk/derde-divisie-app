import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Inloggen/login_screen.dart';
import 'prediction_screen.dart';
import 'moderator/moderator_menu_screen.dart';

// Updates-log knop met badge
import 'loggboek/update_log_button.dart';

class HomeScreen extends StatelessWidget {
  final bool isModerator;

  const HomeScreen({super.key, required this.isModerator});

  void _signOut(BuildContext context) async {
    final navigator = Navigator.of(context); // Sla Navigator vooraf op
    await FirebaseAuth.instance.signOut();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welkom'),
        actions: [
          // Updates-log met badge
          UpdateLogButton(isAdmin: isModerator),

          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Uitloggen',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.sports_soccer),
            title: const Text('Voorspellen Divisie A'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PredictionScreen(divisie: 'A'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sports_soccer),
            title: const Text('Voorspellen Divisie B'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PredictionScreen(divisie: 'B'),
                ),
              );
            },
          ),
          if (isModerator)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Moderatorpaneel'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ModeratorMenuScreen(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
