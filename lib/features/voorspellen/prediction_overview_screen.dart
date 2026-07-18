import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/features/derde_divisie/wedstrijden_scherm_derde_divisie_a.dart';
import 'package:derde_divisie/features/derde_divisie/wedstrijden_scherm_derde_divisie_b.dart';
import 'package:derde_divisie/features/voorspellen/archived_prediction_ranking_screen.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_voorspelling_screen.dart';
import 'package:derde_divisie/features/voorspellen/ranking_screen.dart';
import 'package:derde_divisie/features/voorspellen/voorspel_een_team_screen.dart';

class PredictionOverviewScreen extends StatefulWidget {
  const PredictionOverviewScreen({
    super.key,
    this.initialDivision,
    this.initialRound,
  });

  final String? initialDivision;
  final int? initialRound;

  @override
  State<PredictionOverviewScreen> createState() =>
      _PredictionOverviewScreenState();
}

class _PredictionOverviewScreenState extends State<PredictionOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F1),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 900 ? 28.0 : 14.0;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 8),
                    child: const _PredictionHeader(),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: const TabBar(
                        isScrollable: true,
                        tabs: [
                          Tab(text: 'Wedstrijden'),
                          Tab(text: 'Eindstand'),
                          Tab(text: 'Team'),
                          Tab(text: 'Ranglijsten'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _MatchesPredictionTab(
                          key: ValueKey(
                            '${widget.initialDivision}-${widget.initialRound}',
                          ),
                          initialDivision: widget.initialDivision,
                          initialRound: widget.initialRound,
                        ),
                        _ScrollableTab(
                          horizontalPadding: horizontal,
                          child: const _FinalRankingTab(),
                        ),
                        _ScrollableTab(
                          horizontalPadding: horizontal,
                          child: const _TeamPredictionTab(),
                        ),
                        _ScrollableTab(
                          horizontalPadding: horizontal,
                          child: const _RankingsTab(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScrollableTab extends StatelessWidget {
  const _ScrollableTab({
    required this.horizontalPadding,
    required this.child,
  });

  final double horizontalPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    );
  }
}

class _MatchesPredictionTab extends StatefulWidget {
  const _MatchesPredictionTab({
    super.key,
    this.initialDivision,
    this.initialRound,
  });

  final String? initialDivision;
  final int? initialRound;

  @override
  State<_MatchesPredictionTab> createState() => _MatchesPredictionTabState();
}

class _MatchesPredictionTabState extends State<_MatchesPredictionTab>
    with AutomaticKeepAliveClientMixin {
  String _division = 'A';
  bool _loadedFavorite = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDivision == 'A' || widget.initialDivision == 'B') {
      _division = widget.initialDivision!;
      _loadedFavorite = true;
    } else {
      _loadFavoriteDivision();
    }
  }

  Future<void> _loadFavoriteDivision() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _loadedFavorite = true;
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    final team = SeasonConfig.teamById(
          (data?['favoriteTeamSlug'] ?? '').toString(),
        ) ??
        SeasonConfig.teamByName(
          (data?['favoriteTeamName'] ?? data?['favorieteClub'] ?? '')
              .toString(),
        );
    if (!mounted) return;
    setState(() {
      _division = team?.division == SeasonConfig.divisionB ? 'B' : 'A';
      _loadedFavorite = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Center(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'A', label: Text('Divisie A')),
                ButtonSegment(value: 'B', label: Text('Divisie B')),
              ],
              selected: {_division},
              onSelectionChanged: (selection) {
                setState(() => _division = selection.first);
                ActivityLogService().log(
                  eventType: ActivityEventType.divisionSelected,
                  metadata: {'division': _division},
                );
              },
            ),
          ),
        ),
        Expanded(
          child: !_loadedFavorite
              ? const Center(child: CircularProgressIndicator())
              : _division == 'A'
                  ? WedstrijdenSchermDerdeDivisieA(
                      divisie: 'A',
                      initialRound: widget.initialRound,
                    )
                  : WedstrijdenSchermDerdeDivisieB(
                      divisie: 'B',
                      initialRound: widget.initialRound,
                    ),
        ),
      ],
    );
  }
}

class _FinalRankingTab extends StatelessWidget {
  const _FinalRankingTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          ],
        ),
      ],
    );
  }
}

class _TeamPredictionTab extends StatelessWidget {
  const _TeamPredictionTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

class _RankingsTab extends StatelessWidget {
  const _RankingsTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: Icons.emoji_events_rounded,
          title: 'Ranglijsten',
        ),
        SizedBox(height: AppSpacing.xs),
        _GlobalTopThree(),
        SizedBox(height: AppSpacing.xs),
        _RankingLinks(),
        SizedBox(height: AppSpacing.lg),
        _ActionGrid(
          actions: [
            _ActionCard(
              icon: Icons.emoji_events_rounded,
              title: 'Voorspelranking afgelopen seizoen',
              subtitle: 'Eindranglijst voorspellers 2025/2026',
              action: _PredictionAction.lastSeason,
            ),
          ],
        ),
      ],
    );
  }
}

class _PredictionHeader extends StatelessWidget {
  const _PredictionHeader();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return AppCard(
      child: Row(
        children: [
          if (!isMobile) ...[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Icon(
                Icons.edit_calendar_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voorspellen',
                  style: isMobile
                      ? AppTextStyles.sectionTitle
                      : AppTextStyles.pageTitle,
                ),
                if (!isMobile) ...[
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Kies een competitie of team. De deadline staat compact bij iedere speelronde.',
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ],
            ),
          ),
          if (user != null && !isMobile)
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final team = SeasonConfig.teamById(
                      (data?['favoriteTeamSlug'] ?? '').toString(),
                    ) ??
                    SeasonConfig.teamByName(
                      (data?['favoriteTeamName'] ??
                              data?['favorieteClub'] ??
                              '')
                          .toString(),
                    );
                if (team == null) return const SizedBox.shrink();
                return Chip(
                  avatar: TeamLogo(
                    teamName: team.label,
                    teamSlug: team.id,
                    assetPath: team.logoPath,
                    size: 22,
                    padding: 0,
                  ),
                  label: Text(team.listLabel),
                );
              },
            ),
        ],
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
            ? constraints.maxWidth >= 1050
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2
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

enum _PredictionAction { tableA, tableB, team, lastSeason }

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

      case _PredictionAction.team:
        await _chooseTeam(context);
        return;

      case _PredictionAction.lastSeason:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ArchivedPredictionRankingScreen(
              initialSeason: '2025-2026',
            ),
          ),
        );
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
                      leading: TeamLogo(
                        teamName: item.label,
                        teamSlug: item.id,
                        assetPath: item.logoPath,
                        size: 32,
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

        final ranked = snapshot.data!.docs
            .where((doc) => (doc.data()['totalen'] as num? ?? 0) > 0)
            .toList();
        if (ranked.isEmpty) {
          return const _EmptyRanking(
            text: 'Er is nog geen ranglijst beschikbaar.',
          );
        }
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final userIndex =
            userId == null ? -1 : ranked.indexWhere((doc) => doc.id == userId);
        final docs = ranked.take(5).toList();

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (userIndex >= 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Jouw positie: ${userIndex + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
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
