import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/config/team_logo_assets.dart';
import '../../data/config/season_config.dart';
import '../../data/firestore/season_paths.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/division_data_service.dart';
import '../../core/utils/match_formatters.dart';
import 'periode_standen_screen.dart';
import 'historical_standings_screen.dart';
import 'stand_derde_divisie_screen.dart';
import 'division_schedule_matrix.dart';

class DivisionOverviewScreen extends StatelessWidget {
  final String division;

  const DivisionOverviewScreen({super.key, required this.division});

  String get _shortDivision =>
      division.toLowerCase().contains(' b') ? 'B' : 'A';

  String get _title => 'Derde Divisie $_shortDivision';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1050;
            final horizontalPadding = isDesktop ? 24.0 : 14.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DivisionHeader(title: _title, division: division),
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _StandCard(
                                title: 'Stand $_shortDivision',
                                division: division,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _MatchesCard(
                                    title: 'Komende speelronde',
                                    subtitle:
                                        'Alle 9 wedstrijden zodra het programma bekend is.',
                                    division: division,
                                    mode: _MatchCardMode.upcoming,
                                  ),
                                  const SizedBox(height: 18),
                                  _MatchesCard(
                                    title: 'Laatste uitslagen',
                                    subtitle:
                                        'De 9 meest recente uitslagen van deze divisie.',
                                    division: division,
                                    mode: _MatchCardMode.results,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _StandCard(
                          title: 'Stand $_shortDivision',
                          division: division,
                        ),
                        const SizedBox(height: 14),
                        _MatchesCard(
                          title: 'Komende speelronde',
                          subtitle:
                              'Alle 9 wedstrijden zodra het programma bekend is.',
                          division: division,
                          mode: _MatchCardMode.upcoming,
                        ),
                        const SizedBox(height: 14),
                        _MatchesCard(
                          title: 'Laatste uitslagen',
                          subtitle:
                              'De 9 meest recente uitslagen van deze divisie.',
                          division: division,
                          mode: _MatchCardMode.results,
                        ),
                      ],
                      const SizedBox(height: 18),
                      DivisionScheduleMatrix(division: _shortDivision),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DivisionHeader extends StatelessWidget {
  final String title;
  final String division;

  const _DivisionHeader({
    required this.title,
    required this.division,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF153B2A),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stand, programma en uitslagen overzichtelijk per divisie.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ],
          );

          final periodButton = ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PeriodeStandenScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('Periodestanden'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F8F3B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );

          final archiveButton = OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoricalStandingsScreen(
                    initialDivision:
                        division.toLowerCase().contains(' b') ? 'B' : 'A',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Historische eindstanden'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                textBlock,
                const SizedBox(height: 14),
                periodButton,
                const SizedBox(height: 8),
                archiveButton,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: textBlock),
              const SizedBox(width: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  archiveButton,
                  periodButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StandCard extends StatefulWidget {
  final String title;
  final String division;

  const _StandCard({
    required this.title,
    required this.division,
  });

  @override
  State<_StandCard> createState() => _StandCardState();
}

class _StandCardState extends State<_StandCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.trackStandingsViewed(
        division: widget.division.toLowerCase().contains(' b') ? 'B' : 'A',
        source: 'division_overview',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.leaderboard_rounded,
            title: widget.title,
          ),
          const SizedBox(height: 4),
          Text(
            'Stand seizoen ${SeasonConfig.activeSeasonLabel}. De stand wordt bijgewerkt na verwerkte uitslagen.',
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          StandDerdeDivisie(
            divisie: widget.division,
            seizoen: kActueelSeizoenWaarde,
          ),
        ],
      ),
    );
  }
}

enum _MatchCardMode {
  upcoming,
  results,
}

class _MatchInfo {
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final DateTime? date;
  final bool played;
  final int round;
  final String status;
  final String homeTeamSlug;
  final String awayTeamSlug;

  const _MatchInfo({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.date,
    required this.played,
    required this.round,
    required this.status,
    required this.homeTeamSlug,
    required this.awayTeamSlug,
  });
}

