import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class VoorspelEenTeamScreen extends StatefulWidget {
  const VoorspelEenTeamScreen({
    super.key,
    required this.team,
    required this.competition,
    this.pouleId,
  });

  final String team;
  final String competition;

  /// Alleen behouden zodat oude navigatie vanuit poules backwards compatible is.
  final String? pouleId;

  @override
  State<VoorspelEenTeamScreen> createState() => _VoorspelEenTeamScreenState();
}

class _VoorspelEenTeamScreenState extends State<VoorspelEenTeamScreen> {
  final _db = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _homeControllers = {};
  final Map<String, TextEditingController> _awayControllers = {};
  late Future<List<_TeamMatch>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  @override
  void dispose() {
    for (final controller in _homeControllers.values) {
      controller.dispose();
    }
    for (final controller in _awayControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<_TeamMatch>> _loadMatches() async {
    var matches = <_TeamMatch>[];
    try {
      final seasonSnapshot = await SeasonPaths.currentSeasonMatches.get();
      matches = _parseMatches(seasonSnapshot.docs);
    } on FirebaseException {
      // De rootcollectie blijft beschikbaar tijdens de seizoensmigratie.
    }

    if (matches.isEmpty) {
      final rootSnapshot = await _db.collection('matches').get();
      matches = _parseMatches(rootSnapshot.docs);
    }

    await _loadPredictions(matches);
    return matches;
  }

  List<_TeamMatch> _parseMatches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final selectedTeam = SeasonConfig.normalizeTeamKey(widget.team);
    final division = SeasonConfig.normalizeDivisionCode(widget.competition);
    final matches = <_TeamMatch>[];

    for (final doc in docs) {
      if (doc.id == '_meta') continue;
      final data = doc.data();
      final rawDivision =
          (data['division'] ?? data['divisie'] ?? data['competitie'] ?? '')
              .toString();
      if (rawDivision.isNotEmpty &&
          SeasonConfig.normalizeDivisionCode(rawDivision) != division) {
        continue;
      }

      final home = _string(data, ['homeTeam', 'thuisTeam', 'thuisteam']);
      final away = _string(data, ['awayTeam', 'uitTeam', 'uitteam']);
      final homeCode =
          _string(data, ['homeTeamCode']).isEmpty ? home : data['homeTeamCode'];
      final awayCode =
          _string(data, ['awayTeamCode']).isEmpty ? away : data['awayTeamCode'];
      final selected = SeasonConfig.normalizeTeamKey(homeCode.toString()) ==
              selectedTeam ||
          SeasonConfig.normalizeTeamKey(awayCode.toString()) == selectedTeam ||
          SeasonConfig.teamByName(home)?.id ==
              SeasonConfig.teamByName(widget.team)?.id ||
          SeasonConfig.teamByName(away)?.id ==
              SeasonConfig.teamByName(widget.team)?.id;
      if (!selected || home.isEmpty || away.isEmpty) continue;

      final matchId = _string(data, ['matchId', 'wedstrijdId']);
      matches.add(
        _TeamMatch(
          id: matchId.isEmpty ? doc.id : matchId,
          homeTeam: SeasonConfig.displayNameForTeam(home),
          awayTeam: SeasonConfig.displayNameForTeam(away),
          round: _integer(data, ['round', 'speelronde']) ?? 0,
          date: _date(data['date'] ?? data['datum'] ?? data['startTime']),
          homeScore: _integer(
            data,
            ['homeScore', 'thuisScore', 'uitslagThuis'],
          ),
          awayScore: _integer(
            data,
            ['awayScore', 'uitScore', 'uitslagUit'],
          ),
        ),
      );
    }

    matches.sort((a, b) {
      final round = a.round.compareTo(b.round);
      if (round != 0) return round;
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return matches;
  }

  Future<void> _loadPredictions(List<_TeamMatch> matches) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || matches.isEmpty) return;

    final snapshot = await _db
        .collection('voorspellingen')
        .where('gebruikerId', isEqualTo: user.uid)
        .get();
    final ids = matches.map((match) => match.id).toSet();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final matchId = (data['wedstrijdId'] ?? data['matchId'] ?? '').toString();
      if (!ids.contains(matchId)) continue;
      _homeControllers.putIfAbsent(
        matchId,
        () => TextEditingController(text: data['scoreThuis']?.toString() ?? ''),
      );
      _awayControllers.putIfAbsent(
        matchId,
        () => TextEditingController(text: data['scoreUit']?.toString() ?? ''),
      );
    }
  }

  Future<void> _save(_TeamMatch match) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isLocked(match)) return;

    final home = int.tryParse(_homeControllers[match.id]?.text ?? '');
    final away = int.tryParse(_awayControllers[match.id]?.text ?? '');
    if (home == null || away == null || home > 19 || away > 19) return;

    await _db.collection('voorspellingen').doc('${user.uid}_${match.id}').set({
      'gebruikerId': user.uid,
      'wedstrijdId': match.id,
      'scoreThuis': home,
      'scoreUit': away,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _isLocked(_TeamMatch match) {
    final date = match.date;
    if (date == null) return false;
    return DateTime.now().isAfter(
      DateTime(date.year, date.month, date.day, 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.team} voorspellen')),
      body: FutureBuilder<List<_TeamMatch>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('De wedstrijden kunnen nu niet worden geladen.'),
            );
          }

          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Het programma voor dit team is nog niet bekend.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: ListView.separated(
                    padding:
                        EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 20),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      _homeControllers.putIfAbsent(
                        match.id,
                        TextEditingController.new,
                      );
                      _awayControllers.putIfAbsent(
                        match.id,
                        TextEditingController.new,
                      );
                      return _MatchPredictionCard(
                        match: match,
                        locked: _isLocked(match),
                        homeController: _homeControllers[match.id]!,
                        awayController: _awayControllers[match.id]!,
                        onChanged: () => _save(match),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MatchPredictionCard extends StatelessWidget {
  const _MatchPredictionCard({
    required this.match,
    required this.locked,
    required this.homeController,
    required this.awayController,
    required this.onChanged,
  });

  final _TeamMatch match;
  final bool locked;
  final TextEditingController homeController;
  final TextEditingController awayController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dateText = match.date == null
        ? 'Datum volgt'
        : DateFormat('EEE d MMM, HH:mm', 'nl').format(match.date!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: Column(
        children: [
          Text(
            'Speelronde ${match.round}  |  $dateText',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Team(team: match.homeTeam)),
              _ScoreInput(
                controller: homeController,
                enabled: !locked,
                onChanged: onChanged,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('-', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              _ScoreInput(
                controller: awayController,
                enabled: !locked,
                onChanged: onChanged,
              ),
              Expanded(child: _Team(team: match.awayTeam)),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 10),
            const Text(
              'Deze wedstrijd is vergrendeld.',
              style: TextStyle(color: Color(0xFF8A4B00), fontSize: 12),
            ),
          ],
          if (match.homeScore != null && match.awayScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'Uitslag: ${match.homeScore} - ${match.awayScore}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({required this.team});

  final String team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          SeasonConfig.logoPathForTeam(team),
          width: 40,
          height: 40,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.shield_outlined, size: 40),
        ),
        const SizedBox(height: 5),
        Text(
          team,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        decoration: const InputDecoration(counterText: ''),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _TeamMatch {
  const _TeamMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.round,
    required this.date,
    required this.homeScore,
    required this.awayScore,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final int round;
  final DateTime? date;
  final int? homeScore;
  final int? awayScore;
}

String _string(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
}

int? _integer(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
