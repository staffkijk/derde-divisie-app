import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_rows.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';
import 'package:derde_divisie/features/clubs/club_detail_screen.dart';

class DashboardMatchCenter extends StatelessWidget {
  const DashboardMatchCenter({
    super.key,
    required this.onOpenProgram,
    required this.onOpenPredict,
    required this.onOpenProfile,
    this.showHero = true,
  });

  final VoidCallback onOpenProgram;
  final VoidCallback onOpenPredict;
  final VoidCallback onOpenProfile;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHero)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actions = Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.icon(
                      onPressed: onOpenProgram,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Programma'),
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
                  ],
                );
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DerdeDiv.nl · ${SeasonConfig.activeSeasonLabel}',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Standen, programma, uitslagen en voorspellingen voor de Derde Divisie.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                );
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      text,
                      const SizedBox(height: AppSpacing.md),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.lg),
                    actions,
                  ],
                );
              },
            ),
          ),
        if (showHero) const SizedBox(height: AppSpacing.md),
        _FavoriteAndActions(
          onOpenProgram: onOpenProgram,
          onOpenPredict: onOpenPredict,
          onOpenProfile: onOpenProfile,
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: SeasonPaths.currentSeasonMatches.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MessageCard(
                icon: Icons.error_outline,
                text: 'Het wedstrijdcentrum kan nu niet worden geladen.',
              );
            }
            if (!snapshot.hasData) {
              return const AppCard(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final matches = snapshot.data!.docs
                .where((doc) => doc.id != '_meta')
                .map((doc) => _DashboardMatch(doc.data()))
                .toList();
            final upcoming = matches
                .where(
                  (match) =>
                      match.status == MatchStatus.scheduled ||
                      match.status == MatchStatus.postponed,
                )
                .toList()
              ..sort((a, b) => MatchDateTimeFormatter.compare(a.data, b.data));
            final results = matches
                .where((match) => match.status == MatchStatus.finished)
                .toList()
              ..sort((a, b) => MatchDateTimeFormatter.compare(b.data, a.data));

            return LayoutBuilder(
              builder: (context, constraints) {
                List<_DashboardMatch> byDivision(
                  List<_DashboardMatch> source,
                  String division,
                ) {
                  return source
                      .where(
                        (match) => DivisionDataService.matchBelongsToDivision(
                          match.data,
                          division,
                        ),
                      )
                      .take(5)
                      .toList();
                }

                final cards = [
                  _MatchesPanel(
                    title: 'Komende wedstrijden Divisie A',
                    icon: Icons.event_available_outlined,
                    matches: byDivision(upcoming, 'A'),
                    emptyText: 'Er zijn geen open wedstrijden gevonden.',
                    onOpenAll: onOpenProgram,
                  ),
                  _MatchesPanel(
                    title: 'Komende wedstrijden Divisie B',
                    icon: Icons.event_available_outlined,
                    matches: byDivision(upcoming, 'B'),
                    emptyText: 'Er zijn geen open wedstrijden gevonden.',
                    onOpenAll: onOpenProgram,
                  ),
                  _MatchesPanel(
                    title: 'Laatste uitslagen Divisie A',
                    icon: Icons.fact_check_outlined,
                    matches: byDivision(results, 'A'),
                    emptyText:
                        'Zodra uitslagen zijn verwerkt verschijnen ze hier.',
                    onOpenAll: onOpenProgram,
                  ),
                  _MatchesPanel(
                    title: 'Laatste uitslagen Divisie B',
                    icon: Icons.fact_check_outlined,
                    matches: byDivision(results, 'B'),
                    emptyText:
                        'Zodra uitslagen zijn verwerkt verschijnen ze hier.',
                    onOpenAll: onOpenProgram,
                  ),
                ];
                final cardWidth = constraints.maxWidth < 840
                    ? constraints.maxWidth
                    : (constraints.maxWidth - AppSpacing.md) / 2;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final card in cards)
                      SizedBox(width: cardWidth, child: card),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _MatchesPanel extends StatelessWidget {
  const _MatchesPanel({
    required this.title,
    required this.icon,
    required this.matches,
    required this.emptyText,
    required this.onOpenAll,
  });

  final String title;
  final IconData icon;
  final List<_DashboardMatch> matches;
  final String emptyText;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(title, style: AppTextStyles.sectionTitle),
                ),
                TextButton(
                  onPressed: onOpenAll,
                  child: const Text('Alles bekijken'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(emptyText, style: AppTextStyles.bodyMuted),
            )
          else
            for (var index = 0; index < matches.length; index++) ...[
              CompactMatchRow(data: matches[index].rowData),
              if (index != matches.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _FavoriteAndActions extends StatelessWidget {
  const _FavoriteAndActions({
    required this.onOpenProgram,
    required this.onOpenPredict,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenProgram;
  final VoidCallback onOpenPredict;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: user == null
                ? const Text(
                    'Log in om je favoriete club en persoonlijke voorspelstatus te zien.',
                    style: AppTextStyles.bodyMuted,
                  )
                : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data();
                      final favoriteName = (data?['favoriteTeamName'] ??
                              data?['favorieteClub'] ??
                              '')
                          .toString();
                      final team = SeasonConfig.teamById(
                            (data?['favoriteTeamSlug'] ?? '').toString(),
                          ) ??
                          SeasonConfig.teamByName(favoriteName);
                      if (team == null) {
                        return InkWell(
                          onTap: onOpenProfile,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Kies je favoriete club voor een persoonlijker wedstrijdcentrum.',
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            team.logoPath,
                            width: 54,
                            height: 54,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.shield_outlined,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Jouw favoriete club',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  team.label,
                                  style: AppTextStyles.sectionTitle,
                                ),
                                Text(
                                  SeasonConfig.divisionName(team.division),
                                  style: AppTextStyles.bodyMuted,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _FavoriteMatchSummary(team: team),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ClubDetailScreen(
                                            teamSlug: team.id,
                                            teamName: team.label,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.shield_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Clubpagina'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: onOpenPredict,
                                      icon: const Icon(
                                        Icons.edit_calendar_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Voorspellen'),
                                    ),
                                    TextButton(
                                      onPressed: onOpenProfile,
                                      child: const Text('Wijzig club'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: onOpenProfile,
                child: const Text('Profiel'),
              ),
              OutlinedButton(
                onPressed: onOpenProgram,
                child: const Text('Programma'),
              ),
              FilledButton(
                onPressed: onOpenPredict,
                child: const Text('Voorspellen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FavoriteMatchSummary extends StatelessWidget {
  const _FavoriteMatchSummary({required this.team});

  final SeasonTeam team;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SeasonPaths.currentSeasonMatches.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final matches = snapshot.data!.docs
            .where((doc) => _involvesTeam(doc.data()))
            .map((doc) => _DashboardMatch(doc.data()))
            .toList();
        final upcoming = matches
            .where(
              (match) =>
                  match.status == MatchStatus.scheduled ||
                  match.status == MatchStatus.postponed,
            )
            .toList()
          ..sort((a, b) => MatchDateTimeFormatter.compare(a.data, b.data));
        final results = matches
            .where((match) => match.status == MatchStatus.finished)
            .toList()
          ..sort((a, b) => MatchDateTimeFormatter.compare(b.data, a.data));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              'Volgende',
              upcoming.isEmpty
                  ? 'Geen komende wedstrijd gevonden'
                  : _description(upcoming.first),
            ),
            const SizedBox(height: AppSpacing.xxs),
            _line(
              'Laatste',
              results.isEmpty
                  ? 'Nog geen uitslag'
                  : _description(results.first),
            ),
          ],
        );
      },
    );
  }

  bool _involvesTeam(Map<String, dynamic> data) {
    bool matches(dynamic rawSlug, dynamic rawName) {
      final slug = rawSlug?.toString() ?? '';
      final name = rawName?.toString() ?? '';
      final configured =
          SeasonConfig.teamById(slug) ?? SeasonConfig.teamByName(name);
      return configured?.id == team.id ||
          SeasonConfig.normalizeTeamKey(slug) ==
              SeasonConfig.normalizeTeamKey(team.id) ||
          SeasonConfig.normalizeTeamKey(name) ==
              SeasonConfig.normalizeTeamKey(team.name);
    }

    return matches(
          data['homeTeamSlug'] ?? data['homeTeamCode'],
          data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam'],
        ) ||
        matches(
          data['awayTeamSlug'] ?? data['awayTeamCode'],
          data['awayTeamName'] ?? data['awayTeam'] ?? data['uitteam'],
        );
  }

  Widget _line(String label, String text) {
    return Text.rich(
      TextSpan(
        text: '$label: ',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: text,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _description(_DashboardMatch match) {
    final row = match.rowData;
    return '${row.homeTeam} ${row.centerLabel} ${row.awayTeam}';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DashboardMatch {
  _DashboardMatch(this.data);

  final Map<String, dynamic> data;

  MatchStatus get status => parseMatchStatus(data['status']);

  String get division => SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['competitie'] ?? '').toString(),
      );

  MatchRowData get rowData {
    final homeScore = _int(data['homeScore'] ?? data['uitslagThuis']);
    final awayScore = _int(data['awayScore'] ?? data['uitslagUit']);
    final center =
        status == MatchStatus.finished && homeScore != null && awayScore != null
            ? '$homeScore - $awayScore'
            : status == MatchStatus.scheduled
                ? MatchDateTimeFormatter.publicTime(data)
                : status.label;
    return MatchRowData(
      homeTeam:
          (data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam'] ?? '')
              .toString(),
      awayTeam:
          (data['awayTeamName'] ?? data['awayTeam'] ?? data['uitteam'] ?? '')
              .toString(),
      homeTeamSlug:
          (data['homeTeamSlug'] ?? data['homeTeamCode'] ?? '').toString(),
      awayTeamSlug:
          (data['awayTeamSlug'] ?? data['awayTeamCode'] ?? '').toString(),
      centerLabel: center,
      status: status,
    );
  }

  int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
