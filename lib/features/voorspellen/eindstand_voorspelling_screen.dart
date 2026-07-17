import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';

class EindstandVoorspellingScreen extends StatefulWidget {
  const EindstandVoorspellingScreen({
    super.key,
    required this.divisie,
  });

  final String divisie;

  @override
  State<EindstandVoorspellingScreen> createState() =>
      _EindstandVoorspellingScreenState();
}

class _EindstandVoorspellingScreenState
    extends State<EindstandVoorspellingScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<String> _clubs = [];
  bool _loading = true;
  bool _saving = false;
  int _points = 0;
  late DateTime _deadline;
  _SaveStatus _saveStatus = _SaveStatus.idle;

  bool get _locked => DateTime.now().isAfter(_deadline);

  @override
  void initState() {
    super.initState();
    _deadline = DateTime(2026, 8, 31, 23, 59);
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final teamSnapshot = await SeasonPaths.currentSeasonTeams.get();
      final configuredTeams = teamSnapshot.docs
          .where((doc) {
            if (doc.id == '_meta') return false;
            final data = doc.data();
            final division =
                (data['division'] ?? data['divisie'] ?? '').toString();
            return SeasonConfig.normalizeDivisionCode(division) ==
                widget.divisie;
          })
          .map((doc) {
            final data = doc.data();
            final name =
                (data['teamName'] ?? data['name'] ?? data['team'] ?? doc.id)
                    .toString();
            return SeasonConfig.displayNameForTeam(name);
          })
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final prediction = await _db
          .collection('eindstand_voorspellingen')
          .doc('${user.uid}_${widget.divisie}')
          .get();
      final data = prediction.data();
      final belongsToCurrentSeason =
          data?['seasonId']?.toString() == SeasonConfig.activeSeasonId;
      final saved = belongsToCurrentSeason && data?['voorspelling'] is List
          ? List<String>.from(data!['voorspelling'])
          : <String>[];
      final validSaved = saved.length == configuredTeams.length &&
          saved.toSet().containsAll(configuredTeams);

      if (!mounted) return;
      setState(() {
        _clubs = validSaved ? saved : configuredTeams;
        _points = belongsToCurrentSeason
            ? ((data?['punten'] as num?)?.toInt() ?? 0)
            : 0;
        _loading = false;
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _clubs = [];
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final user = _auth.currentUser;
    if (user == null || _locked) return;

    setState(() {
      _saving = true;
      _saveStatus = _SaveStatus.saving;
    });

    try {
      await _db
          .collection('eindstand_voorspellingen')
          .doc('${user.uid}_${widget.divisie}')
          .set({
        'gebruikerId': user.uid,
        'divisie': widget.divisie,
        'seasonId': SeasonConfig.activeSeasonId,
        'voorspelling': _clubs,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveStatus = _SaveStatus.saved;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveStatus = _SaveStatus.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Eindstand voorspellen - Divisie ${widget.divisie}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clubs.isEmpty
              ? const _MissingDivisionState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Column(
                          children: [
                            _StatusBar(
                              locked: _locked,
                              points: _points,
                              saveStatus: _saveStatus,
                              saving: _saving,
                              onRetry: _save,
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                padding: EdgeInsets.all(
                                  constraints.maxWidth < 600 ? 10 : 18,
                                ),
                                buildDefaultDragHandles: false,
                                itemCount: _clubs.length,
                                onReorder: (oldIndex, newIndex) async {
                                  if (_locked || _saving) return;
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex--;
                                    final club = _clubs.removeAt(oldIndex);
                                    _clubs.insert(newIndex, club);
                                  });
                                  await _save();
                                },
                                itemBuilder: (context, index) {
                                  final club = _clubs[index];
                                  return _ClubRow(
                                    key: ValueKey(club),
                                    index: index,
                                    club: club,
                                    locked: _locked,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

enum _SaveStatus { idle, saving, saved, failed }

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.locked,
    required this.points,
    required this.saveStatus,
    required this.saving,
    required this.onRetry,
  });

  final bool locked;
  final int points;
  final _SaveStatus saveStatus;
  final bool saving;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: locked ? const Color(0xFFFFCC80) : const Color(0xFFC8E6C9),
        ),
      ),
      child: Row(
        children: [
          Icon(locked ? Icons.lock_outline : Icons.lock_open_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              locked ? 'Vergrendeld' : 'Open tot en met 31 augustus 2026',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (points > 0) Text('$points punten'),
          if (!locked) ...[
            const SizedBox(width: 12),
            _SaveStatusIndicator(
              status: saveStatus,
              saving: saving,
              onRetry: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _SaveStatusIndicator extends StatelessWidget {
  const _SaveStatusIndicator({
    required this.status,
    required this.saving,
    required this.onRetry,
  });

  final _SaveStatus status;
  final bool saving;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _SaveStatus.saving:
        return const Text(
          'Opslaan...',
          style: TextStyle(fontWeight: FontWeight.w800),
        );
      case _SaveStatus.saved:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
            SizedBox(width: 4),
            Text('Opgeslagen', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        );
      case _SaveStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Niet opgeslagen',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextButton(
              onPressed: saving ? null : onRetry,
              child: const Text('Opnieuw proberen'),
            ),
          ],
        );
      case _SaveStatus.idle:
        return const Text(
          'Sleep clubs om je voorspelling op te slaan',
          style: TextStyle(color: Colors.black54),
        );
    }
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({
    super.key,
    required this.index,
    required this.club,
    required this.locked,
  });

  final int index;
  final String club;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${index + 1}.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Image.asset(
            SeasonConfig.logoPathForTeam(club),
            width: 34,
            height: 34,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.shield_outlined, size: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              club,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (!locked)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle_rounded),
              ),
            )
          else
            const Icon(Icons.lock_outline, size: 20),
        ],
      ),
    );
  }
}

class _MissingDivisionState extends StatelessWidget {
  const _MissingDivisionState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'De definitieve indeling is nog niet bekend. Je kunt deze voorspelling later invullen zodra de indeling beschikbaar is.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
        ),
      ),
    );
  }
}
