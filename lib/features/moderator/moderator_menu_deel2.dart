// lib/moderator/moderator_menu_deel2.dart
import 'package:flutter/material.dart';

// Pad klopt omdat dit bestand in dezelfde map staat.
// Pas aan als jij AdminSyncToolsScreen elders hebt staan.
import 'admin_sync_tools_screen.dart';

class ModeratorMenuDeel2 extends StatelessWidget {
  const ModeratorMenuDeel2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderator')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        children: <Widget>[
          // ---- Voeg hier evt. je bestaande moderator-items toe ----
          // ListTile(
          //   leading: const Icon(Icons.build),
          //   title: const Text('Bestaande tool X'),
          //   onTap: () { ... },
          // ),

          // === NIEUW: knop naar de Sync tools (migratie) ===
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync tools'),
            subtitle: const Text('Zet sync-vlag bij alle deelnemers'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminSyncToolsScreen(),
                ),
              );
            },
          ),

          // ---- evt. meer items hieronder ----
        ],
      ),
    );
  }
}
