// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MatchFieldMap {
  static const homeTeamKeys = ['thuisteam', 'homeTeam'];
  static const awayTeamKeys = ['uitteam', 'awayTeam'];
  static const homeScoreKeys = ['uitslagThuis', 'scoreThuis'];
  static const awayScoreKeys = ['uitslagUit', 'scoreUit'];
  static const divisionKeys = ['competitie'];
  static const dateKeys = ['datum'];
  static const playedFlagKeys = ['verwerkt', 'gespeeld', 'isProcessed'];
}

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

Future<List<_M>> _loadMatchesFromFirestore() async {
  final snapshot = await FirebaseFirestore.instance.collection('matches').get();
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

  int totalGoals = 0;
  int goalsA = 0;
  int goalsB = 0;
  int playedA = 0;
  int playedB = 0;
  int biggestDiff = -1;
  int mostTotal = -1;
  List<_M> biggestWins = [];
  List<_M> mostGoalsMatches = [];

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

  return _Stats(
    totalMatches: total,
    playedMatches: played.length,
    playedA: playedA,
    playedB: playedB,
    totalGoals: totalGoals,
    goalsA: goalsA,
    goalsB: goalsB,
    avgGoalsTotal: played.isEmpty ? 0 : totalGoals / played.length,
    avgGoalsA: playedA == 0 ? 0 : goalsA / playedA,
    avgGoalsB: playedB == 0 ? 0 : goalsB / playedB,
    biggestWins: biggestWins,
    mostGoalsMatches: mostGoalsMatches,
  );
}

class RotatingLogo extends StatefulWidget {
  const RotatingLogo({super.key, this.size = 86});

  final double size;

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo> {
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
    _logos = List<String>.from(_allLogos)..shuffle(Random());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _index++;
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: Image.asset(
        _logos[_index],
        key: ValueKey(_logos[_index]),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.shield_outlined,
          size: widget.size * .72,
          color: const Color(0xFF2F8F3B),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.onOpenStand,
    this.onOpenPredict,
    this.onOpenPoules,
  });

  final VoidCallback? onOpenStand;
  final VoidCallback? onOpenPredict;
  final VoidCallback? onOpenPoules;

