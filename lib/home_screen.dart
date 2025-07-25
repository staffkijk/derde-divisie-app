import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Inloggen/login_screen.dart';
import 'prediction_screen.dart';
import 'moderator/moderator_menu_screen.dart';

class HomeScreen extends StatelessWidget {
  final bool isModerator;

  const HomeScreen({Key? key, required this.isModerator}) : super(key: key);

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welkom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
