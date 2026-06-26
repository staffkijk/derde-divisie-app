import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'periode_standen_screen.dart';
import 'stand_derde_divisie_screen.dart';

class DivisionOverviewScreen extends StatelessWidget {
  final String division;

  const DivisionOverviewScreen({super.key, required this.division});

  String get _shortDivision => division.toLowerCase().contains(' b') ? 'B' : 'A';
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
                                    subtitle: 'Alle 9 wedstrijden zodra het programma bekend is.',
                                    division: division,
                                    mode: _MatchCardMode.upcoming,
                                  ),
                                  const SizedBox(height: 18),
                                  _MatchesCard(
                                    title: 'Laatste uitslagen',
                                    subtitle: 'De 9 meest recente uitslagen van deze divisie.',
                                    division: division,
                                    mode: _MatchCardMode.results,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _StandCard(title: 'Stand $_shortDivision', division: division),
                        const SizedBox(height: 14),
                        _MatchesCard(
                          title: 'Komende speelronde',
                          subtitle: 'Alle 9 wedstrijden zodra het programma bekend is.',
                          division: division,
                          mode: _MatchCardMode.upcoming,
                        ),
                        const SizedBox(height: 14),
                        _MatchesCard(
                          title: 'Laatste uitslagen',
                          subtitle: 'De 9 meest recente uitslagen van deze divisie.',
                          division: division,
                          mode: _MatchCardMode.results,
                        ),
                      ],
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

  const _DivisionHeader({required this.title, required this.division});

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

          final button = ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PeriodeStandenScreen()),
              );
            },
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('Periodestanden'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F8F3B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                textBlock,
                const SizedBox(height: 14),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: textBlock),
              const SizedBox(width: 14),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _StandCard extends StatelessWidget {
  final String title;
  final String division;

  const _StandCard({required this.title, required this.division});

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.leaderboard_rounded, title: title),
          const SizedBox(height: 4),
          Text(
            'Voorlopige deelnemerslijst seizoen 2026/2027. De stand wordt automatisch gevuld zodra er uitslagen zijn verwerkt.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.3),
          ),
          const SizedBox(height: 10),
          StandDerdeDivisie(
            divisie: division,
            seizoen: kActueelSeizoenWaarde,
          ),
        ],
      ),
    );
  }
}

enum _MatchCardMode { upcoming, results }

class _MatchInfo {
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final DateTime? date;
  final bool played;

  const _MatchInfo({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.date,
    required this.played,
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
    return FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: division)
        .snapshots();
  }

  List<_MatchInfo> _selectMatches(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final matches = docs.map((doc) {
      final data = doc.data();
      final homeScore = _asInt(data['uitslagThuis'] ?? data['scoreThuis']);
      final awayScore = _asInt(data['uitslagUit'] ?? data['scoreUit']);
      final playedFlag = _asBool(data['verwerkt'] ?? data['gespeeld'] ?? data['isProcessed']);
      final played = playedFlag ?? (homeScore != null && awayScore != null);

      return _MatchInfo(
        homeTeam: _asTeamName(data['thuisteam'] ?? data['homeTeam'] ?? data['thuisTeam']),
        awayTeam: _asTeamName(data['uitteam'] ?? data['awayTeam'] ?? data['uitTeam']),
        homeScore: homeScore,
        awayScore: awayScore,
        date: _asDate(data['datum'] ?? data['date'] ?? data['startTime']),
        played: played,
      );
    }).where((m) => m.homeTeam.isNotEmpty || m.awayTeam.isNotEmpty).toList();

    if (mode == _MatchCardMode.upcoming) {
      final upcoming = matches.where((m) => !m.played).toList()
        ..sort((a, b) => _compareNullableDates(a.date, b.date));
      return upcoming.take(9).toList();
    }

    final results = matches.where((m) => m.played).toList()
      ..sort((a, b) => _compareNullableDates(b.date, a.date));
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
            style: TextStyle(color: Colors.grey.shade700, height: 1.3),
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
                    _MatchTile(
                      match: matches[i],
                      index: i + 1,
                      mode: mode,
                    ),
                    if (i != matches.length - 1)
                      Divider(height: 1, color: Colors.grey.shade200),
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
                Text(
                  '${match.homeTeam} - ${match.awayTeam}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1D1D1D),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (dateLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      dateLabel,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 54),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: mode == _MatchCardMode.results && scoreKnown
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF4F6F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E7DE)),
            ),
            alignment: Alignment.center,
            child: Text(
              scoreKnown ? '${match.homeScore}-${match.awayScore}' : 'vs',
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
        style: TextStyle(color: Colors.grey.shade700, height: 1.35),
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

  const _SectionTitle({required this.icon, required this.title});

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
          child: Icon(icon, color: const Color(0xFF2F8F3B), size: 20),
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
  return int.tryParse(value.toString());
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().toLowerCase().trim();
  if (text == 'true' || text == 'ja' || text == 'yes' || text == '1') return true;
  if (text == 'false' || text == 'nee' || text == 'no' || text == '0') return false;
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _asTeamName(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text;
}

int _compareNullableDates(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

String _formatMatchDate(DateTime? date) {
  if (date == null) return '';
  final format = DateFormat('EEE d MMM HH:mm', 'nl_NL');
  return format.format(date);
}
