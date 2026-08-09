import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_rows.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
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
                      'DerdeDiv · ${SeasonConfig.activeSeasonLabel}',
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
    required this.onOpenPredict,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenPredict;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 64,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snapshot.data?.data();
        final favoriteName =
            (data?['favoriteTeamName'] ?? data?['favorieteClub'] ?? '')
                .toString();
        final team = SeasonConfig.teamById(
              (data?['favoriteTeamSlug'] ?? '').toString(),
            ) ??
            SeasonConfig.teamByName(favoriteName);
        if (team == null) {
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              onTap: onOpenProfile,
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: AppColors.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Kies je favoriete club')),
                ],
              ),
            ),
          );
        }

        void openClub() => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClubDetailScreen(
                  teamSlug: team.id,
                  teamName: team.label,
                ),
              ),
            );

        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 650;
              final info = Expanded(
                child: mobile
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${team.label} · ${SeasonConfig.divisionName(team.division)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          _FavoriteMatchSummary(team: team),
                        ],
                      )
                    : Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${team.label} · ${SeasonConfig.divisionName(team.division)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('|', style: AppTextStyles.bodyMuted),
                          ),
                          Expanded(child: _FavoriteMatchSummary(team: team)),
                        ],
                      ),
              );
              return Row(
                children: [
                  TeamLogo(teamSlug: team.id, teamName: team.label, size: 36),
                  const SizedBox(width: 10),
                  info,
                  if (!mobile) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: openClub,
                      child: const Text('Clubpagina'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: onOpenPredict,
                      child: const Text('Voorspellen'),
                    ),
                  ],
                  PopupMenuButton<String>(
                    tooltip: 'Meer acties',
                    onSelected: (value) {
                      if (value == 'club') openClub();
                      if (value == 'predict') onOpenPredict();
                      if (value == 'change') onOpenProfile();
                    },
                    itemBuilder: (_) => [
                      if (mobile)
                        const PopupMenuItem(
                            value: 'club', child: Text('Clubpagina')),
                      if (mobile)
                        const PopupMenuItem(
                            value: 'predict', child: Text('Voorspellen')),
                      const PopupMenuItem(
                          value: 'change', child: Text('Wijzig club')),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
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
        return _line(
          'Volgende',
          upcoming.isEmpty
              ? 'Geen komende wedstrijd'
              : _description(upcoming.first),
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
