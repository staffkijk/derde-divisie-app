import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/models/poule_prediction_scope.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/voorspellen/prediction_overview_screen.dart';
import 'package:derde_divisie/features/voorspellen/voorspel_een_team_screen.dart';
import 'edit_poule_screen.dart';

class PouleDetailScreen extends StatefulWidget {
  const PouleDetailScreen({super.key, required this.pouleId});

  final String pouleId;

  @override
  State<PouleDetailScreen> createState() => _PouleDetailScreenState();
}

class _PouleDetailScreenState extends State<PouleDetailScreen> {
  final _db = FirebaseFirestore.instance;
  final _userId = FirebaseAuth.instance.currentUser?.uid;
  Object _reloadKey = Object();

  String _type(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase();
    if (type == 'team' || type == 'one_team') return 'team';
    if (type == 'competition') return 'competition';

    final legacy = (data['competition'] ?? '').toString().toLowerCase();
    if (legacy == 'team') return 'team';
    return 'competition';
  }

  String _teamName(Map<String, dynamic> data) {
    final value = data['teamName'] ??
        data['selectedTeam'] ??
        data['team'] ??
        data['oneTeam'] ??
        data['teamCode'];
    return value?.toString().trim() ?? '';
  }

  String _division(Map<String, dynamic> data, String teamName) {
    final configured = (data['division'] ?? data['divisie'] ?? '').toString();
    if (configured.isNotEmpty) {
      return SeasonConfig.normalizeDivisionCode(configured);
    }
    return SeasonConfig.normalizeDivisionCode(
      SeasonConfig.divisionCodeForTeam(teamName),
    );
  }

