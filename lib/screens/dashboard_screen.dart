// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';

/// ---------------------------
/// Firestore veldmapping
/// ---------------------------
class MatchFieldMap {
  static const homeTeamKeys = ['thuisteam', 'homeTeam'];
  static const awayTeamKeys = ['uitteam', 'awayTeam'];
  static const homeScoreKeys = ['uitslagThuis', 'scoreThuis'];
  static const awayScoreKeys = ['uitslagUit', 'scoreUit'];
  static const divisionKeys = ['competitie'];
  static const dateKeys = ['datum'];
  static const playedFlagKeys = ['verwerkt', 'gespeeld', 'isProcessed'];
}

/// ---------------------------
/// Helpers
/// ---------------------------
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _asString(dynamic v) => v?.toString();

bool? _asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == 'yes' || s == 'ja';
  }
  return null;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

T? _firstOf<T>(
  Map<String, dynamic> data,
  List<String> keys,
  T? Function(dynamic) cast,
) {
  for (final k in keys) {
    if (data.containsKey(k)) {
      final got = cast(data[k]);
      if (got != null) return got;
    }
  }
  return null;
}

/// ---------------------------
/// Wedstrijdmodel
/// ---------------------------
class _M {
  final String? home;
  final String? away;
  final int? sh;
  final int? sa;
  final String? division;
  final bool played;
  final DateTime? date;

  const _M({
    required this.home,
    required this.away,
    required this.sh,
    required this.sa,
    required this.division,
    required this.played,
    required this.date,
  });

  int? get totalGoals => (sh != null && sa != null) ? sh! + sa! : null;
  int? get goalDiff => (sh != null && sa != null) ? (sh! - sa!).abs() : null;
}

/// ---------------------------
/// Firestore: lees `matches`
/// ---------------------------
Future<List<_M>> _loadMatchesFromFirestore() async {
  final fs = FirebaseFirestore.instance;
  final snapshot = await fs.collection('matches').get();
  if (snapshot.docs.isEmpty) return <_M>[];

  return snapshot.docs.map((doc) {
    final data = doc.data();
    final home = _firstOf<String>(data, MatchFieldMap.homeTeamKeys, _asString);
    final away = _firstOf<String>(data, MatchFieldMap.awayTeamKeys, _asString);
    final sh = _firstOf<int>(data, MatchFieldMap.homeScoreKeys, _asInt);
    final sa = _firstOf<int>(data, MatchFieldMap.awayScoreKeys, _asInt);
    final div = _firstOf<String>(data, MatchFieldMap.divisionKeys, _asString);
    final date = _firstOf<DateTime>(data, MatchFieldMap.dateKeys, _asDate);
    final flag = _firstOf<bool>(data, MatchFieldMap.playedFlagKeys, _asBool);
    final isPlayed = flag ?? (sh != null && sa != null);

    return _M(
      home: home,
      away: away,
      sh: sh,
      sa: sa,
      division: div,
      played: isPlayed,
      date: date,
    );
  }).toList();
}

/// ---------------------------
/// Statistieken berekening
/// ---------------------------
class _Stats {
  final int totalMatches;
  final int playedMatches;
  final int playedA;
  final int playedB;
  final int totalGoals;
  final int goalsA;
  final int goalsB;
  final double avgGoalsTotal;
  final double avgGoalsA;
  final double avgGoalsB;
  final List<_M> biggestWins;
  final List<_M> mostGoalsMatches;

  const _Stats({
    required this.totalMatches,
    required this.playedMatches,
    required this.playedA,
    required this.playedB,
    required this.totalGoals,
    required this.goalsA,
    required this.goalsB,
    required this.avgGoalsTotal,
    required this.avgGoalsA,
    required this.avgGoalsB,
    required this.biggestWins,
    required this.mostGoalsMatches,
  });
}

