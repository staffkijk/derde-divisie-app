import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_rows.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/data/services/analytics_service.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';
import 'package:derde_divisie/features/voorspellen/voorspel_een_team_screen.dart';

class ClubDetailScreen extends StatelessWidget {
  const ClubDetailScreen({
    super.key,
    required this.teamSlug,
    required this.teamName,
  });

  final String teamSlug;
  final String teamName;

  Future<_ClubData> _load() async {
    final source = await const DivisionDataService().loadClub(
      teamSlug: teamSlug,
      teamName: teamName,
    );
    final slug = source.team.id;
    final name = source.team.name;
    final matches =
        source.matches.map((match) => _ClubMatch(match.data)).toList();
    final standing = source.standing?.data;

    final upcoming = matches
        .where(
          (match) =>
              match.status == MatchStatus.scheduled ||
              match.status == MatchStatus.postponed,
        )
        .toList()
      ..sort((a, b) => MatchDateTimeFormatter.compare(a.data, b.data));
    final resultsOnly = matches
        .where((match) => match.status == MatchStatus.finished)
        .toList()
      ..sort((a, b) => MatchDateTimeFormatter.compare(b.data, a.data));
    final allMatches = [...matches]
      ..sort((a, b) => MatchDateTimeFormatter.compare(a.data, b.data));
    final balance = _balance(resultsOnly, slug, name);

    return _ClubData(
      name: name,
      division: source.division,
      logoPath: source.team.logoPath,
      position: source.position,
      divisionTeamCount: source.divisionTeamCount,
      standing: standing,
      nextMatch: upcoming.isEmpty ? null : upcoming.first,
      results: resultsOnly.take(5).toList(),
      allMatches: allMatches,
      balance: balance,
    );
  }

  _Balance _balance(List<_ClubMatch> results, String slug, String name) {
    var homeWins = 0;
    var homeDraws = 0;
    var homeLosses = 0;
    var awayWins = 0;
    var awayDraws = 0;
    var awayLosses = 0;
    final form = <String>[];
    for (final match in results.take(5).toList().reversed) {
      final data = match.data;
      final homeScore = _score(data['homeScore'] ?? data['uitslagThuis']);
      final awayScore = _score(data['awayScore'] ?? data['uitslagUit']);
      if (homeScore == null || awayScore == null) continue;
      final isHome = _isTeam(
        data['homeTeamSlug'] ?? data['homeTeamCode'],
        data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam'],
        slug,
        name,
      );
      final own = isHome ? homeScore : awayScore;
      final opponent = isHome ? awayScore : homeScore;
      final result = own > opponent
          ? 'W'
          : own == opponent
              ? 'G'
              : 'V';
      form.add(result);
      if (isHome) {
        if (result == 'W') homeWins++;
        if (result == 'G') homeDraws++;
        if (result == 'V') homeLosses++;
      } else {
        if (result == 'W') awayWins++;
        if (result == 'G') awayDraws++;
        if (result == 'V') awayLosses++;
      }
    }
    return _Balance(
      home: '$homeWins-$homeDraws-$homeLosses',
      away: '$awayWins-$awayDraws-$awayLosses',
      form: form,
    );
  }

  bool _isTeam(
    dynamic rawSlug,
    dynamic rawName,
    String slug,
    String name,
  ) {
    final configured = SeasonConfig.teamById(rawSlug?.toString() ?? '') ??
        SeasonConfig.teamByName(rawName?.toString() ?? '');
    return configured?.id == slug ||
        SeasonConfig.normalizeTeamKey(rawSlug?.toString() ?? '') ==
            SeasonConfig.normalizeTeamKey(slug) ||
        SeasonConfig.normalizeTeamKey(rawName?.toString() ?? '') ==
            SeasonConfig.normalizeTeamKey(name);
  }

