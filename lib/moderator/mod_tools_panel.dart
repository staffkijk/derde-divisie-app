// lib/moderator/mod_tools_panel.dart
import 'package:flutter/material.dart';
import 'package:derde_divisie/moderator/moderator_tools_screen.dart';

class ModToolsPanel extends StatelessWidget {
  const ModToolsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderator Tools Panel')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.build),
          label: const Text('Open Moderator Tools'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModeratorToolsScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
