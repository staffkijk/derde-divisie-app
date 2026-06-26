import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:derde_divisie/data/config/season_config.dart';

class VoorspelEenTeamScreen extends StatefulWidget {
  final String team; // bv. "Noordwijk"
  final String competition; // bv. "DDA" / "DDB" / "Derde Divisie A"
  final String pouleId;

  const VoorspelEenTeamScreen({
    super.key,
    required this.team,
    required this.competition,
    required this.pouleId,
  });

  @override
  State<VoorspelEenTeamScreen> createState() => _VoorspelEenTeamScreenState();
}

class _VoorspelEenTeamScreenState extends State<VoorspelEenTeamScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // Sync status van deelnemer in deze poule
  bool _syncEnabled = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deelnemerSub;

  // ---- LOGO-MAP: keys = genormaliseerde teamcode (lowercase, zonder spaties/'/ /) ----

  // Controllers en caches per wedstrijd (key = matchId)
  final Map<String, TextEditingController> _homeCtrls = {};
  final Map<String, TextEditingController> _awayCtrls = {};
  final Map<String, int?> _points = {};
  final Map<String, int?> _resHome = {};
  final Map<String, int?> _resAway = {};
  final Map<String, DateTime> _matchDate = {};

  @override
  void initState() {
    super.initState();
    _listenDeelnemerSyncStatus();
  }

  @override
  void dispose() {
    _deelnemerSub?.cancel();
    for (final c in _homeCtrls.values) {
      c.dispose();
    }
    for (final c in _awayCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Helpers ----------

  void _listenDeelnemerSyncStatus() {
    _deelnemerSub?.cancel();
    _deelnemerSub = FirebaseFirestore.instance
        .collection('poules')
        .doc(widget.pouleId)
        .collection('deelnemers')
        .doc(userId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final enabled = (data?['syncEnabled'] == true);
      if (enabled != _syncEnabled && mounted) {
        setState(() => _syncEnabled = enabled);
      }
    });
  }

  DateTime _parseDatum(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  String _mapCompetition(String code) {
    switch (code.toLowerCase()) {
      case 'dda':
        return 'Derde Divisie A';
      case 'ddb':
        return 'Derde Divisie B';
      default:
        return code;
    }
  }

  // Zelfde normalisatie als in matches.homeTeamCode/awayTeamCode
  String _normCode(String s) => s
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll("'", '')
      .replaceAll('/', '')
      .replaceAll('.', '')
      .replaceAll('-', '');

  bool _validScore(String s) {
    final n = int.tryParse(s);
    return n != null && n >= 0 && n <= 19;
  }

  String _logoPath(String clubNaam) {
    return SeasonConfig.logoPathForTeam(clubNaam);
  }

  // ---------- Save ----------

  Future<void> _save(String matchId) async {
    final home = _homeCtrls[matchId]?.text ?? '';
    final away = _awayCtrls[matchId]?.text ?? '';
    if (!_validScore(home) || !_validScore(away)) return;

    // Per-wedstrijd locking: 12:00 op wedstrijddag
    final d = _matchDate[matchId];
    if (d != null) {
      final deadline = DateTime(d.year, d.month, d.day, 12);
      final locked = DateTime.now().isAfter(deadline);
      if (_syncEnabled || locked) return; // blokkeer bij sync of na deadline
    }

    await FirebaseFirestore.instance
        .collection('predictions')
        .doc('${userId}_${matchId}_${widget.pouleId}')
        .set({
      'pouleId': widget.pouleId,
      'gebruikerId': userId,
      'matchId': matchId,
      'wedstrijdId': matchId, // compat
      'scoreThuis': int.parse(home),
      'scoreUit': int.parse(away),
      'syncedFromGeneral': false, // expliciet handmatig
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Streams ----------

  Stream<QuerySnapshot<Map<String, dynamic>>> _homeMatchesStream() {
    final comp = _mapCompetition(widget.competition);
    final teamCode = _normCode(widget.team);

    return FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: comp)
        .where('homeTeamCode', isEqualTo: teamCode)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _awayMatchesStream() {
    final comp = _mapCompetition(widget.competition);
    final teamCode = _normCode(widget.team);

    return FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: comp)
        .where('awayTeamCode', isEqualTo: teamCode)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _predictionsStream() {
    return FirebaseFirestore.instance
        .collection('predictions')
        .where('gebruikerId', isEqualTo: userId)
        .where('pouleId', isEqualTo: widget.pouleId)
        .snapshots();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voorspel ${widget.team}')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _homeMatchesStream(),
        builder: (context, homeSnap) {
          if (homeSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _awayMatchesStream(),
            builder: (context, awaySnap) {
              if (awaySnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> combined =
                  [];
              if (homeSnap.hasData) combined.addAll(homeSnap.data!.docs);
              if (awaySnap.hasData) combined.addAll(awaySnap.data!.docs);

              if (combined.isEmpty) {
                return const Center(
                    child: Text('Geen wedstrijden gevonden voor dit team.'));
              }

              final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
                  byId = {for (final d in combined) d.id: d};
              final matches = byId.values.toList();

              matches.sort((a, b) {
                final aData = a.data();
                final bData = b.data();
                final ad = _parseDatum(aData['datum'] ?? aData['timestamp']);
                final bd = _parseDatum(bData['datum'] ?? bData['timestamp']);
                return ad.compareTo(bd);
              });

              for (final d in matches) {
                final id = d.id;
                final data = d.data();
                _matchDate[id] =
                    _parseDatum(data['datum'] ?? data['timestamp']);
                _resHome[id] = data['uitslagThuis'];
                _resAway[id] = data['uitslagUit'];

                _homeCtrls.putIfAbsent(id, () => TextEditingController());
                _awayCtrls.putIfAbsent(id, () => TextEditingController());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _predictionsStream(),
                builder: (context, predSnap) {
                  if (predSnap.hasData) {
                    for (final doc in predSnap.data!.docs) {
                      final data = doc.data();
                      final matchId =
                          (data['matchId'] ?? data['wedstrijdId'])?.toString();
                      if (matchId == null) continue;

                      final existingHome = data['scoreThuis']?.toString() ?? '';
                      final existingAway = data['scoreUit']?.toString() ?? '';
                      _points[matchId] = data['punten'];

                      final hc = _homeCtrls[matchId];
                      final ac = _awayCtrls[matchId];
                      if (hc != null && hc.text != existingHome) {
                        hc.text = existingHome;
                      }
                      if (ac != null && ac.text != existingAway) {
                        ac.text = existingAway;
                      }
                    }
                  }

                  return Column(
                    children: [
                      if (_syncEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Card(
                            color: Colors.blue.shade50,
                            child: const ListTile(
                              leading: Icon(Icons.sync, color: Colors.blue),
                              title: Text('Synchronisatie is ingeschakeld'),
                              subtitle: Text(
                                'Je voorspellingen volgen je algemene voorspellingen (tot de deadline). '
                                'Wil je hier handmatig voorspellen? Zet synchronisatie uit op het pouledetail-scherm.',
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (context, i) {
                            final m = matches[i];
                            final data = m.data();
                            final id = m.id;

                            final date = _matchDate[id]!;
                            final deadline =
                                DateTime(date.year, date.month, date.day, 12);
                            final locked = DateTime.now().isAfter(deadline);

                            final speelronde =
                                data['speelronde']?.toString() ?? '';
                            final homeName = data['thuisteam'] ?? '';
                            final awayName = data['uitteam'] ?? '';

                            final hasResult =
                                _resHome[id] != null && _resAway[id] != null;

                            final ownHome =
                                int.tryParse(_homeCtrls[id]?.text ?? '');
                            final ownAway =
                                int.tryParse(_awayCtrls[id]?.text ?? '');
                            final haveOwnPrediction =
                                ownHome != null && ownAway != null;

                            final inputsDisabled = _syncEnabled || locked;

                            return Card(
                              color: const Color(0xFFF7FAF6),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                        child: _teamColumn(
                                            homeName, _logoPath(homeName))),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          Text(
                                            'Speelronde $speelronde – ${DateFormat('d MMMM yyyy', 'nl').format(date)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _scoreField(
                                                enabled: !inputsDisabled,
                                                controller: _homeCtrls[id]!,
                                                onChanged: (_) => _save(id),
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 6),
                                                child: Text('-'),
                                              ),
                                              _scoreField(
                                                enabled: !inputsDisabled,
                                                controller: _awayCtrls[id]!,
                                                onChanged: (_) => _save(id),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (hasResult) ...[
                                            Text(
                                                'Uitslag: ${_resHome[id]} - ${_resAway[id]}'),
                                            if (_points[id] != null)
                                              Text(
                                                  'Behaalde punten: +${_points[id]}',
                                                  style: const TextStyle(
                                                      color: Colors.green)),
                                            if (haveOwnPrediction)
                                              Text(
                                                  'Jouw voorspelling: $ownHome - $ownAway',
                                                  style: const TextStyle(
                                                      color: Colors.blueGrey)),
                                          ] else if (locked &&
                                              haveOwnPrediction) ...[
                                            Text(
                                                'Jouw voorspelling: $ownHome - $ownAway',
                                                style: const TextStyle(
                                                    color: Colors.blueGrey)),
                                          ] else ...[
                                            const Text(
                                                'Uitslag nog niet bekend'),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            'Deadline: ${DateFormat('EEE d MMM, HH:mm', 'nl').format(deadline)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: locked
                                                  ? Colors.red[700]
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                        child: _teamColumn(
                                            awayName, _logoPath(awayName))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _teamColumn(String naam, String logoPath) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          logoPath,
          width: 36,
          height: 36,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.shield, size: 36),
        ),
        const SizedBox(height: 4),
        Text(naam,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _scoreField({
    required bool enabled,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 36,
      height: 38,
      child: TextField(
        enabled: enabled,
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          isDense: true,
          counterText: '',
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(),
        ),
        onChanged: (val) {
          if (!_validScore(val)) return; // alleen 0..19
          onChanged(val);
        },
      ),
    );
  }
}