_Stats _computeStats(List<_M> ms) {
  final played = ms.where((m) => m.played && m.sh != null && m.sa != null).toList();
  final total = ms.length;

  int totalGoals = 0, goalsA = 0, goalsB = 0, playedA = 0, playedB = 0;
  int biggestDiff = -1, mostTotal = -1;
  List<_M> biggestWins = [], mostGoalsMatches = [];

  for (final m in played) {
    final tg = m.totalGoals!;
    final dif = m.goalDiff ?? -1;
    totalGoals += tg;

    final div = (m.division ?? '').toLowerCase().replaceAll(' ', '');
    if (div.contains('derdedivisiea') || div == 'a') {
      goalsA += tg;
      playedA++;
    } else if (div.contains('derdedivisieb') || div == 'b') {
      goalsB += tg;
      playedB++;
    }

    if (dif > biggestDiff) {
      biggestDiff = dif;
      biggestWins = [m];
    } else if (dif == biggestDiff && dif > 0) {
      biggestWins.add(m);
    }

    if (tg > mostTotal) {
      mostTotal = tg;
      mostGoalsMatches = [m];
    } else if (tg == mostTotal && tg > 0) {
      mostGoalsMatches.add(m);
    }
  }

  final avgGoalsTotal = played.isEmpty ? 0.0 : totalGoals / played.length;
  final avgGoalsA = playedA == 0 ? 0.0 : goalsA / playedA;
  final avgGoalsB = playedB == 0 ? 0.0 : goalsB / playedB;

  return _Stats(
    totalMatches: total,
    playedMatches: played.length,
    playedA: playedA,
    playedB: playedB,
    totalGoals: totalGoals,
    goalsA: goalsA,
    goalsB: goalsB,
    avgGoalsTotal: avgGoalsTotal,
    avgGoalsA: avgGoalsA,
    avgGoalsB: avgGoalsB,
    biggestWins: biggestWins,
    mostGoalsMatches: mostGoalsMatches,
  );
}

/// ---------------------------
/// RotatingLogo – toont alle 36 clublogo’s in willekeurige volgorde
/// ---------------------------
class RotatingLogo extends StatefulWidget {
  const RotatingLogo({super.key});

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo> {
  // Alle 36 clublogo’s
  static const List<String> _allLogos = [
    'assets/images/logo_ADO20.png',
    'assets/images/logo_ASWH.png',
    'assets/images/logo_BlauwGeel38JUMBO.png',
    'assets/images/logo_DOVO.png',
    'assets/images/logo_DVS33Ermelo.png',
    'assets/images/logo_Eemdijk.png',
    'assets/images/logo_Excelsior31.png',
    'assets/images/logo_FCLisse.png',
    'assets/images/logo_Gemert.png',
    'assets/images/logo_Goes.png',
    'assets/images/logo_GroeneSter.png',
    'assets/images/logo_HarkemaseBoys.png',
    'assets/images/logo_Hercules.png',
    'assets/images/logo_Hoogeveen.png',
    'assets/images/logo_HSC21.png',
    'assets/images/logo_Huizen.png',
    'assets/images/logo_Kloetinge.png',
    'assets/images/logo_Noordwijk.png',
    'assets/images/logo_RBC.png',
    'assets/images/logo_Rijnvogels.png',
    'assets/images/logo_RohdaRaalte.png',
    'assets/images/logo_SCGenemuiden.png',
    'assets/images/logo_Scherpenzeel.png',
    'assets/images/logo_Scheveningen.png',
    'assets/images/logo_SpartaNijkerk.png',
    'assets/images/logo_Sportlust46.png',
    'assets/images/logo_Staphorst.png',
    'assets/images/logo_SteDoCo.png',
    'assets/images/logo_svMeerssen.png',
    'assets/images/logo_TEC.png',
    'assets/images/logo_TOGB.png',
    'assets/images/logo_UDI19.png',
    'assets/images/logo_UNA.png',
    'assets/images/logo_Urk.png',
    'assets/images/logo_VVSB.png',
    'assets/images/logo_Zwaluwen.png',
  ];

  late List<String> _logos;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Maak een nieuwe willekeurige volgorde
    _logos = List<String>.from(_allLogos)..shuffle(Random());
    // Start timer om elke 2 seconden te wisselen
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _index++;
        // Als we aan het eind zijn: opnieuw shuffelen
        if (_index >= _logos.length) {
          _index = 0;
          _logos.shuffle(Random());
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoPath = _logos[_index];
    return SizedBox(
      width: 120,
      height: 120,
      child: Image.asset(
        logoPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.shield_outlined, size: 64),
      ),
    );
  }
}


