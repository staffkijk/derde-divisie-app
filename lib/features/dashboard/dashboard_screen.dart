// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/analytics_service.dart';
import 'package:derde_divisie/data/services/prediction_reminder_service.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/features/derde_divisie/historical_standings_screen.dart';
import 'package:derde_divisie/features/dashboard/dashboard_match_center.dart';

/// ---------------------------
/// Firestore veldmapping
/// ---------------------------
class MatchFieldMap {
  static const homeTeamKeys = ['homeTeamName', 'homeTeam', 'thuisteam'];
  static const awayTeamKeys = ['awayTeamName', 'awayTeam', 'uitteam'];
  static const homeScoreKeys = ['homeScore', 'uitslagThuis', 'scoreThuis'];
  static const awayScoreKeys = ['awayScore', 'uitslagUit', 'scoreUit'];
  static const divisionKeys = ['division', 'competitie'];
  static const dateKeys = ['scheduledAt', 'date', 'datum'];
  static const playedFlagKeys = ['processed', 'verwerkt', 'gespeeld'];
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
  final snapshot = await SeasonPaths.currentSeasonMatches.get();
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

class _HomePredictionReminder extends StatelessWidget {
  const _HomePredictionReminder({required this.onOpenPredict});

  final VoidCallback? onOpenPredict;

  Future<PredictionReminderStatus?> _load() async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    final service = PredictionReminderService();
    final a = await service.syncMissingPredictionNotification(division: 'A');
    if (a != null && !a.complete && !a.expired && a.missing > 0) return a;
    final b = await service.syncMissingPredictionNotification(division: 'B');
    if (b != null && !b.complete && !b.expired && b.missing > 0) return b;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PredictionReminderStatus?>(
      future: _load(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) return const SizedBox(height: 24);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.edit_notifications_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                'Je hebt nog ${status.missing} wedstrijden niet voorspeld voor speelronde ${status.round}.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Divisie ${status.division} - ${status.predicted} van ${status.totalRequired} ingevuld.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenPredict,
            ),
          ),
        );
      },
    );
  }
}

