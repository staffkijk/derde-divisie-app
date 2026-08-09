// lib/screens/admin_sync_tools_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// pas dit pad aan naar waar je 'm hebt neergezet
import 'package:derde_divisie/helpers/sync_migrations.dart';

class AdminSyncToolsScreen extends StatefulWidget {
  const AdminSyncToolsScreen({super.key});

  @override
  State<AdminSyncToolsScreen> createState() => _AdminSyncToolsScreenState();
}

class _AdminSyncToolsScreenState extends State<AdminSyncToolsScreen> {
  bool _busy = false;
  String _log = '';

  Future<bool> _isModerator() async {
    final user = FirebaseAuth.instance.currentUser;

    // In dev builds mag je eventueel door zonder login; haal dit weg als je dat niet wilt.
    if (user == null) return !kReleaseMode;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snap.data() ?? {};
    return data['ismoderator'] == true;
  }

  Future<void> _run({required bool dryRun}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _log = 'Bezig… (dryRun: $dryRun)';
    });

    try {
      final res = await SyncMigrations.ensureSyncFlagsForAllParticipants(
          dryRun: dryRun);

      setState(() {
        _log = 'Klaar ${dryRun ? "(dry-run)" : ""}:\n'
            'poules gescand: ${res["poolsScanned"]}\n'
            'deelnemers gescand: ${res["participantsScanned"]}\n'
            'deelnemers bijgewerkt: ${res["participantsUpdated"]}';
      });

      if (!dryRun) {
        await FirebaseFirestore.instance.doc('maintenance/migrations').set(
            {'syncFlagsV1_lastRun': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(dryRun ? 'Dry-run klaar' : 'Migration uitgevoerd')),
        );
      }
    } catch (e) {
      setState(() => _log = 'Fout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout tijdens uitvoeren: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isModerator(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data != true) {
          return const Scaffold(body: Center(child: Text('Geen toegang')));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Admin • Sync Tools')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    '1) Zet sync-vlag op alle bestaande deelnemers (standaard UIT).'),
                const SizedBox(height: 12),
                Wrap(spacing: 12, children: [
                  ElevatedButton(
                    onPressed: _busy ? null : () => _run(dryRun: true),
                    child: const Text('Dry-run'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(dryRun: false),
                    child: const Text('Uitvoeren'),
                  ),
                ]),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                SelectableText(_log),
              ],
            ),
          ),
        );
      },
    );
  }
}