class _MatchesCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String division;
  final _MatchCardMode mode;

  const _MatchesCard({
    required this.title,
    required this.subtitle,
    required this.division,
    required this.mode,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return SeasonPaths.currentSeasonMatches.snapshots();
  }

  String get _divisionCode => division.toLowerCase().contains(' b') ? 'B' : 'A';

  bool _matchesDivision(Map<String, dynamic> data) {
    return DivisionDataService.matchBelongsToDivision(data, _divisionCode);
  }

  List<_MatchInfo> _selectMatches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final matches = docs
        .where((doc) {
          if (doc.id == '_meta') return false;
          return _matchesDivision(doc.data());
        })
        .map((doc) {
          final data = doc.data();

          final homeScore = _asInt(
            data['homeScore'] ??
                data['scoreHome'] ??
                data['uitslagThuis'] ??
                data['scoreThuis'] ??
                data['goalsHome'] ??
                data['homeGoals'] ??
                data['thuisGoals'],
          );

          final awayScore = _asInt(
            data['awayScore'] ??
                data['scoreAway'] ??
                data['uitslagUit'] ??
                data['scoreUit'] ??
                data['goalsAway'] ??
                data['awayGoals'] ??
                data['uitGoals'],
          );

          final playedFlag = _asBool(
            data['verwerkt'] ??
                data['gespeeld'] ??
                data['isProcessed'] ??
                data['processed'] ??
                data['played'] ??
                data['isPlayed'],
          );

          final status = (data['status'] ??
                  data['matchStatus'] ??
                  data['statusLabel'] ??
                  data['state'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase();

          final playedByStatus = _isPlayedStatus(status);
          final scheduledByStatus = _isScheduledStatus(status);

          final played = playedFlag ??
              playedByStatus ||
                  (!scheduledByStatus &&
                      homeScore != null &&
                      awayScore != null);

          return _MatchInfo(
            homeTeam: _asTeamName(
              data['homeTeamName'] ??
                  data['homeTeam'] ??
                  data['thuisteam'] ??
                  data['thuisTeam'] ??
                  data['home'] ??
                  data['teamHome'],
            ),
            awayTeam: _asTeamName(
              data['awayTeamName'] ??
                  data['awayTeam'] ??
                  data['uitteam'] ??
                  data['uitTeam'] ??
                  data['away'] ??
                  data['teamAway'],
            ),
            homeScore: homeScore,
            awayScore: awayScore,
            date: _asDate(
              data['scheduledAt'] ??
                  data['date'] ??
                  data['datum'] ??
                  data['startTime'] ??
                  data['kickoff'] ??
                  data['matchDate'],
            ),
            played: played,
            round: _asInt(
                  data['round'] ??
                      data['speelronde'] ??
                      data['matchday'] ??
                      data['ronde'],
                ) ??
                999,
            status: status,
            homeTeamSlug:
                (data['homeTeamSlug'] ?? data['homeTeamCode'] ?? '').toString(),
            awayTeamSlug:
                (data['awayTeamSlug'] ?? data['awayTeamCode'] ?? '').toString(),
          );
        })
        .where((m) => m.homeTeam.isNotEmpty && m.awayTeam.isNotEmpty)
        .toList();

    if (mode == _MatchCardMode.upcoming) {
      final upcoming = matches
          .where(
            (m) =>
                !m.played &&
                (m.status == 'scheduled' || m.status == 'postponed'),
          )
          .toList()
        ..sort((a, b) {
          final roundCompare = a.round.compareTo(b.round);
          if (roundCompare != 0) return roundCompare;
          return _compareNullableDates(a.date, b.date);
        });

      if (upcoming.isEmpty) return [];

      final firstRound = upcoming.first.round;
      final sameRound = upcoming.where((m) => m.round == firstRound).toList();

      return sameRound.take(9).toList();
    }

    final results = matches.where((m) => m.played).toList()
      ..sort((a, b) {
        final dateCompare = _compareNullableDates(b.date, a.date);
        if (dateCompare != 0) return dateCompare;
        return b.round.compareTo(a.round);
      });

    return results.take(9).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: mode == _MatchCardMode.upcoming
                ? Icons.event_rounded
                : Icons.fact_check_rounded,
            title: title,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Kan wedstrijden nu niet laden.',
                  style: TextStyle(color: Colors.red.shade700),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final matches = _selectMatches(snapshot.data!.docs);

              if (matches.isEmpty) {
                return _EmptyMatchState(mode: mode);
              }

              return Column(
                children: [
                  for (var i = 0; i < matches.length; i++) ...[
                    if (i == 0 ||
                        !_sameDay(matches[i - 1].date, matches[i].date))
                      _MatchDayHeader(date: matches[i].date),
                    _MatchTile(
                      match: matches[i],
                      index: i + 1,
                      mode: mode,
                    ),
                    if (i != matches.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final _MatchInfo match;
  final int index;
  final _MatchCardMode mode;

  const _MatchTile({
    required this.match,
    required this.index,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final scoreKnown = match.homeScore != null && match.awayScore != null;
    final dateLabel = _formatMatchDate(match.date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MiniLogo(team: match.homeTeam, slug: match.homeTeamSlug),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${match.homeTeam} - ${match.awayTeam}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1D1D1D),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _MiniLogo(team: match.awayTeam, slug: match.awayTeamSlug),
                  ],
                ),
                if (dateLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 54),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: mode == _MatchCardMode.results && scoreKnown
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF4F6F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E7DE)),
            ),
            alignment: Alignment.center,
            child: Text(
              match.status == 'postponed'
                  ? 'In te halen'
                  : match.status == 'cancelled'
                      ? 'Afgelast'
                      : match.status == 'abandoned'
                          ? 'Gestaakt'
                          : scoreKnown
                              ? '${match.homeScore}-${match.awayScore}'
                              : 'vs',
              style: const TextStyle(
                color: Color(0xFF153B2A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo({required this.team, required this.slug});

  final String team;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final asset =
        teamLogoAssetFromValues([slug, team]) ?? kDefaultTeamLogoAsset;
    return Image.asset(
      asset,
      width: 22,
      height: 22,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.shield_outlined,
        size: 20,
        color: Color(0xFF2F8F3B),
      ),
    );
  }
}

class _MatchDayHeader extends StatelessWidget {
  const _MatchDayHeader({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFFF3F6F1),
      child: Text(
        MatchDateTimeFormatter.dayHeader(date!),
        style: const TextStyle(
          color: Color(0xFF153B2A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyMatchState extends StatelessWidget {
  final _MatchCardMode mode;

  const _EmptyMatchState({required this.mode});

  @override
  Widget build(BuildContext context) {
    final text = mode == _MatchCardMode.upcoming
        ? 'Nog geen komend programma gevonden voor deze divisie.'
        : 'Nog geen uitslagen gevonden voor deze divisie.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9E2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ShellCard extends StatelessWidget {
  final Widget child;

  const _ShellCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E9E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2F8F3B),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF153B2A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  return int.tryParse(text);
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value.toString().toLowerCase().trim();

  if (text == 'true' ||
      text == 'ja' ||
      text == 'yes' ||
      text == '1' ||
      text == 'gespeeld' ||
      text == 'verwerkt' ||
      text == 'finished' ||
      text == 'played' ||
      text == 'final' ||
      text == 'ft') {
    return true;
  }

  if (text == 'false' ||
      text == 'nee' ||
      text == 'no' ||
      text == '0' ||
      text == 'scheduled' ||
      text == 'programma' ||
      text == 'niet gespeeld') {
    return false;
  }

  return null;
}

bool _isPlayedStatus(String status) {
  return status == 'finished' ||
      status == 'played' ||
      status == 'final' ||
      status == 'fulltime' ||
      status == 'full time' ||
      status == 'ft' ||
      status == 'afgelopen' ||
      status == 'gespeeld' ||
      status == 'verwerkt' ||
      status == 'definitief';
}

bool _isScheduledStatus(String status) {
  return status == 'scheduled' ||
      status == 'programma' ||
      status == 'fixture' ||
      status == 'planned' ||
      status == 'gepland' ||
      status == 'niet gespeeld' ||
      status == 'upcoming';
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
  }

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  return DateTime.tryParse(text);
}

String _asTeamName(dynamic value) {
  if (value == null) return '';

  if (value is Map) {
    final name = value['name'] ??
        value['teamName'] ??
        value['clubName'] ??
        value['displayName'] ??
        value['label'] ??
        value['shortName'];

    return name?.toString().trim() ?? '';
  }

  return value.toString().trim();
}

int _compareNullableDates(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;

  return a.compareTo(b);
}

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == b;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatMatchDate(DateTime? date) {
  if (date == null) return '';

  final format = DateFormat('EEE d MMM HH:mm', 'nl_NL');
  return format.format(date);
}