_Stats _computeStats(List<_M> ms) {
  final played =
      ms.where((m) => m.played && m.sh != null && m.sa != null).toList();
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
/// RotatingLogo
/// ---------------------------
class RotatingLogo extends StatefulWidget {
  const RotatingLogo({super.key});

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo> {
  late List<SeasonTeam> _teams;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _teams = List<SeasonTeam>.from(SeasonConfig.teamsInListOrder)
      ..shuffle(Random());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _index++;
        if (_index >= _teams.length) {
          _index = 0;
          _teams.shuffle(Random());
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
    final team = _teams[_index];
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: TeamLogo(
            teamName: team.listLabel,
            teamSlug: team.id,
            assetPath: team.logoPath,
            size: 120,
            padding: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          team.listLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1B5E20),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// ---------------------------
/// DashboardScreen
/// ---------------------------
class DashboardScreen extends StatelessWidget {
  final VoidCallback? onOpenIntrofilm;
  final VoidCallback? onOpenDivisionA;
  final VoidCallback? onOpenDivisionB;
  final VoidCallback? onOpenPredict;
  final VoidCallback? onOpenPoules;
  final VoidCallback? onOpenProgram;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistoricalStandings;

  const DashboardScreen({
    super.key,
    this.onOpenIntrofilm,
    this.onOpenDivisionA,
    this.onOpenDivisionB,
    this.onOpenPredict,
    this.onOpenPoules,
    this.onOpenProgram,
    this.onOpenProfile,
    this.onOpenHistoricalStandings,
  });

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon link niet openen')),
      );
    }
  }

  String _fmtDate(Timestamp ts) =>
      DateFormat('d MMM yyyy', 'nl').format(ts.toDate());

  Widget _buildStatRow(String label, String value, {IconData? icon}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
            if (icon != null) const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _quickLinksCard(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final cards = [
                _HomeQuickAction(
                  title: 'Derde Divisie A',
                  subtitle: 'Stand, alle 9 wedstrijden en laatste uitslagen.',
                  icon: Icons.leaderboard_rounded,
                  onTap: onOpenDivisionA,
                ),
                _HomeQuickAction(
                  title: 'Derde Divisie B',
                  subtitle: 'Stand, alle 9 wedstrijden en laatste uitslagen.',
                  icon: Icons.leaderboard_rounded,
                  onTap: onOpenDivisionB,
                ),
                _HomeQuickAction(
                  title: 'Voorspellen',
                  subtitle: 'Log in om uitslagen te voorspellen.',
                  icon: Icons.edit_calendar_rounded,
                  onTap: onOpenPredict,
                ),
                _HomeQuickAction(
                  title: 'Poules',
                  subtitle: 'Bekijk je poules en ranglijsten.',
                  icon: Icons.groups_2_rounded,
                  onTap: onOpenPoules,
                ),
                _HomeQuickAction(
                  title: 'Historische eindstanden',
                  subtitle: 'Bekijk eindstanden van eerdere seizoenen.',
                  icon: Icons.history_rounded,
                  onTap: onOpenHistoricalStandings ??
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistoricalStandingsScreen(),
                          ),
                        );
                      },
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth >= 960 ? 5 : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: cards,
              );
            },
          ),
        ),
      );

  Widget _seasonTeamsCard() => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.groups_rounded, color: Color(0xFF43A047)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deelnemende teams 2026/2027',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'De indeling van de Derde Divisie A en B volgt later. Tot die tijd tonen we alle bevestigde deelnemers gezamenlijk.',
                style: TextStyle(color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1100
                      ? 6
                      : width >= 850
                          ? 5
                          : width >= 620
                              ? 4
                              : width >= 420
                                  ? 3
                                  : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: SeasonConfig.teamsInListOrder.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    itemBuilder: (context, index) {
                      final team = SeasonConfig.teamsInListOrder[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TeamLogo(
                                teamName: team.listLabel,
                                teamSlug: team.id,
                                assetPath: team.logoPath,
                                size: 72,
                                padding: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              team.listLabel,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );

  Widget _introfilmCard() => _DashboardIntrofilmCard(
        onTap: onOpenIntrofilm,
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
              : s.biggestWins
                  .map((m) => '${m.home} ${m.sh}-${m.sa} ${m.away}')
                  .toList();

          final mostGoalsLines = s.mostGoalsMatches.isEmpty
              ? const ['n.v.t.']
              : s.mostGoalsMatches
                  .map((m) =>
                      '${m.home} ${m.sh}-${m.sa} ${m.away} (${m.totalGoals} goals)')
                  .toList();

          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow('⚽ Totaal doelpunten', '${s.totalGoals}'),
                  _buildStatRow('Doelpunten Derde Divisie A', '${s.goalsA}'),
                  _buildStatRow('Doelpunten Derde Divisie B', '${s.goalsB}'),
                  const Divider(),
                  _buildStatRow('Gemiddeld aantal doelpunten',
                      s.avgGoalsTotal.toStringAsFixed(2)),
                  _buildStatRow('Gem. per wedstrijd Divisie A',
                      s.avgGoalsA.toStringAsFixed(2)),
                  _buildStatRow('Gem. per wedstrijd Divisie B',
                      s.avgGoalsB.toStringAsFixed(2)),
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
                  if (docs.isEmpty) {
                    return const Text('Nog geen berichten gevonden.');
                  }

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
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                if (mediaUrl != null && mediaUrl.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Image.network(mediaUrl,
                                        fit: BoxFit.cover),
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
        backgroundColor: const Color(0xFFF3F6F1),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF153B2A), Color(0xFF2F8F3B)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'DerdeDiv · ${SeasonConfig.activeSeasonLabel}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Standen, programma, uitslagen en voorspellingen voor de Derde Divisie.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await AnalyticsService.instance
                                    .trackShareClicked(
                                        source: 'home_challenge');
                                await Share.share(
                                  'Doe mee met de Derde Divisie Voorspelpoule op DerdeDiv!',
                                  subject: 'Daag je vrienden uit',
                                );
                              },
                              icon: const Icon(Icons.ios_share_outlined),
                              label: const Text('Daag je vrienden uit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HomePredictionReminder(onOpenPredict: onOpenPredict),
                      const SizedBox.shrink(),
                      const SizedBox.shrink(),
                      const SizedBox.shrink(),
                      Visibility(
                        visible: false,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            const message =
                                '🏆 Doe mee met de Derde Divisie Voorspelpoule!\n'
                                'Voorspel uitslagen, daag je vrienden uit en klim in de ranglijst.\n'
                                '👉 Download de app of volg @Derde_Div op X!';

                            await AnalyticsService.instance
                                .trackShareClicked(source: 'home_hidden');
                            await Share.share(
                              message,
                              subject: 'Daag je vrienden uit!',
                            );
                          },
                          icon: const Icon(Icons.emoji_events_rounded,
                              color: Colors.white),
                          label: const Text(
                            'Daag je vrienden uit',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DashboardMatchCenter(
                        showHero: false,
                        onOpenProgram: onOpenProgram ?? () {},
                        onOpenPredict: onOpenPredict ?? () {},
                        onOpenProfile: onOpenProfile ?? () {},
                      ),
                      const SizedBox(height: 24),
                      _introfilmCard(),
                      const SizedBox(height: 24),
                      _quickLinksCard(context),
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
                      const SizedBox(height: 24),
                      _seasonTeamsCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _DashboardIntrofilmCard extends StatefulWidget {
  final VoidCallback? onTap;

  const _DashboardIntrofilmCard({required this.onTap});

  @override
  State<_DashboardIntrofilmCard> createState() =>
      _DashboardIntrofilmCardState();
}

class _DashboardIntrofilmCardState extends State<_DashboardIntrofilmCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return Semantics(
      button: true,
      label: 'Open de Derde Divisie introfilm voor seizoen 2026/2027',
      child: Tooltip(
        message: 'Introfilm openen',
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedScale(
            scale: _hovered && enabled ? 1.006 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: widget.onTap,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xFF050807),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF3BAE5D).withValues(alpha: .34),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3BAE5D).withValues(
                            alpha: _hovered && enabled ? .22 : .12,
                          ),
                          blurRadius: _hovered && enabled ? 34 : 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: .76,
                            colors: [
                              Color(0x332F8F3B),
                              Color(0x110F2B1D),
                              Color(0xFF050807),
                            ],
                            stops: [0, .48, 1],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const DerdeDivLogo.full(
                                      width: 210,
                                      height: 82,
                                    ),
                                    const SizedBox(height: 22),
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3BAE5D)
                                            .withValues(alpha: .94),
                                        shape: BoxShape.circle,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x66000000),
                                            blurRadius: 18,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 44,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 22,
                              right: 22,
                              bottom: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Derde Divisie introfilm',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Seizoen 2026/2027',
                                    style: TextStyle(
                                      color: Color(0xFF7DDD90),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bekijk de officiële introductiefilm van het nieuwe seizoen.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .74),
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 18,
                              right: 18,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .34),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.ondemand_video_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Introfilm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _HomeQuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7FAF6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8DF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF2E7D32)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF153B2A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
