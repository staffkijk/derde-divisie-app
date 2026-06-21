import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'faq_screen.dart';
import 'package:derde_divisie/features/voorspellen/puntentelling_screen.dart';
import 'package:derde_divisie/features/about/over_scherm.dart';
import 'package:derde_divisie/features/about/juridisch_scherm.dart';
import 'package:derde_divisie/helpers/herbereken_standen_tool.dart';
import 'package:derde_divisie/helpers/x_tweet_sync.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool _isModerator = false;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _checkModerator();
  }

  Future<void> _checkModerator() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isModerator = false;
        _loading = false;
      });
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      setState(() {
        _isModerator = data['isModerator'] == true;
        _loading = false;
      });
    } else {
      setState(() {
        _isModerator = false;
        _loading = false;
      });
    }
  }

  /// Handmatige tweet-sync via Cloud Function
  Future<void> _syncTweets() async {
    setState(() => _syncing = true);

    try {
      final added = await XTweeterSync.syncTweets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tweets bijgewerkt ($added nieuwe toegevoegd)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij synchroniseren: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Info')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Puntentelling'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PuntentellingScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.question_answer),
                    label: const Text('FAQ'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.info),
                    label: const Text('Over de app'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OverScherm()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ✅ Nieuwe knop voor Privacy / Voorwaarden / Disclaimer
                  ElevatedButton.icon(
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacy, voorwaarden & disclaimer'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JuridischScherm(
                            scrollTo: 'privacy',
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Moderator-only knoppen
                  if (_isModerator) ...[
                    const Divider(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Herbereken standen (moderator)'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HerberekenStandenTool(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      icon: const Icon(Icons.sync),
                      label: Text(
                        _syncing
                            ? 'Bezig met bijwerken...'
                            : 'Tweets bijwerken (handmatig)',
                      ),
                      onPressed: _syncing ? null : _syncTweets,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
