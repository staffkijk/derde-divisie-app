import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// helpers
import 'package:derde_divisie/utils/team_code_mapping.dart';
import 'package:derde_divisie/helpers/sync_service.dart';

// schermen
import 'package:derde_divisie/features/voorspellen/voorspel_een_team_screen.dart';
import 'wedstrijden_poule_dda_screen.dart';
import 'wedstrijden_poule_ddb_screen.dart';
import 'package:derde_divisie/features/profiel/bekijk_profiel_screen.dart';
import 'poule_voorspellingen_screen.dart';
import 'edit_poule_screen.dart';

class PouleDetailScreen extends StatefulWidget {
  final String pouleId;

  const PouleDetailScreen({super.key, required this.pouleId});

  @override
  State<PouleDetailScreen> createState() => _PouleDetailScreenState();
}

class _PouleDetailScreenState extends State<PouleDetailScreen> {
  late String userId;
  bool voorspellingenZichtbaar = false;

  // force refresh na edit
  Object _reloadKey = Object();

  // toggle-guard
  bool _syncBusy = false;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    _loadZichtbaarheid();
  }

  Future<void> _loadZichtbaarheid() async {
    final doc = await FirebaseFirestore.instance
        .collection('poules')
        .doc(widget.pouleId)
        .collection('deelnemers')
        .doc(userId)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        voorspellingenZichtbaar =
            doc.data()?['voorspellingenZichtbaar'] ?? false;
      });
    }
  }

  Future<void> _toggleZichtbaarheid(bool value) async {
    setState(() => voorspellingenZichtbaar = value);
    await FirebaseFirestore.instance
        .collection('poules')
        .doc(widget.pouleId)
        .collection('deelnemers')
        .doc(userId)
        .set({'voorspellingenZichtbaar': value}, SetOptions(merge: true));
  }

  Future<bool> _isOwner() async {
    final snap = await FirebaseFirestore.instance
        .collection('poules')
        .doc(widget.pouleId)
        .get();
    return snap.exists && (snap.data()?['ownerId'] == userId);
  }

  Future<void> _leavePoule() async {
    final isOwner = await _isOwner();
    if (isOwner && mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Kan poule niet verlaten'),
          content: const Text(
              'Je bent de eigenaar van deze poule. Verwijder de poule of draag het eigenaarschap over in “Poule bewerken”.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Poule verlaten'),
        content: const Text(
          'Weet je zeker dat je deze poule wilt verlaten? Je verdwijnt uit de ranglijst. '
          'Je poule-voorspellingen voor deze poule worden verwijderd.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Verlaten')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 1) Verwijder deelnemer-doc
      await FirebaseFirestore.instance
          .collection('poules')
          .doc(widget.pouleId)
          .collection('deelnemers')
          .doc(userId)
          .delete();

      // 2) Opruimen voorspellingen die aan deze poule hangen
      Future<void> deleteAll(String coll, List<String> userFields) async {
        for (final userField in userFields) {
          final q = await FirebaseFirestore.instance
              .collection(coll)
              .where('pouleId', isEqualTo: widget.pouleId)
              .where(userField, isEqualTo: userId)
              .get();
          for (final doc in q.docs) {
            await doc.reference.delete();
          }
        }
      }

      await deleteAll('poule_predictions', ['userId', 'gebruikerId']);
      await deleteAll('poule_voorspellingen', ['userId', 'gebruikerId']);
      await deleteAll('predictions', ['userId', 'gebruikerId']); // 1-team

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je hebt de poule verlaten.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kon poule niet verlaten: $e')),
      );
    }
  }

  // ----------------- SYNC -----------------

  Future<void> _handleSyncToggle({
    required bool enable,
    required DocumentReference<Map<String, dynamic>> deelnemerRef,
  }) async {
    if (_syncBusy) return;

    try {
      setState(() => _syncBusy = true);

      if (enable) {
        await deelnemerRef.set({
          'syncEnabled': true,
          'syncStartAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Synchronisatie aangezet — open rondes worden gevuld.')),
          );
        }

        await SyncService.instance.enableSyncForUserInPool(
          poolId: widget.pouleId,
          userId: userId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Synchronisatie gereed voor open rondes. Afgesloten rondes bleven ongewijzigd.'),
            ),
          );
        }
      } else {
        await deelnemerRef.set({
          'syncEnabled': false,
          'syncStartAt': null,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Synchronisatie uitgeschakeld.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synchronisatie mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Widget _buildSyncToggle() {
    final deelnemerRef = FirebaseFirestore.instance
        .collection('poules')
        .doc(widget.pouleId)
        .collection('deelnemers')
        .doc(userId);

    return StreamBuilder<DocumentSnapshot>(
      stream: deelnemerRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? <String, dynamic>{};
        final syncEnabled = data['syncEnabled'] ?? false;

        return SwitchListTile(
          title: const Text('Synchroniseer voorspellingen'),
          subtitle: Text(
            syncEnabled
                ? 'Jouw voorspellingen worden gelijkgezet met je globale voorspellingen'
                : 'Je voorspelt los in deze poule',
          ),
          value: syncEnabled,
          onChanged: _syncBusy
              ? null
              : (val) =>
                  _handleSyncToggle(enable: val, deelnemerRef: deelnemerRef),
          secondary: _syncBusy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        );
      },
    );
  }

  // ----------------- HELPERS -----------------

  String _normalizeCompetition(Map<String, dynamic> data) {
    // 1) direct veld 'competition'
    final c = (data['competition'] ?? '').toString().toLowerCase();
    if (c == 'dda' || c == 'ddb' || c == 'team') return c;

    // 2) 'type' zoals "ONE_TEAM", "DDA", "DDB"
    final t = (data['type'] ?? '').toString().toUpperCase();
    if (t == 'DDA') return 'dda';
    if (t == 'DDB') return 'ddb';
    if (t == 'ONE_TEAM' || t == 'TEAM') return 'team';

    // 3) eventuele codes "3A" / "3B"
    final code = (data['competitionCode'] ?? data['divisie'] ?? '')
        .toString()
        .toUpperCase();
    if (code == '3A' || code == 'DDA') return 'dda';
    if (code == '3B' || code == 'DDB') return 'ddb';

    return 'onbekend';
  }

  String _beschrijfCompetitie(String norm, String team) {
    switch (norm) {
      case 'dda':
        return 'Derde Divisie A';
      case 'ddb':
        return 'Derde Divisie B';
      case 'team':
        return team.isNotEmpty ? 'Eén team: $team' : 'Eén team';
      default:
        return 'Onbekend';
    }
  }

  String _bepaalDivisieOpBasisVanTeam(String team) {
    final mappedTeam = teamCodeMapping[team] ?? team;

    const List<String> teamsDDA = [
      'DOVO',
      'Eemdijk',
      'Scherpenzeel',
      'Staphorst',
      'DVS33Ermelo',
      'SpartaNijkerk',
      'TEC',
      'Urk',
      'Hoogeveen',
      'HSC21',
      'Sportlust46',
      'Excelsior31',
      'Hercules',
      'SCGenemuiden',
      'Huizen',
      'HarkemaseBoys',
      'RohdaRaalte',
      'ADO20'
    ];

    const List<String> teamsDDB = [
      'Noordwijk',
      'Scheveningen',
      'SteDoCo',
      'Zwaluwen',
      'Kloetinge',
      'RBC',
      'GroeneSter',
      'Rijnvogels',
      'UNA',
      'ASWH',
      'UDI19',
      'TOGB',
      'FCLisse',
      'Gemert',
      'svMeerssen',
      'BlauwGeel38JUMBO',
      'Goes',
      'VVSB'
    ];

    if (teamsDDA.contains(mappedTeam)) return 'dda';
    if (teamsDDB.contains(mappedTeam)) return 'ddb';
    return 'onbekend';
  }

  String _leesTeamNaam(Map<String, dynamic> data) {
    // Ondersteun meerdere veldnamen; 'teamCode' is nu toegevoegd.
    final raw = (data['selectedTeam'] ??
            data['team'] ??
            data['oneTeam'] ??
            data['teamName'] ??
            data['team_code'] ??
            data['teamCode'])
        ?.toString()
        .trim();

    return raw ?? '';
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poule details'),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('poules')
                .doc(widget.pouleId)
                .get(),
            builder: (context, snapshot) {
              final isOwner = snapshot.hasData &&
                  snapshot.data!.exists &&
                  (snapshot.data!.get('ownerId') == userId);

              return Row(
                children: [
                  if (isOwner)
                    IconButton(
                      tooltip: 'Poule bewerken',
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final changed =
                            await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                EditPouleScreen(pouleId: widget.pouleId),
                          ),
                        );
                        if (changed == true && mounted) {
                          setState(() => _reloadKey = Object());
                        }
                      },
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'leave') _leavePoule();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, size: 20),
                            SizedBox(width: 8),
                            Text('Poule verlaten'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        key: ValueKey(_reloadKey),
        future: FirebaseFirestore.instance
            .collection('poules')
            .doc(widget.pouleId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Poule niet gevonden.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final competition = _normalizeCompetition(data);
          final String team = _leesTeamNaam(data);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Naam onbekend',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  data['description'] ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Text(
                  'Competitie: ${_beschrijfCompetitie(competition, team)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                // zichtbaarheid
                SwitchListTile(
                  title: const Text('Voorspellingen delen'),
                  subtitle: const Text(
                      'Sta toe dat anderen jouw voorspellingen in deze poule zien.'),
                  value: voorspellingenZichtbaar,
                  onChanged: _toggleZichtbaarheid,
                ),
                const SizedBox(height: 8),

                // sync
                _buildSyncToggle(),

                const SizedBox(height: 16),
                const Text('Ranglijst deelnemers:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('poules')
                        .doc(widget.pouleId)
                        .collection('deelnemers')
                        .orderBy('punten', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final deelnemers = snapshot.data?.docs ?? [];
                      if (deelnemers.isEmpty) {
                        return const Text('Nog geen deelnemers.');
                      }

                      return ListView.builder(
                        itemCount: deelnemers.length,
                        itemBuilder: (context, index) {
                          final doc = deelnemers[index];
                          final d =
                              doc.data() as Map<String, dynamic>;
                          final punten = d['punten'] ?? 0;

                          String? medaille;
                          if (index == 0) {
                            medaille = '🥇';
                          } else if (index == 1) {
                            medaille = '🥈';
                          } else if (index == 2) {
                            medaille = '🥉';
                          }

                          final isCurrentUser = doc.id == userId;

                          return _DeelnemerTile(
                            pouleId: widget.pouleId,
                            deelnemerUserId: doc.id,
                            punten: punten,
                            isCurrentUser: isCurrentUser,
                            medaille: medaille,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // VOORSPELLEN-knop
                ElevatedButton.icon(
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('Voorspellen'),
                  onPressed: () {
                    if (competition == 'dda') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WedstrijdenPouleDdaScreen(
                            divisie: 'A',
                            pouleId: widget.pouleId,
                          ),
                        ),
                      );
                      return;
                    }
                    if (competition == 'ddb') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WedstrijdenPouleDdbScreen(
                            divisie: 'B',
                            pouleId: widget.pouleId,
                          ),
                        ),
                      );
                      return;
                    }

                    if (competition == 'team') {
                      if (team.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Geen team ingesteld voor deze poule. Ga naar “Poule bewerken” om een team te kiezen.',
                            ),
                          ),
                        );
                        return;
                      }

                      final echteDivisie =
                          _bepaalDivisieOpBasisVanTeam(team);
                      if (echteDivisie == 'onbekend') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Kan divisie niet bepalen voor $team. Controleer de teamnaam in “Poule bewerken”.'),
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VoorspelEenTeamScreen(
                            team: team,
                            competition: echteDivisie,
                            pouleId: widget.pouleId,
                          ),
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Onbekende competitie-configuratie: $competition')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ----------------- Lijsttegel deelnemer -----------------

class _DeelnemerTile extends StatefulWidget {
  final String pouleId;
  final String deelnemerUserId;
  final int punten;
  final bool isCurrentUser;
  final String? medaille;

  const _DeelnemerTile({
    required this.pouleId,
    required this.deelnemerUserId,
    required this.punten,
    required this.isCurrentUser,
    required this.medaille,
  });

  @override
  State<_DeelnemerTile> createState() => _DeelnemerTileState();
}

class _DeelnemerTileState extends State<_DeelnemerTile> {
  String? _lastSetName;
  String? _lastSetAvatar;
  bool _syncInProgress = false;

  Future<void> _syncIfNeeded(String username, String avatarUrl) async {
    if (_syncInProgress) return;
    if (_lastSetName == username && _lastSetAvatar == avatarUrl) return;

    _syncInProgress = true;
    try {
      final ref = FirebaseFirestore.instance
          .collection('poules')
          .doc(widget.pouleId)
          .collection('deelnemers')
          .doc(widget.deelnemerUserId);

      final snap = await ref.get();
      final currentName = (snap.data()?['username'] ?? '') as String;
      final currentAvatar = (snap.data()?['avatarUrl'] ?? '') as String;

      final mustUpdate =
          currentName != username || currentAvatar != avatarUrl;

      if (mustUpdate) {
        await ref.set(
          {'username': username, 'avatarUrl': avatarUrl},
          SetOptions(merge: true),
        );
      }

      _lastSetName = username;
      _lastSetAvatar = avatarUrl;
    } catch (_) {
      // fail silent
    } finally {
      _syncInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.deelnemerUserId)
          .snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data();
        final avatarUrl = (userData?['avatarUrl'] ?? '').toString();
        final username = (userData?['username'] ?? 'Gebruiker').toString();

        if (userData != null) {
          Future.microtask(() => _syncIfNeeded(username, avatarUrl));
        }

        return ListTile(
          leading: GestureDetector(
            onTap: () async {
              final selected =
                  await showModalBottomSheet<String>(
                context: context,
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Bekijk profiel'),
                      onTap: () => Navigator.pop(context, 'profiel'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.visibility),
                      title: const Text('Bekijk voorspellingen'),
                      onTap: () => Navigator.pop(context, 'voorspellingen'),
                    ),
                  ],
                ),
              );

              if (!context.mounted) return;

              if (selected == 'profiel') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BekijkProfielScreen(userId: widget.deelnemerUserId),
                  ),
                );
              } else if (selected == 'voorspellingen') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PouleVoorspellingenScreen(
                      pouleId: widget.pouleId,
                      userId: widget.deelnemerUserId,
                    ),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 20,
              backgroundImage:
                  (avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
          ),
          title: Text('$username${widget.isCurrentUser ? " (jij)" : ""}'),
          subtitle: Text('Punten: ${widget.punten}'),
          trailing: widget.medaille != null
              ? Text(widget.medaille!, style: const TextStyle(fontSize: 20))
              : null,
        );
      },
    );
  }
}