  Future<void> _leave() async {
    if (_userId == null) return;
    final memberRef = _db
        .collection('poules')
        .doc(widget.pouleId)
        .collection('deelnemers')
        .doc(_userId);
    if (!(await memberRef.get()).exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Je neemt niet deel aan deze poule.')),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poule verlaten?'),
        content: const Text(
          'Je centrale voorspellingen blijven gewoon bewaard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verlaten'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final batch = _db.batch();
    batch.delete(memberRef);
    batch.delete(_db.doc('users/$_userId/poules/${widget.pouleId}'));
    batch.set(
      _db.collection('users').doc(_userId),
      {'gejoinedePoules': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
    await batch.commit();

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _join() async {
    if (_userId == null) return;
    final pouleRef = _db.collection('poules').doc(widget.pouleId);
    final memberRef = pouleRef.collection('deelnemers').doc(_userId);
    if ((await memberRef.get()).exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Je neemt al deel aan deze poule.')),
        );
      }
      return;
    }
    final batch = _db.batch();
    batch.set(memberRef, {
      'joinedAt': FieldValue.serverTimestamp(),
      'punten': 0,
      'rol': 'deelnemer',
      'voorspellingenZichtbaarVoorDeadline': false,
      'syncEnabled': true,
    });
    batch.set(
      _db.doc('users/$_userId/poules/${widget.pouleId}'),
      {'joinedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('users').doc(_userId),
      {'gejoinedePoules': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    await batch.commit();
    if (mounted) {
      setState(() => _reloadKey = Object());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je neemt nu deel aan deze poule.')),
      );
    }
  }

  Future<void> _share(String name) {
    return Share.share(
      'Doe mee met mijn poule "$name" op DerdeDiv. Poulecode: ${widget.pouleId}',
      subject: 'Uitnodiging voor $name',
    );
  }

  void _openPredictions(Map<String, dynamic> data) {
    final type = _type(data);
    final team = _teamName(data);
    if (type == 'team' && team.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VoorspelEenTeamScreen(
            team: SeasonConfig.displayNameForTeam(team),
            competition: _division(data, team),
            pouleId: widget.pouleId,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PredictionOverviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pouleRef = _db.collection('poules').doc(widget.pouleId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Poule'),
        actions: [
          IconButton(
            tooltip: 'Poule verlaten',
            onPressed: _leave,
            icon: const Icon(Icons.exit_to_app_rounded),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey(_reloadKey),
        future: pouleRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Poule niet gevonden.'));
          }

          final data = snapshot.data!.data() ?? {};
          final type = _type(data);
          final predictionScope =
              parsePoulePredictionScope(data['predictionScope']);
          final teamName = _teamName(data);
          final isOwner = data['ownerId'] == _userId;
          final explanation = type == 'team'
              ? 'Deze poule telt alleen wedstrijden mee van het gekozen team. Voorspellen doe je via Team voorspellen.'
              : 'Deze poule gebruikt je algemene voorspellingen.';

          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListView(
                    padding:
                        EdgeInsets.all(constraints.maxWidth < 600 ? 14 : 24),
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (data['name'] ?? 'Naam onbekend')
                                        .toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF153B2A),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (isOwner)
                                  IconButton(
                                    tooltip: 'Poule bewerken',
                                    onPressed: () async {
                                      final changed =
                                          await Navigator.of(context)
                                              .push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => EditPouleScreen(
                                            pouleId: widget.pouleId,
                                          ),
                                        ),
                                      );
                                      if (changed == true && mounted) {
                                        setState(() => _reloadKey = Object());
                                      }
                                    },
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                            if ((data['description'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(data['description'].toString()),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: Icon(
                                    type == 'team'
                                        ? Icons.shield_outlined
                                        : Icons.public_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    type == 'team'
                                        ? 'Teampoule'
                                        : 'Hele competitie',
                                  ),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.tune_outlined,
                                    size: 18,
                                  ),
                                  label: Text(predictionScope.label),
                                ),
                                Chip(
                                  avatar: Icon(
                                    data['isPublic'] == false
                                        ? Icons.lock_outline
                                        : Icons.public,
                                    size: 18,
                                  ),
                                  label: Text(
                                    data['isPublic'] == false
                                        ? 'Privé'
                                        : 'Openbaar',
                                  ),
                                ),
                                if (type == 'team' && teamName.isNotEmpty)
                                  Chip(
                                    label: Text(
                                      SeasonConfig.displayNameForTeam(teamName),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$explanation ${predictionScope.explanation}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _openPredictions(data),
                                  icon:
                                      const Icon(Icons.edit_calendar_outlined),
                                  label: Text(
                                    type == 'team'
                                        ? 'Team voorspellen'
                                        : 'Voorspellen',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _share(
                                    (data['name'] ?? 'Poule').toString(),
                                  ),
                                  icon: const Icon(Icons.share_outlined),
                                  label: const Text('Uitnodigen'),
                                ),
                                if (!isOwner && data['isPublic'] != false)
                                  OutlinedButton.icon(
                                    onPressed: _join,
                                    icon: const Icon(Icons.group_add_outlined),
                                    label: const Text('Deelnemen'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Ranglijst',
                        style: TextStyle(
                          color: Color(0xFF153B2A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ParticipantsRanking(
                        pouleRef: pouleRef,
                        type: type,
                        teamName: teamName,
                        usesCentralPredictions: data['type'] == 'competition' ||
                            data['type'] == 'team',
                      ),
                    ],
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

class _ParticipantsRanking extends StatelessWidget {
  const _ParticipantsRanking({
    required this.pouleRef,
    required this.type,
    required this.teamName,
    required this.usesCentralPredictions,
  });

  final DocumentReference<Map<String, dynamic>> pouleRef;
  final String type;
  final String teamName;
  final bool usesCentralPredictions;

  Future<List<_ParticipantScore>> _loadScores() async {
    final participantsSnapshot = await pouleRef.collection('deelnemers').get();
    final scores = <_ParticipantScore>[];
    final teamMatchIds =
        type == 'team' ? await _teamMatchIds(teamName) : const <String>{};

    for (final participant in participantsSnapshot.docs) {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(participant.id)
          .get();
      final username =
          (userSnapshot.data()?['username'] ?? 'Deelnemer').toString();
      int points;

      if (!usesCentralPredictions) {
        points = (participant.data()['punten'] as num?)?.toInt() ?? 0;
      } else if (type == 'competition') {
        points = (userSnapshot.data()?['totalen'] as num?)?.toInt() ?? 0;
      } else {
        final predictions = await FirebaseFirestore.instance
            .collection('voorspellingen')
            .where('gebruikerId', isEqualTo: participant.id)
            .get();
        points = predictions.docs.where((doc) {
          final data = doc.data();
          final matchId =
              (data['wedstrijdId'] ?? data['matchId'] ?? '').toString();
          return teamMatchIds.contains(matchId);
        }).fold<int>(
          0,
          (total, doc) =>
              total + ((doc.data()['punten'] as num?)?.toInt() ?? 0),
        );
      }

      scores.add(
        _ParticipantScore(
          username: username,
          points: points,
        ),
      );
    }

    scores.sort((a, b) {
      final points = b.points.compareTo(a.points);
      return points != 0 ? points : a.username.compareTo(b.username);
    });
    return scores;
  }

  Future<Set<String>> _teamMatchIds(String team) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await SeasonPaths.currentSeasonMatches.get();
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance.collection('matches').get();
      }
    } on FirebaseException {
      snapshot = await FirebaseFirestore.instance.collection('matches').get();
    }

    final selectedTeam = SeasonConfig.normalizeTeamKey(team);
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final home =
          (data['homeTeam'] ?? data['thuisTeam'] ?? data['thuisteam'] ?? '')
              .toString();
      final away =
          (data['awayTeam'] ?? data['uitTeam'] ?? data['uitteam'] ?? '')
              .toString();
      return SeasonConfig.normalizeTeamKey(home) == selectedTeam ||
          SeasonConfig.normalizeTeamKey(away) == selectedTeam ||
          SeasonConfig.teamByName(home)?.id ==
              SeasonConfig.teamByName(team)?.id ||
          SeasonConfig.teamByName(away)?.id ==
              SeasonConfig.teamByName(team)?.id;
    }).map((doc) {
      final data = doc.data();
      return (data['matchId'] ?? data['wedstrijdId'] ?? doc.id).toString();
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ParticipantScore>>(
      future: _loadScores(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final participants = snapshot.data!;
        if (participants.isEmpty) {
          return const Text('Nog geen deelnemers.');
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var index = 0; index < participants.length; index++)
                _ParticipantRow(
                  rank: index + 1,
                  username: participants[index].username,
                  points: participants[index].points,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.rank,
    required this.username,
    required this.points,
  });

  final int rank;
  final String username;
  final int points;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text(username),
      trailing: Text(
        '$points pt',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ParticipantScore {
  const _ParticipantScore({
    required this.username,
    required this.points,
  });

  final String username;
  final int points;
}