/// ---------------------------
/// DashboardScreen
/// ---------------------------
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon link niet openen')),
      );
    }
  }

  String _fmtDate(Timestamp ts) => DateFormat('d MMM yyyy', 'nl').format(ts.toDate());

  Widget _buildStatRow(String label, String value, {IconData? icon}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            if (icon != null) Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
            if (icon != null) const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _statsCard() => FutureBuilder<List<_M>>(
        future: _loadMatchesFromFirestore(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final s = _computeStats(snap.data!);

          final biggestWinLines = s.biggestWins.isEmpty
              ? const ['n.v.t.']
              : s.biggestWins.map((m) => '${m.home} ${m.sh}-${m.sa} ${m.away}').toList();

          final mostGoalsLines = s.mostGoalsMatches.isEmpty
              ? const ['n.v.t.']
              : s.mostGoalsMatches
                  .map((m) => '${m.home} ${m.sh}-${m.sa} ${m.away} (${m.totalGoals} goals)')
                  .toList();

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bar_chart, color: Color(0xFF43A047)),
                      SizedBox(width: 8),
                      Text(
                        'Statistieken',
                        style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow('⚽ Totaal doelpunten', '${s.totalGoals}'),
                  _buildStatRow('Doelpunten Derde Divisie A', '${s.goalsA}'),
                  _buildStatRow('Doelpunten Derde Divisie B', '${s.goalsB}'),
                  const Divider(),
                  _buildStatRow('Gemiddeld aantal doelpunten', s.avgGoalsTotal.toStringAsFixed(2)),
                  _buildStatRow('Gem. per wedstrijd Divisie A', s.avgGoalsA.toStringAsFixed(2)),
                  _buildStatRow('Gem. per wedstrijd Divisie B', s.avgGoalsB.toStringAsFixed(2)),
                  const Divider(),
                  const Text('Grootste overwinning:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...biggestWinLines.map((t) => Text(t)),
                  const SizedBox(height: 8),
                  const Text('Meeste goals in één wedstrijd:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...mostGoalsLines.map((t) => Text(t)),
                ],
              ),
            ),
          );
        },
      );

  Widget _xPostsCard(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.article_outlined, color: Color(0xFF43A047)),
                  SizedBox(width: 8),
                  Text(
                    'Laatste berichten van @Derde_Div',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openUrl(context, 'https://x.com/Derde_Div'),
                child: const Text(
                  '🔗 Volg @Derde_Div op X →',
                  style: TextStyle(
                    color: Color(0xFF43A047),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('x_posts')
                    .orderBy('createdAt', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const Text('Nog geen berichten gevonden.');

                  return SizedBox(
                    height: 400,
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final text = data['text'] ?? '';
                        final mediaUrl = data['mediaUrl'] as String?;
                        final url = data['url'] as String?;
                        final created = data['createdAt'] as Timestamp?;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (created != null)
                                  Text(
                                    _fmtDate(created),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                if (mediaUrl != null && mediaUrl.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Image.network(mediaUrl, fit: BoxFit.cover),
                                  ),
                                Text(text, style: const TextStyle(height: 1.3)),
                                if (url != null && url.isNotEmpty)
                                  TextButton(
                                    onPressed: () => _openUrl(context, url),
                                    child: const Text('Bekijk op X →'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFAF5F3),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Deelnemende teams seizoen 2025/2026',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const RotatingLogo(),
                    const SizedBox(height: 12),
                    // 🔥 Deelknop
                    ElevatedButton.icon(
                      onPressed: () {
                        const message =
                            '🏆 Doe mee met de Derde Divisie Voorspelpoule!\n'
                            'Voorspel uitslagen, daag je vrienden uit en klim in de ranglijst.\n'
                            '👉 Download de app of volg @Derde_Div op X!';
                        Share.share(message, subject: 'Daag je vrienden uit!');
                      },
                      icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
                      label: const Text(
                        'Daag je vrienden uit',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _statsCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _xPostsCard(context)),
                        ],
                      )
                    else ...[
                      _statsCard(),
                      const SizedBox(height: 24),
                      _xPostsCard(context),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
}