  int? _score(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _setFavorite(BuildContext context, _ClubData club) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Log in om een favoriete club te kiezen.')),
      );
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'favoriteTeamSlug': SeasonConfig.teamByName(club.name)?.id ?? teamSlug,
      'favoriteTeamName': club.name,
      'favoriteDivision': club.division ?? FieldValue.delete(),
      'favorieteClub': club.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await ActivityLogService().log(
      eventType: ActivityEventType.favoriteTeamChanged,
      entityType: 'team',
      entityId: SeasonConfig.teamByName(club.name)?.id ?? teamSlug,
    );
    await AnalyticsService.instance.trackFavoriteClubSelected(
      team: SeasonConfig.teamByName(club.name)?.id ?? teamSlug,
      division: club.division,
      source: 'club_detail',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${club.name} is je favoriete club.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(teamName)),
      body: FutureBuilder<_ClubData>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Clubgegevens konden niet worden geladen.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final club = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: AppLayout.matchContentMaxWidth),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Image.asset(
                          club.logoPath,
                          width: 76,
                          height: 76,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield_outlined,
                            size: 68,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(club.name, style: AppTextStyles.pageTitle),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                club.division == null
                                    ? 'Divisie onbekend'
                                    : SeasonConfig.divisionName(club.division!),
                                style: AppTextStyles.bodyMuted,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _setFavorite(context, club),
                                    icon: const Icon(
                                      Icons.favorite_border,
                                      size: 18,
                                    ),
                                    label: const Text('Favoriete club'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: club.nextMatch == null
                                        ? null
                                        : () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    VoorspelEenTeamScreen(
                                                  team: club.name,
                                                  competition:
                                                      club.division ?? '',
                                                ),
                                              ),
                                            ),
                                    icon: const Icon(
                                      Icons.edit_calendar_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Voorspellen'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (club.position > 0 &&
                            club.position <= club.divisionTeamCount)
                          _Position(position: club.position),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (club.standing != null)
                    _StandingSummary(data: club.standing!),
                  if (club.standing != null)
                    const SizedBox(height: AppSpacing.md),
                  _BalanceCard(balance: club.balance),
                  const SizedBox(height: AppSpacing.md),
                  _MatchSection(
                    title: 'Volgende wedstrijd',
                    matches:
                        club.nextMatch == null ? const [] : [club.nextMatch!],
                    emptyText: 'Er is geen komende wedstrijd gevonden.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MatchSection(
                    title: 'Volledig programma',
                    matches: club.allMatches,
                    emptyText: 'Voor deze club zijn geen wedstrijden gevonden.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MatchSection(
                    title: 'Laatste uitslagen',
                    matches: club.results,
                    emptyText: 'Er zijn nog geen uitslagen beschikbaar.',
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

class _Position extends StatelessWidget {
  const _Position({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            '$position',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text('positie', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _StandingSummary extends StatelessWidget {
  const _StandingSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    int value(String primary, String fallback) {
      final raw = data[primary] ?? data[fallback];
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    final metrics = {
      'GS': value('played', 'gespeeld'),
      'W': value('wins', 'gewonnen'),
      'G': value('draws', 'gelijk'),
      'V': value('losses', 'verloren'),
      'Pnt': value('points', 'punten'),
      'DS': value('goalDifference', 'doelsaldo'),
    };
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.spaceAround,
        children: metrics.entries
            .map(
              (entry) => Column(
                children: [
                  Text(
                    '${entry.value}',
                    style: AppTextStyles.sectionTitle,
                  ),
                  Text(
                    entry.key,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final _Balance balance;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Thuis W-G-V: ${balance.home}'),
          Text('Uit W-G-V: ${balance.away}'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Vorm: '),
              for (final result in balance.form)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: result == 'W'
                        ? AppColors.primary
                        : result == 'G'
                            ? AppColors.warning
                            : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    result,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchSection extends StatelessWidget {
  const _MatchSection({
    required this.title,
    required this.matches,
    required this.emptyText,
  });

  final String title;
  final List<_ClubMatch> matches;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(title, style: AppTextStyles.sectionTitle),
          ),
          const Divider(height: 1),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(emptyText, style: AppTextStyles.bodyMuted),
            )
          else
            for (var index = 0; index < matches.length; index++) ...[
              PublicMatchRow(data: matches[index].rowData),
              if (index != matches.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _ClubMatch {
  _ClubMatch(this.data);

  final Map<String, dynamic> data;

  MatchStatus get status => parseMatchStatus(data['status']);

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

class _ClubData {
  const _ClubData({
    required this.name,
    required this.division,
    required this.logoPath,
    required this.position,
    required this.divisionTeamCount,
    required this.standing,
    required this.nextMatch,
    required this.results,
    required this.allMatches,
    required this.balance,
  });

  final String name;
  final String? division;
  final String logoPath;
  final int position;
  final int divisionTeamCount;
  final Map<String, dynamic>? standing;
  final _ClubMatch? nextMatch;
  final List<_ClubMatch> results;
  final List<_ClubMatch> allMatches;
  final _Balance balance;
}

class _Balance {
  const _Balance({
    required this.home,
    required this.away,
    required this.form,
  });

  final String home;
  final String away;
  final List<String> form;
}
