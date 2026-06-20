// lib/moderator/moderator_menu_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Puntensysteem
import 'package:derde_divisie/Puntensysteem/puntenverwerker.dart'
    show verwerkUitslagVoorWedstrijd;
import 'package:derde_divisie/Puntensysteem/eindstand_puntenverwerker.dart'
    show verwerkEindstandPunten;

// Moderator services
import 'package:derde_divisie/moderator/init_vorige_scores.dart';
import 'package:derde_divisie/moderator/speelronde_reset_service.dart';
import 'package:derde_divisie/moderator/standen_service.dart';
import 'package:derde_divisie/moderator/periodestand_service.dart';
import 'package:derde_divisie/moderator/reset_eindstand_punten.dart' as reset;

// Helpers
import 'package:derde_divisie/utils/teamcode_updater.dart';

import 'moderator_tools_screen.dart';

class ModeratorMenuScreen extends StatefulWidget {
  const ModeratorMenuScreen({super.key});

  @override
  State<ModeratorMenuScreen> createState() => _ModeratorMenuScreenState();
}

class _ModeratorMenuScreenState extends State<ModeratorMenuScreen> {
  String _geselecteerdeDivisie = 'Derde Divisie A';
  int _geselecteerdeSpeelronde = 1;

  final Map<String, TextEditingController> _thuisControllers = {};
  final Map<String, TextEditingController> _uitControllers = {};

  late Future<QuerySnapshot> _matchesFuture;
  bool _initialisatieKlaar = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startModeratorInitialisatie();
  }

  Future<void> _startModeratorInitialisatie() async {
    await initVorigeScores();
    _laadWedstrijden();
    if (!mounted) return;
    setState(() => _initialisatieKlaar = true);
  }

  void _laadWedstrijden() {
    setState(() {
      _matchesFuture = FirebaseFirestore.instance
          .collection('matches')
          .where('competitie', isEqualTo: _geselecteerdeDivisie)
          .where('speelronde', isEqualTo: _geselecteerdeSpeelronde)
          .get();
    });
  }

  @override
  void dispose() {
    for (final c in _thuisControllers.values) {
      c.dispose();
    }
    for (final c in _uitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _resetSpeelronde() async {
    final divisieCode = _geselecteerdeDivisie.contains('A') ? 'A' : 'B';
    try {
      await SpeelrondeResetService().resetSpeelronde(
        divisieCode,
        _geselecteerdeSpeelronde,
      );

      _thuisControllers.clear();
      _uitControllers.clear();
      _laadWedstrijden();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speelronde is gereset.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij resetten: $e')),
      );
    }
  }

  Future<void> _verwerkAutomatisch(
    String docId,
    int? nieuweThuis,
    int? nieuweUit,
  ) async {
    if (nieuweThuis == null || nieuweUit == null) return;

    final docRef = FirebaseFirestore.instance.collection('matches').doc(docId);
    final docSnapshot = await docRef.get();
    final data = docSnapshot.data();
    if (data == null) return;

    final Map<String, dynamic> updates = {
      'vorigeUitslagThuis': data['uitslagThuis'],
      'vorigeUitslagUit': data['uitslagUit'],
      'uitslagThuis': nieuweThuis,
      'uitslagUit': nieuweUit,
    };

    if (data['homeTeamCode'] == null) {
      updates['homeTeamCode'] =
          teamCodeMapping[data['thuisteam']] ?? data['thuisteam'];
    }
    if (data['awayTeamCode'] == null) {
      updates['awayTeamCode'] =
          teamCodeMapping[data['uitteam']] ?? data['uitteam'];
    }

    await docRef.update(updates);

    await verwerkUitslagVoorWedstrijd(docId);
    await StandenService().herberekenStandenVoorCompetitie(data['competitie']);

    final String divisieCode =
        (data['competitie'] as String).endsWith('A') ? 'A' : 'B';
    await PeriodestandService().herberekenAllePeriodesVoorDivisie(divisieCode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialisatieKlaar) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderatorpaneel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Reset speelronde',
            onPressed: _busy ? null : _resetSpeelronde,
          ),
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: 'Moderator Tools',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModeratorToolsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<String>(
                value: _geselecteerdeDivisie,
                items: const [
                  DropdownMenuItem(
                    value: 'Derde Divisie A',
                    child: Text('Divisie A'),
                  ),
                  DropdownMenuItem(
                    value: 'Derde Divisie B',
                    child: Text('Divisie B'),
                  ),
                ],
                onChanged: (value) {
                  _geselecteerdeDivisie = value!;
                  _thuisControllers.clear();
                  _uitControllers.clear();
                  _laadWedstrijden();
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _geselecteerdeSpeelronde,
                items: List.generate(
                  34,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('Speelronde ${index + 1}'),
                  ),
                ),
                onChanged: (value) {
                  _geselecteerdeSpeelronde = value!;
                  _thuisControllers.clear();
                  _uitControllers.clear();
                  _laadWedstrijden();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _matchesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Fout: ${snapshot.error}'));
                }

                final matches = snapshot.data?.docs;
                if (matches == null || matches.isEmpty) {
                  return const Center(child: Text('Geen wedstrijden gevonden.'));
                }

                return ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    final docId = match.id;
                    final data = match.data() as Map<String, dynamic>;

                    final thuisteam = data['thuisteam'] ?? '[onbekend]';
                    final uitteam = data['uitteam'] ?? '[onbekend]';

                    final thuisScore = data['uitslagThuis']?.toString() ?? '';
                    final uitScore = data['uitslagUit']?.toString() ?? '';

                    final thuisController = _thuisControllers.putIfAbsent(
                      docId,
                      () => TextEditingController(text: thuisScore),
                    );
                    final uitController = _uitControllers.putIfAbsent(
                      docId,
                      () => TextEditingController(text: uitScore),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$thuisteam - $uitteam',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: thuisController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Thuis'),
                                    onChanged: _busy
                                        ? null
                                        : (value) async {
                                            final int? thuis =
                                                int.tryParse(value);
                                            final int? uit = int.tryParse(
                                                uitController.text);
                                            await _verwerkAutomatisch(
                                                docId, thuis, uit);
                                          },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: uitController,
                                    keyboardType: TextInputType.number,
                                    decoration:
                                        const InputDecoration(labelText: 'Uit'),
                                    onChanged: _busy
                                        ? null
                                        : (value) async {
                                            final int? thuis = int.tryParse(
                                                thuisController.text);
                                            final int? uit =
                                                int.tryParse(value);
                                            await _verwerkAutomatisch(
                                                docId, thuis, uit);
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