  static const _cream = Color(0xFFF3F6F1);

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon link niet openen')),
      );
    }
  }

  String _fmtDate(Timestamp ts) => DateFormat('d MMM yyyy', 'nl').format(ts.toDate());

  Future<void> _shareApp() async {
    const message = 'DerdeDiv.nl — volg de Derde Divisie en doe mee met de voorspelpoule.\nhttps://derdedev.nl';
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'DerdeDiv.nl',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 980;
          final isTablet = constraints.maxWidth >= 700 && !isDesktop;
          final maxWidth = isDesktop ? 1180.0 : 760.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: isDesktop ? 28 : 18,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroPanel(
                      isDesktop: isDesktop,
                      onOpenStand: onOpenStand,
                      onOpenPredict: onOpenPredict,
                      onShare: _shareApp,
                    ),
                    const SizedBox(height: 18),
                    _QuickActions(
                      isTabletOrDesktop: isTablet || isDesktop,
                      onOpenStand: onOpenStand,
                      onOpenPredict: onOpenPredict,
                      onOpenPoules: onOpenPoules,
                      onOpenX: () => _openUrl(context, 'https://x.com/Derde_Div'),
                    ),
                    const SizedBox(height: 18),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _StatsCard()),
                          const SizedBox(width: 18),
                          Expanded(flex: 4, child: _XPostsCard(openUrl: _openUrl, fmtDate: _fmtDate)),
                        ],
                      )
                    else ...[
                      _StatsCard(),
                      const SizedBox(height: 18),
                      _XPostsCard(openUrl: _openUrl, fmtDate: _fmtDate),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  static const _green = Color(0xFF2F8F3B);
  static const _darkGreen = Color(0xFF153B2A);

  final bool isDesktop;
  final VoidCallback? onOpenStand;
  final VoidCallback? onOpenPredict;
  final VoidCallback onShare;

  const _HeroPanel({
    required this.isDesktop,
    required this.onOpenStand,
    required this.onOpenPredict,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final textBlock = Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: const Text(
            'Derde Divisie A & B',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Alles rond de Derde Divisie op één plek.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 38 : 28,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bekijk standen, programma, cijfers en ranglijsten. Meedoen met voorspellen kan zodra je bent ingelogd.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.45),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: onOpenStand,
              icon: const Icon(Icons.leaderboard),
              label: const Text('Bekijk standen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _darkGreen,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenPredict,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Voorspellen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share),
              label: const Text('Delen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ],
        ),
      ],
    );

    final logoBlock = Container(
      width: isDesktop ? 230 : 150,
      height: isDesktop ? 230 : 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Center(child: RotatingLogo(size: isDesktop ? 138 : 96)),
    );

    return Container(
      padding: EdgeInsets.all(isDesktop ? 34 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkGreen, _green],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(child: textBlock),
                const SizedBox(width: 28),
                logoBlock,
              ],
            )
          : Column(
              children: [
                logoBlock,
                const SizedBox(height: 22),
                textBlock,
              ],
            ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isTabletOrDesktop;
  final VoidCallback? onOpenStand;
  final VoidCallback? onOpenPredict;
  final VoidCallback? onOpenPoules;
  final VoidCallback onOpenX;

  const _QuickActions({
    required this.isTabletOrDesktop,
    required this.onOpenStand,
    required this.onOpenPredict,
    required this.onOpenPoules,
    required this.onOpenX,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickActionData(
        icon: Icons.leaderboard_outlined,
        title: 'Standen',
        subtitle: 'A en B overzichtelijk naast elkaar.',
        onTap: onOpenStand,
      ),
      _QuickActionData(
        icon: Icons.edit_calendar_outlined,
        title: 'Voorspellen',
        subtitle: 'Log in en vul je uitslagen in.',
        onTap: onOpenPredict,
      ),
      _QuickActionData(
        icon: Icons.groups_2_outlined,
        title: 'Poules',
        subtitle: 'Maak of open je eigen poule.',
        onTap: onOpenPoules,
      ),
      _QuickActionData(
        icon: Icons.alternate_email,
        title: '@Derde_Div',
        subtitle: 'Laatste berichten en updates.',
        onTap: onOpenX,
      ),
    ];

    if (!isTabletOrDesktop) {
      return Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuickActionCard(data: item),
                ))
            .toList(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) => _QuickActionCard(data: items[index]),
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  static const _green = Color(0xFF2F8F3B);
  static const _darkGreen = Color(0xFF153B2A);

  final _QuickActionData data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: _green),
              ),
              const SizedBox(height: 12),
              Text(
                data.title,
                style: const TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  data.subtitle,
                  style: const TextStyle(color: Colors.black54, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_M>>(
      future: _loadMatchesFromFirestore(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _PanelCard(
            title: 'Cijfers',
            icon: Icons.query_stats_outlined,
            child: SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
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

        return _PanelCard(
          title: 'Cijfers van het seizoen',
          icon: Icons.query_stats_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricTile(label: 'Wedstrijden', value: '${s.playedMatches}/${s.totalMatches}'),
                  _MetricTile(label: 'Doelpunten', value: '${s.totalGoals}'),
                  _MetricTile(label: 'Gemiddelde', value: s.avgGoalsTotal.toStringAsFixed(2)),
                ],
              ),
              const SizedBox(height: 16),
              _StatLine(label: 'Doelpunten Divisie A', value: '${s.goalsA}'),
              _StatLine(label: 'Doelpunten Divisie B', value: '${s.goalsB}'),
              _StatLine(label: 'Gem. Divisie A', value: s.avgGoalsA.toStringAsFixed(2)),
              _StatLine(label: 'Gem. Divisie B', value: s.avgGoalsB.toStringAsFixed(2)),
              const Divider(height: 28),
              const Text(
                'Grootste overwinning',
                style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ...biggestWinLines.take(4).map((t) => Text(t, style: const TextStyle(height: 1.35))),
              const SizedBox(height: 14),
              const Text(
                'Meeste goals in één wedstrijd',
                style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ...mostGoalsLines.take(4).map((t) => Text(t, style: const TextStyle(height: 1.35))),
            ],
          ),
        );
      },
    );
  }
}

class _XPostsCard extends StatelessWidget {
  final Future<void> Function(BuildContext, String) openUrl;
  final String Function(Timestamp) fmtDate;

  const _XPostsCard({required this.openUrl, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Laatste berichten',
      icon: Icons.article_outlined,
      trailing: TextButton.icon(
        onPressed: () => openUrl(context, 'https://x.com/Derde_Div'),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('@Derde_Div'),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('x_posts')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Text('Nog geen berichten gevonden.');
          }

          return Column(
            children: List.generate(docs.length, (i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final text = (data['text'] ?? '').toString();
              final mediaUrl = data['mediaUrl'] as String?;
              final url = data['url'] as String?;
              final created = data['createdAt'] as Timestamp?;

              return Padding(
                padding: EdgeInsets.only(bottom: i == docs.length - 1 ? 0 : 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: url == null || url.isEmpty ? null : () => openUrl(context, url),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE3EADF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (created != null)
                          Text(
                            fmtDate(created),
                            style: const TextStyle(color: Colors.black45, fontSize: 12),
                          ),
                        if (mediaUrl != null && mediaUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Text(
                          text,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _PanelCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2F8F3B)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF153B2A),
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
