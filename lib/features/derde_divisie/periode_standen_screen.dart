import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:derde_divisie/data/config/season_config.dart';

final Logger _log = Logger('PeriodeStanden');

class PeriodeStandenScreen extends StatelessWidget {
  const PeriodeStandenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F4),
        appBar: AppBar(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 1,
          title: const Text('Periodestanden'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Divisie A'),
              Tab(text: 'Divisie B'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PeriodeDivisionView(division: SeasonConfig.divisionA),
            _PeriodeDivisionView(division: SeasonConfig.divisionB),
          ],
        ),
      ),
    );
  }
}

class _PeriodeDivisionView extends StatefulWidget {
  const _PeriodeDivisionView({
    required this.division,
  });

  final String division;

  @override
  State<_PeriodeDivisionView> createState() => _PeriodeDivisionViewState();
}

class _PeriodeDivisionViewState extends State<_PeriodeDivisionView> {
  int _selectedPeriod = 1;

  @override
  Widget build(BuildContext context) {
    final divisionName = SeasonConfig.divisionName(widget.division);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final horizontalPadding = isWide ? 32.0 : 16.0;
        final maxContentWidth = isWide ? 1180.0 : double.infinity;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                24,
              ),
              children: [
                _HeaderCard(
                  title: divisionName,
                  subtitle:
                      'Seizoen ${SeasonConfig.activeSeasonLabel} · periodestanden',
                ),
                const SizedBox(height: 14),
                _PeriodSelector(
                  selectedPeriod: _selectedPeriod,
                  onChanged: (period) {
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _PeriodeStandCard(
                  division: widget.division,
                  period: _selectedPeriod,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.leaderboard_outlined,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final int selectedPeriod;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: List.generate(3, (index) {
            final period = index + 1;
            final selected = period == selectedPeriod;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Periode $period',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PeriodeStandCard extends StatelessWidget {
  const _PeriodeStandCard({
    required this.division,
    required this.period,
  });

  final String division;
  final int period;

  @override
  Widget build(BuildContext context) {
    final divisionName = SeasonConfig.divisionName(division);
    final teams = SeasonConfig.teamsForDivision(division);

    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('seasons')
              .doc(SeasonConfig.activeSeasonId)
              .collection('periodStandings')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _log.warning(
                'Fout bij laden periodestand periode $period $divisionName: ${snapshot.error}',
              );

              return const _ErrorState();
            }

            if (!snapshot.hasData) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final rows = _buildRows(
              docs: snapshot.data!.docs,
              teams: teams,
              division: division,
              period: period,
            );

            final hasPlayedMatches = rows.any((row) => row.played > 0);

            if (!hasPlayedMatches) {
              return _EmptyState(
                title: 'Nog geen periodestand beschikbaar',
                message:
                    'De stand voor periode $period in $divisionName wordt zichtbaar zodra er wedstrijden zijn verwerkt.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TableTitle(
                  title: 'Periode $period',
                  subtitle: divisionName,
                ),
                const SizedBox(height: 12),
                _StandTable(rows: rows),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_PeriodStandingRow> _buildRows({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required List<SeasonTeam> teams,
    required String division,
    required int period,
  }) {
    final normalizedDivision = SeasonConfig.normalizeDivisionCode(division);

    final Map<String, Map<String, dynamic>> dataByTeamKey = {};

    for (final doc in docs) {
      final data = doc.data();

      final docPeriod = _readInt(data, const [
        'period',
        'periode',
        'periodNumber',
        'periodeNummer',
      ]);

      if (docPeriod != period) {
        continue;
      }

      final docDivisionRaw = _readString(data, const [
        'division',
        'divisie',
        'divisionCode',
        'divisieCode',
        'competition',
        'competitie',
      ]);

      if (docDivisionRaw.isNotEmpty) {
        final docDivision = SeasonConfig.normalizeDivisionCode(docDivisionRaw);
        if (docDivision != normalizedDivision) {
          continue;
        }
      }

      final possibleKeys = <String>[
        doc.id,
        _teamKeyFromPeriodDocId(doc.id),
        _readString(data, const ['teamId', 'team_id', 'id']),
        _readString(data, const ['teamName', 'club', 'clubNaam', 'name']),
      ];

      for (final key in possibleKeys) {
        if (key.trim().isEmpty) {
          continue;
        }

        dataByTeamKey[SeasonConfig.normalizeTeamKey(key)] = data;
      }
    }

    final rows = teams.map((team) {
      final data = dataByTeamKey[SeasonConfig.normalizeTeamKey(team.id)] ??
          dataByTeamKey[SeasonConfig.normalizeTeamKey(team.name)] ??
          dataByTeamKey[SeasonConfig.normalizeTeamKey(team.label)];

      final goalsFor = _readInt(data, const [
        'goalsFor',
        'doelpuntenVoor',
        'voor',
        'dv',
      ]);

      final goalsAgainst = _readInt(data, const [
        'goalsAgainst',
        'doelpuntenTegen',
        'tegen',
        'dt',
      ]);

      final goalDifference = _readNullableInt(data, const [
            'goalDifference',
            'doelsaldo',
            'saldo',
            'ds',
          ]) ??
          goalsFor - goalsAgainst;

      return _PeriodStandingRow(
        team: team,
        played: _readInt(data, const [
          'played',
          'matchesPlayed',
          'gespeeld',
          'wedstrijden',
          'g',
        ]),
        won: _readInt(data, const [
          'won',
          'gewonnen',
          'w',
        ]),
        drawn: _readInt(data, const [
          'drawn',
          'gelijk',
          'draw',
        ]),
        lost: _readInt(data, const [
          'lost',
          'verloren',
          'v',
        ]),
        points: _readInt(data, const [
          'points',
          'punten',
          'pnt',
        ]),
        goalsFor: goalsFor,
        goalsAgainst: goalsAgainst,
        goalDifference: goalDifference,
      );
    }).toList();

    rows.sort((a, b) {
      if (a.points != b.points) {
        return b.points.compareTo(a.points);
      }

      if (a.played != b.played) {
        return a.played.compareTo(b.played);
      }

      if (a.goalDifference != b.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }

      if (a.goalsFor != b.goalsFor) {
        return b.goalsFor.compareTo(a.goalsFor);
      }

      if (a.goalsAgainst != b.goalsAgainst) {
        return a.goalsAgainst.compareTo(b.goalsAgainst);
      }

      return a.team.label.compareTo(b.team.label);
    });

    return rows;
  }

  static String _teamKeyFromPeriodDocId(String docId) {
    return docId.replaceFirst(RegExp(r'^p[123]_'), '');
  }

  static String _readString(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) {
      return '';
    }

    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  static int _readInt(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    return _readNullableInt(data, keys) ?? 0;
  }

  static int? _readNullableInt(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) {
      return null;
    }

    for (final key in keys) {
      final value = data[key];

      if (value == null) {
        continue;
      }

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      final parsed = int.tryParse(value.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }
}

class _TableTitle extends StatelessWidget {
  const _TableTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$title · $subtitle',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          SeasonConfig.activeSeasonLabel,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StandTable extends StatelessWidget {
  const _StandTable({
    required this.rows,
  });

  final List<_PeriodStandingRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 54,
              columnSpacing: 18,
              horizontalMargin: 10,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Club')),
                DataColumn(numeric: true, label: Text('G')),
                DataColumn(numeric: true, label: Text('W')),
                DataColumn(numeric: true, label: Text('G')),
                DataColumn(numeric: true, label: Text('V')),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Pnt',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                DataColumn(numeric: true, label: Text('DS')),
                DataColumn(numeric: true, label: Text('DV-DT')),
              ],
              rows: List.generate(rows.length, (index) {
                final row = rows[index];
                final isLeader = index == 0;

                return DataRow(
                  color: isLeader
                      ? WidgetStateProperty.all(Colors.green.shade50)
                      : null,
                  cells: [
                    DataCell(
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight:
                              isLeader ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                    DataCell(
                      _TeamCell(team: row.team),
                    ),
                    DataCell(Text('${row.played}')),
                    DataCell(Text('${row.won}')),
                    DataCell(Text('${row.drawn}')),
                    DataCell(Text('${row.lost}')),
                    DataCell(
                      Text(
                        '${row.points}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text('${row.goalDifference}')),
                    DataCell(Text('${row.goalsFor}-${row.goalsAgainst}')),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _TeamCell extends StatelessWidget {
  const _TeamCell({
    required this.team,
  });

  final SeasonTeam team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            team.logoPath,
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/default_logo.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            team.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 48,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Text(
          'Fout bij laden van de periodestand.',
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PeriodStandingRow {
  const _PeriodStandingRow({
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
  });

  final SeasonTeam team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int points;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
}
