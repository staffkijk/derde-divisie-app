import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/derde_divisie/historical_standings_screen.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_voorspelling_screen.dart';
import 'package:derde_divisie/features/voorspellen/prediction_screen.dart';
import 'package:derde_divisie/features/voorspellen/ranking_screen.dart';
import 'package:derde_divisie/features/voorspellen/voorspel_een_team_screen.dart';

class PredictionOverviewScreen extends StatelessWidget {
  const PredictionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth >= 900 ? 28 : 14,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(
                      icon: Icons.sports_soccer_rounded,
                      title: 'Wedstrijden voorspellen',
                    ),
                    SizedBox(height: 10),
                    _ActionGrid(
                      actions: [
                        _ActionCard(
                          icon: Icons.looks_one_rounded,
                          title: 'Divisie A',
                          subtitle: 'Voorspel de wedstrijduitslagen',
                          action: _PredictionAction.matchesA,
                        ),
                        _ActionCard(
                          icon: Icons.looks_two_rounded,
                          title: 'Divisie B',
                          subtitle: 'Voorspel de wedstrijduitslagen',
                          action: _PredictionAction.matchesB,
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    _SectionTitle(
                      icon: Icons.format_list_numbered_rounded,
                      title: 'Eindstand voorspellen',
                    ),
                    SizedBox(height: 10),
                    _ActionGrid(
                      actions: [
                        _ActionCard(
                          icon: Icons.leaderboard_rounded,
                          title: 'Eindstand Divisie A',
                          subtitle: 'Rangschik de clubs',
                          action: _PredictionAction.tableA,
                        ),
                        _ActionCard(
                          icon: Icons.leaderboard_rounded,
                          title: 'Eindstand Divisie B',
                          subtitle: 'Rangschik de clubs',
                          action: _PredictionAction.tableB,
                        ),
                        _ActionCard(
                          icon: Icons.history_rounded,
                          title: 'Eindstand afgelopen seizoen',
                          subtitle: 'Bekijk seizoen 2025/2026',
                          action: _PredictionAction.lastSeason,
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    _SectionTitle(
                      icon: Icons.shield_outlined,
                      title: 'Team voorspellen',
                    ),
                    SizedBox(height: 10),
                    _ActionGrid(
                      actions: [
                        _ActionCard(
                          icon: Icons.groups_rounded,
                          title: 'Kies een team',
                          subtitle: 'Voorspel alleen wedstrijden van jouw team',
                          action: _PredictionAction.team,
                        ),
                      ],
                    ),
                    SizedBox(height: 28),
                    Divider(),
                    SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.emoji_events_rounded,
                      title: 'Ranglijsten',
                    ),
                    SizedBox(height: 10),
                    _GlobalTopThree(),
                    SizedBox(height: 12),
                    _RankingLinks(),
                    SizedBox(height: 24),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2F8F3B)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF153B2A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_ActionCard> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map((action) => SizedBox(width: width, child: action))
              .toList(),
        );
      },
    );
  }
}

enum _PredictionAction { matchesA, matchesB, tableA, tableB, team, lastSeason }

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _PredictionAction action;

  Future<void> _open(BuildContext context) async {
    switch (action) {
      case _PredictionAction.matchesA:
      case _PredictionAction.matchesB:
        final division = action == _PredictionAction.matchesA ? 'A' : 'B';
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PredictionScreen(divisie: division),
          ),
        );
        return;
      case _PredictionAction.tableA:
      case _PredictionAction.tableB:
        final division = action == _PredictionAction.tableA ? 'A' : 'B';
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EindstandVoorspellingScreen(divisie: division),
          ),
        );
        return;
      case _PredictionAction.lastSeason:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HistoricalStandingsScreen(
              initialSeason: '2025-2026',
            ),
          ),
        );
        return;
      case _PredictionAction.team:
        await _chooseTeam(context);
        return;
    }
  }

  Future<void> _chooseTeam(BuildContext context) async {
    final team = await showModalBottomSheet<SeasonTeam>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Kies een team',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: SeasonConfig.teamsInListOrder.length,
                  itemBuilder: (context, index) {
                    final item = SeasonConfig.teamsInListOrder[index];
                    return ListTile(
                      leading: Image.asset(
                        item.logoPath,
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.shield_outlined),
                      ),
                      title: Text(item.listLabel),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (team == null || !context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoorspelEenTeamScreen(
          team: team.listLabel,
          competition: team.division,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE3EADF)),
      ),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2F8F3B)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF153B2A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalTopThree extends StatelessWidget {
  const _GlobalTopThree();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalen', descending: true)
          .limit(3)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const _EmptyRanking(
              text: 'De ranglijst kan nu niet worden geladen.');
        }

        final docs = snapshot.data!.docs
            .where((doc) => (doc.data()['totalen'] as num? ?? 0) > 0)
            .toList();
        if (docs.isEmpty) {
          return const _EmptyRanking(
            text: 'Er is nog geen ranglijst beschikbaar.',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3EADF)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < docs.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Text('${i + 1}'),
                  ),
                  title: Text(
                    (docs[i].data()['username'] ?? 'Onbekend').toString(),
                  ),
                  trailing: Text(
                    '${docs[i].data()['totalen'] ?? 0} pt',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class _RankingLinks extends StatelessWidget {
  const _RankingLinks();

  @override
  Widget build(BuildContext context) {
    final links = [
      const _RankingLink(label: 'Globale ranglijst'),
      const _RankingLink(label: 'Ranking Divisie A'),
      const _RankingLink(label: 'Ranking Divisie B'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: links,
    );
  }
}

class _RankingLink extends StatelessWidget {
  const _RankingLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const RankingScreen(),
          ),
        );
      },
      icon: const Icon(Icons.leaderboard_outlined),
      label: Text(label),
    );
  }
}
