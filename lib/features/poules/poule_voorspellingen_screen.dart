import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ===============================================================
/// Helpers voor logo-pad op basis van teamnamen
/// ===============================================================

String _sanitizeForAsset(String s) => s
    .replaceAll(RegExp(r'\(.*?\)'), '')
    .replaceAll('\u00A0', '')
    .replaceAll('’', '')
    .replaceAll("'", '')
    .replaceAll('/', '')
    .replaceAll('.', '')
    .replaceAll('-', '')
    .replaceAll(' ', '');

String _logoPathFromTeamName(dynamic rawName) {
  final name = (rawName?.toString() ?? '').trim();
  if (name.isEmpty) return 'assets/images/default_logo.png';
  final cleaned = _sanitizeForAsset(name);
  return 'assets/images/logo_$cleaned.png';
}

/// ===============================================================
/// Kleine UI widgets (logo + center kolom)
/// ===============================================================

class _TeamLogoColumn extends StatelessWidget {
  final dynamic teamDisplayName;
  const _TeamLogoColumn({required this.teamDisplayName});

  @override
  Widget build(BuildContext context) {
    final label = (teamDisplayName?.toString() ?? '').trim();
    final assetPath = _logoPathFromTeamName(label);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          assetPath,
          width: 36,
          height: 36,
          errorBuilder: (_, __, ___) =>
              Image.asset('assets/images/default_logo.png', width: 36, height: 36),
        ),
        const SizedBox(height: 6),
        Text(
          label.isEmpty ? '?' : label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PredictionCenterColumn extends StatelessWidget {
  final String prediction;
  final int? uitslagThuis;
  final int? uitslagUit;
  final int? punten;
  final bool verwerkt;

  const _PredictionCenterColumn({
    required this.prediction,
    this.uitslagThuis,
    this.uitslagUit,
    this.punten,
    required this.verwerkt,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prediction,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (verwerkt && uitslagThuis != null && uitslagUit != null)
            Text('Uitslag: $uitslagThuis - $uitslagUit',
                style: const TextStyle(fontSize: 13)),
          if (punten != null && verwerkt)
            Text('🎯 $punten pt',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// ===============================================================
/// Hoofdscherm (per SPEELRONDE zichtbaarheid, deadline = 12:00)
/// ===============================================================

class PouleVoorspellingenScreen extends StatelessWidget {
  final String pouleId;
  final String userId;

  const PouleVoorspellingenScreen({
    super.key,
    required this.pouleId,
    required this.userId,
  });

  int _roundFromMatch(Map<String, dynamic> m) {
    final r = m['speelronde'] ?? m['ronde'] ?? m['round'] ?? m['matchday'];
    if (r is int) return r;
    if (r is String) return int.tryParse(r) ?? 0;
    return 0;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Deelnemer deelt altijd? Dan is alles zichtbaar.
  Future<bool> _deelnemerDeelt() async {
    final deelnemerSnap = await FirebaseFirestore.instance
        .collection('poules')
        .doc(pouleId)
        .collection('deelnemers')
        .doc(userId)
        .get();

    if (!deelnemerSnap.exists) return false;
    final data = deelnemerSnap.data()!;
    return (data['voorspellingenZichtbaar'] ??
            data['toonVoorspellingen'] ??
            false) == true;
  }

  /// Alle voorspellingen van deze user in deze poule (uit diverse collecties)
  Future<List<Map<String, dynamic>>> _getVoorspellingen() async {
    final results = <Map<String, dynamic>>[];

    Future<void> fromCollection(String coll) async {
      for (final userField in ['gebruikerId', 'userId']) {
        final q = FirebaseFirestore.instance
            .collection(coll)
            .where('pouleId', isEqualTo: pouleId)
            .where(userField, isEqualTo: userId);
        final snap = await q.get();
        for (final d in snap.docs) {
          final m = d.data();
          final matchId = (m['matchId'] ?? m['wedstrijdId'] ?? '').toString();
          if (matchId.isEmpty) continue;

          final scoreHome =
              m['homeGoals'] ?? m['scoreThuis'] ?? m['thuis'] ?? m['home'];
          final scoreAway =
              m['awayGoals'] ?? m['scoreUit'] ?? m['uit'] ?? m['away'];

          results.add({
            'matchId': matchId,
            'voorspellingThuis': (scoreHome?.toString() ?? '-'),
            'voorspellingUit': (scoreAway?.toString() ?? '-'),
            'punten': m['punten'],
            'verwerkt': m['verwerkt'] == true,
          });
        }
      }
    }

    await fromCollection('predictions');
    await fromCollection('poule_predictions');
    await fromCollection('poule_voorspellingen');

    // Dedup op matchId
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final r in results) {
      final id = r['matchId'] as String;
      if (seen.add(id)) deduped.add(r);
    }

    deduped.sort((a, b) => (a['matchId'] as String).compareTo(b['matchId'] as String));
    return deduped;
  }

  /// Laad alle matches bij de gegeven matchIds (probeert docId, matchId, wedstrijdId)
  Future<Map<String, Map<String, dynamic>>> _getMatchesByIds(
      List<String> matchIds) async {
    final Map<String, Map<String, dynamic>> result = {};
    if (matchIds.isEmpty) return result;

    const chunk = 10;

    // 1) documentId
    for (var i = 0; i < matchIds.length; i += chunk) {
      final slice = matchIds.sublist(i, (i + chunk > matchIds.length) ? matchIds.length : i + chunk);
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where(FieldPath.documentId, whereIn: slice)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = doc.data();
      }
    }

    // 2) matchId
    final missing1 = matchIds.where((id) => !result.containsKey(id)).toList();
    for (var i = 0; i < missing1.length; i += chunk) {
      final slice = missing1.sublist(i, (i + chunk > missing1.length) ? missing1.length : i + chunk);
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('matchId', whereIn: slice)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['matchId'] ?? doc.id).toString();
        result[id] = data;
      }
    }

    // 3) wedstrijdId
    final missing2 = matchIds.where((id) => !result.containsKey(id)).toList();
    for (var i = 0; i < missing2.length; i += chunk) {
      final slice = missing2.sublist(i, (i + chunk > missing2.length) ? missing2.length : i + chunk);
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('wedstrijdId', whereIn: slice)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['wedstrijdId'] ?? data['matchId'] ?? doc.id).toString();
        result[id] = data;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voorspellingen in deze poule')),
      body: FutureBuilder<bool>(
        future: _deelnemerDeelt(),
        builder: (context, shareSnap) {
          if (!shareSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final deeltAltijd = shareSnap.data!; // true = altijd zichtbaar

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _getVoorspellingen(),
            builder: (context, predSnap) {
              if (!predSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final voorspellingen = predSnap.data!;
              if (voorspellingen.isEmpty) {
                return const Center(child: Text('Geen voorspellingen gevonden.'));
              }

              final matchIds = voorspellingen
                  .map((v) => (v['matchId'] as String))
                  .where((id) => id.isNotEmpty)
                  .toList();

              return FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _getMatchesByIds(matchIds),
                builder: (context, matchesSnap) {
                  if (!matchesSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final matches = matchesSnap.data!;

                  // === Groepeer per speelronde + bereken 1e aftrap en 12:00-deadline per ronde ===
                  final perRonde = <int, List<Map<String, dynamic>>>{};
                  final firstKickoff = <int, DateTime?>{};
                  final roundDeadline = <int, DateTime?>{};
                  int maxRound = 0;

                  for (final v in voorspellingen) {
                    final matchId = v['matchId'] as String;
                    final match = matches[matchId] ?? {};

                    final homeName = match['thuisteam'] ??
                        match['homeTeamName'] ??
                        match['homeTeam'] ??
                        match['home'] ??
                        '';
                    final awayName = match['uitteam'] ??
                        match['awayTeamName'] ??
                        match['awayTeam'] ??
                        match['away'] ??
                        '';

                    final round = _roundFromMatch(match);
                    if (round > maxRound) maxRound = round;

                    final dt = _parseDate(match['datetime']) ??
                        _parseDate(match['datum']) ??
                        _parseDate(match['date']) ??
                        _parseDate(match['kickoff']) ??
                        _parseDate(match['start']) ??
                        _parseDate(match['aftrap']);

                    final uitslagThuis = (match['uitslagThuis'] ??
                        match['homeGoals'] ??
                        match['finalHome'] ??
                        match['scoreThuis']) as int?;
                    final uitslagUit = (match['uitslagUit'] ??
                        match['awayGoals'] ??
                        match['finalAway'] ??
                        match['scoreUit']) as int?;

                    perRonde.putIfAbsent(round, () => []).add({
                      'homeName': homeName,
                      'awayName': awayName,
                      'predHome': (v['voorspellingThuis'] ?? '-').toString(),
                      'predAway': (v['voorspellingUit'] ?? '-').toString(),
                      'punten': v['punten'] as int?,
                      'verwerkt':
                          (v['verwerkt'] == true) || (uitslagThuis != null && uitslagUit != null),
                      'uitslagThuis': uitslagThuis,
                      'uitslagUit': uitslagUit,
                      'datetime': dt,
                    });

                    // earliest kickoff per round
                    if (dt != null) {
                      final cur = firstKickoff[round];
                      if (cur == null || dt.isBefore(cur)) {
                        firstKickoff[round] = dt;

                        // deadline = 12:00 op die dag
                        roundDeadline[round] = DateTime(dt.year, dt.month, dt.day, 12, 0);
                      }
                    }
                  }

                  final tabCount = (maxRound >= 1 && maxRound <= 34) ? maxRound : 34;
                  final now = DateTime.now();

                  bool roundVisible(int r) {
                    if (deeltAltijd) return true;
                    final deadline = roundDeadline[r];
                    return deadline != null && now.isAfter(deadline);
                  }

                  return DefaultTabController(
                    length: tabCount,
                    child: Column(
                      children: [
                        Material(
                          color: Theme.of(context).colorScheme.primary,
                          child: TabBar(
                            isScrollable: true,
                            indicatorColor: Colors.white,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white70,
                            tabs: List.generate(tabCount, (i) => Tab(text: 'Ronde ${i + 1}')),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: List.generate(tabCount, (i) {
                              final r = i + 1;
                              final lijst = (perRonde[r] ?? [])
                                ..sort((a, b) =>
                                    (a['homeName'] as String).compareTo(b['homeName'] as String));

                              if (lijst.isEmpty) {
                                return const Center(
                                  child: Text('Geen wedstrijden/voorspellingen in deze ronde.'),
                                );
                              }

                              final zichtbaar = roundVisible(r);
                              if (!zichtbaar) {
                                final dl = roundDeadline[r];
                                final deadlineText = (dl == null)
                                    ? 'Voorspellingen van deze ronde zijn nog afgeschermd.'
                                    : 'Voorspellingen zichtbaar na ${dl.year}-${dl.month.toString().padLeft(2, '0')}-${dl.day.toString().padLeft(2, '0')} 12:00';
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_outline, size: 40),
                                      const SizedBox(height: 10),
                                      Text(deadlineText),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: lijst.length,
                                itemBuilder: (context, index) {
                                  final it = lijst[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 4)
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: _TeamLogoColumn(
                                                  teamDisplayName: it['homeName'])),
                                          Expanded(
                                            flex: 2,
                                            child: _PredictionCenterColumn(
                                              prediction:
                                                  '${it['predHome']} - ${it['predAway']}',
                                              uitslagThuis: it['uitslagThuis'] as int?,
                                              uitslagUit: it['uitslagUit'] as int?,
                                              punten: it['punten'] as int?,
                                              verwerkt: it['verwerkt'] as bool,
                                            ),
                                          ),
                                          Expanded(
                                              child: _TeamLogoColumn(
                                                  teamDisplayName: it['awayName'])),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
