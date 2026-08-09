import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';
import 'package:derde_divisie/features/clubs/club_detail_screen.dart';

class DivisionScheduleMatrix extends StatelessWidget {
  const DivisionScheduleMatrix({super.key, required this.division});

  final String division;

  Future<_MatrixData> _load() async {
    final data = await const DivisionDataService().loadDivision(division);
    final matchMap = <String, Map<String, dynamic>>{};
    for (final match in data.matches) {
      final home = DivisionDataService.teamIdFromMatch(match.data, home: true);
      final away = DivisionDataService.teamIdFromMatch(match.data, home: false);
      if (home.isNotEmpty && away.isNotEmpty) {
        matchMap['$home|$away'] = match.data;
      }
    }
    return _MatrixData(teams: data.teams, matches: matchMap);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speelschema matrix', style: AppTextStyles.sectionTitle),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  'Rijen spelen thuis, kolommen uit. Scroll horizontaal voor alle clubs.',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          FutureBuilder<_MatrixData>(
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('De matrix kon niet worden geladen.'),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data!;
              if (data.teams.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('Geen teams beschikbaar voor deze divisie.'),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 142, height: 58),
                        for (final team in data.teams)
                          _ColumnHeader(team: team),
                      ],
                    ),
                    for (final home in data.teams)
                      Row(
                        children: [
                          _RowHeader(team: home),
                          for (final away in data.teams)
                            _MatrixCell(
                              home: home,
                              away: away,
                              match: data.matches['${home.id}|${away.id}'],
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.team});

  final DivisionTeam team;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: team.label,
      child: SizedBox(
        width: 64,
        height: 58,
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              team.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({required this.team});

  final DivisionTeam team;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ClubDetailScreen(teamSlug: team.id, teamName: team.label),
        ),
      ),
      child: SizedBox(
        width: 142,
        height: 42,
        child: Row(
          children: [
            Image.asset(
              team.logoPath,
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.shield_outlined, size: 24),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                team.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.home,
    required this.away,
    required this.match,
  });

  final DivisionTeam home;
  final DivisionTeam away;
  final Map<String, dynamic>? match;

  @override
  Widget build(BuildContext context) {
    final diagonal = home.id == away.id;
    final label = diagonal ? '' : _label(match);
    return Tooltip(
      message: diagonal
          ? home.label
          : '${home.label} - ${away.label}${label.isEmpty ? '' : ': $label'}',
      child: InkWell(
        onTap: diagonal
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClubDetailScreen(
                      teamSlug: home.id,
                      teamName: home.label,
                    ),
                  ),
                ),
        child: Container(
          width: 64,
          height: 42,
          decoration: BoxDecoration(
            color: diagonal ? AppColors.primaryDark : Colors.white,
            border: Border.all(color: AppColors.border, width: .5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: diagonal ? Colors.white : AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _label(Map<String, dynamic>? data) {
    if (data == null) return '–';
    final status = parseMatchStatus(data['status']);
    final homeScore = _int(data['homeScore'] ?? data['uitslagThuis']);
    final awayScore = _int(data['awayScore'] ?? data['uitslagUit']);
    if (status == MatchStatus.finished &&
        homeScore != null &&
        awayScore != null) {
      return '$homeScore-$awayScore';
    }
    if (status != MatchStatus.scheduled) return status.label;
    final date = MatchDateTimeFormatter.dateTimeFromData(data);
    return date == null ? '–' : '${date.day} ${_month(date.month)}';
  }

  int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _month(int month) {
    const months = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    return months[month - 1];
  }
}

class _MatrixData {
  const _MatrixData({required this.teams, required this.matches});

  final List<DivisionTeam> teams;
  final Map<String, Map<String, dynamic>> matches;
}
