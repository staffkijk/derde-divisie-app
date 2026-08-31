// lib/screens/stand_derde_divisie.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';
import 'periode_standen_screen.dart';
import 'package:derde_divisie/data/config/team_logo_assets.dart';

final Logger _log = Logger('StandDerdeDivisie');

const String kActueelSeizoenLabel = 'Actueel seizoen';
const String kActueelSeizoenWaarde = 'actueel';

const List<String> kArchiefSeizoenen = [
  '2025-2026',
  '2024-2025',
  '2023-2024',
  '2022-2023',
  '2021-2022',
  '2020-2021',
  '2019-2020',
  '2018-2019',
  '2017-2018',
  '2016-2017',
];

const Map<String, List<String>> kPeriodeKampioenen = {
  'Derde Divisie A': [],
  'Derde Divisie B': [],
};

String _normName(String s) {
  return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int _calcDoelsaldo(Map<String, dynamic> d) {
  final ds = d['doelsaldo'] ?? d['goalDifference'];
  if (ds != null) return _toInt(ds);

  final dv = _toInt(
    d['doelpuntenVoor'] ?? d['goalsFor'] ?? d['dv'],
  );

  final dt = _toInt(
    d['doelpuntenTegen'] ?? d['goalsAgainst'] ?? d['dt'],
  );

  return dv - dt;
}

String _divisieCode(String divisie) {
  if (divisie.toLowerCase().contains(' b')) return 'B';
  return 'A';
}

Map<String, List<String>> berekenVormPerTeam(
  List<Map<String, dynamic>> matches,
) {
  final perTeam = <String, List<Map<String, dynamic>>>{};

  String teamKey(Map<String, dynamic> match, bool home) {
    final id = (match[home ? 'homeTeamId' : 'awayTeamId'] ??
            match[home ? 'homeClubId' : 'awayClubId'] ??
            '')
        .toString();
    final byId = id.isEmpty ? null : SeasonConfig.teamById(id);
    final raw = (match[home ? 'homeTeamName' : 'awayTeamName'] ??
            match[home ? 'homeTeam' : 'awayTeam'] ??
            match[home ? 'thuisteam' : 'uitteam'] ??
            match[home ? 'homeTeamCode' : 'awayTeamCode'] ??
            id)
        .toString();
    final team = byId ?? SeasonConfig.teamByName(raw);
    return _normName(team?.listLabel ?? raw);
  }

  int? score(Map<String, dynamic> match, bool home) {
    final value = match[home ? 'homeScore' : 'awayScore'] ??
        match[home ? 'uitslagThuis' : 'uitslagUit'] ??
        match[home ? 'thuisScore' : 'uitScore'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime date(Map<String, dynamic> match) {
    final value = match['kickoff'] ?? match['datum'] ?? match['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(2000);
  }

  for (final match in matches) {
    final status = (match['status'] ?? '').toString().toLowerCase();
    if (const {'postponed', 'cancelled', 'canceled', 'abandoned'}
        .contains(status)) {
      continue;
    }
    final homeScore = score(match, true);
    final awayScore = score(match, false);
    if (homeScore == null || awayScore == null) continue;
    final home = teamKey(match, true);
    final away = teamKey(match, false);
    if (home.isEmpty || away.isEmpty) continue;

    void add(String key, int own, int other) {
      perTeam.putIfAbsent(key, () => []).add({
        'datum': date(match),
        'result': own > other
            ? 'W'
            : own < other
                ? 'V'
                : 'G',
      });
    }

    add(home, homeScore, awayScore);
    add(away, awayScore, homeScore);
  }

  return {
    for (final entry in perTeam.entries)
      entry.key: ((entry.value
                ..sort((a, b) =>
                    (a['datum'] as DateTime).compareTo(b['datum'] as DateTime)))
              .reversed
              .take(5)
              .toList()
              .reversed)
          .map((value) => value['result'] as String)
          .toList(),
  };
}

class StandEntry {
  final Map<String, dynamic> data;
  final String naam;
  final String code;
  final String docCode;
  final String? logoAsset;
  final int positie;
  final int gespeeld;
  final int gewonnen;
  final int gelijk;
  final int verloren;
  final int punten;
  final int doelpuntenVoor;
  final int doelpuntenTegen;
  final int doelsaldo;

  const StandEntry({
    required this.data,
    required this.naam,
    required this.code,
    required this.docCode,
    required this.logoAsset,
    required this.positie,
    required this.gespeeld,
    required this.gewonnen,
    required this.gelijk,
    required this.verloren,
    required this.punten,
    required this.doelpuntenVoor,
    required this.doelpuntenTegen,
    required this.doelsaldo,
  });

  factory StandEntry.fromSeasonTeam(SeasonTeam team) {
    return StandEntry(
      data: const {},
      naam: team.listLabel,
      code: _normName(team.listLabel),
      docCode: _normName(team.listLabel),
      logoAsset: team.logoPath,
      positie: 0,
      gespeeld: 0,
      gewonnen: 0,
      gelijk: 0,
      verloren: 0,
      punten: 0,
      doelpuntenVoor: 0,
      doelpuntenTegen: 0,
      doelsaldo: 0,
    );
  }

  factory StandEntry.fromDivisionTeam(DivisionTeam team) {
    return StandEntry(
      data: const {},
      naam: team.shortName,
      code: _normName(team.name),
      docCode: _normName(team.id),
      logoAsset: team.logoPath,
      positie: 0,
      gespeeld: 0,
      gewonnen: 0,
      gelijk: 0,
      verloren: 0,
      punten: 0,
      doelpuntenVoor: 0,
      doelpuntenTegen: 0,
      doelsaldo: 0,
    );
  }

  factory StandEntry.fromCurrentStandingDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final naam = (data['teamName'] ??
            data['name'] ??
            data['team'] ??
            SeasonConfig.teamById((data['teamId'] ?? doc.id).toString())
                ?.listLabel ??
            doc.id)
        .toString();
    final team = SeasonConfig.teamByName(naam) ??
        SeasonConfig.teamById((data['teamId'] ?? doc.id).toString());

    return StandEntry(
      data: data,
      naam: team?.listLabel ?? naam,
      code: _normName(team?.listLabel ?? naam),
      docCode: _normName((data['teamId'] ?? data['id'] ?? doc.id).toString()),
      logoAsset: teamLogoAssetFromValues([
        data['logoAsset'],
        team?.logoPath,
        team?.listLabel,
        naam,
        data['teamName'],
        data['name'],
        data['team'],
        data['club'],
        data['teamId'],
        data['id'],
        doc.id,
      ]),
      positie: _toInt(data['position'] ?? data['positie'] ?? data['rank']),
      gespeeld: _toInt(data['played'] ?? data['gespeeld']),
      gewonnen: _toInt(data['wins'] ?? data['won'] ?? data['gewonnen']),
      gelijk: _toInt(data['draws'] ?? data['drawn'] ?? data['gelijk']),
      verloren: _toInt(data['losses'] ?? data['lost'] ?? data['verloren']),
      punten: _toInt(data['points'] ?? data['punten']),
      doelpuntenVoor: _toInt(
        data['goalsFor'] ?? data['doelpuntenVoor'] ?? data['dv'],
      ),
      doelpuntenTegen: _toInt(
        data['goalsAgainst'] ?? data['doelpuntenTegen'] ?? data['dt'],
      ),
      doelsaldo: _calcDoelsaldo(data),
    );
  }

  factory StandEntry.fromArchiveDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final naam =
        (data['teamName'] ?? data['name'] ?? data['team'] ?? data['club'] ?? '')
            .toString();
    final team = SeasonConfig.teamByName(naam) ??
        SeasonConfig.teamById(
            (data['teamId'] ?? data['id'] ?? doc.id).toString());

    return StandEntry(
      data: data,
      naam: team?.listLabel ?? naam,
      code: _normName(team?.listLabel ?? naam),
      docCode: _normName(doc.id),
      logoAsset: teamLogoAssetFromValues([
        data['logoAsset'],
        team?.logoPath,
        team?.listLabel,
        naam,
        data['teamName'],
        data['name'],
        data['team'],
        data['club'],
        data['teamId'],
        data['id'],
        doc.id,
      ]),
      positie: _toInt(data['position'] ?? data['positie']),
      gespeeld: _toInt(data['played'] ?? data['gespeeld']),
      gewonnen: _toInt(data['won'] ?? data['wins'] ?? data['gewonnen']),
      gelijk: _toInt(data['drawn'] ?? data['draws'] ?? data['gelijk']),
      verloren: _toInt(data['lost'] ?? data['losses'] ?? data['verloren']),
      punten: _toInt(data['points'] ?? data['punten']),
      doelpuntenVoor: _toInt(
        data['goalsFor'] ?? data['doelpuntenVoor'] ?? data['dv'],
      ),
      doelpuntenTegen: _toInt(
        data['goalsAgainst'] ?? data['doelpuntenTegen'] ?? data['dt'],
      ),
      doelsaldo: _calcDoelsaldo(data),
    );
  }
}

class VormVakjes extends StatefulWidget {
  final List<String> vorm;
  final bool compact;

  const VormVakjes({
    super.key,
    required this.vorm,
    this.compact = false,
  });

  @override
  State<VormVakjes> createState() => _VormVakjesState();
}

class _VormVakjesState extends State<VormVakjes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _kleur(String v) {
    switch (v) {
      case 'W':
        return Colors.green;
      case 'G':
        return Colors.orange;
      case 'V':
        return Colors.red;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 9.0 : 12.0;

    return FadeTransition(
      opacity: _opacity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: widget.vorm.map((v) {
          return Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _kleur(v).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StandDerdeDivisieScreen extends StatefulWidget {
  const StandDerdeDivisieScreen({super.key});

  @override
  State<StandDerdeDivisieScreen> createState() =>
      _StandDerdeDivisieScreenState();
}

class _StandDerdeDivisieScreenState extends State<StandDerdeDivisieScreen> {
  String _selectedSeason = kActueelSeizoenWaarde;

  bool get _isActueel => _selectedSeason == kActueelSeizoenWaarde;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 10,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text(
                    'Bekijk periodestanden',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PeriodeStandenScreen(),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSeason,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: [
                        const DropdownMenuItem(
                          value: kActueelSeizoenWaarde,
                          child: Text(kActueelSeizoenLabel),
                        ),
                        ...kArchiefSeizoenen.map(
                          (season) => DropdownMenuItem(
                            value: season,
                            child: Text(season),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedSeason = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 12,
            ),
            child: Text(
              _isActueel
                  ? 'Voorlopige deelnemerslijst seizoen 2026/2027'
                  : 'Eindstand seizoen $_selectedSeason',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!isWide) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Voorlopige lijst A',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            StandDerdeDivisie(
              divisie: 'Derde Divisie A',
              seizoen: _selectedSeason,
            ),
            const Divider(thickness: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Voorlopige lijst B',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            StandDerdeDivisie(
              divisie: 'Derde Divisie B',
              seizoen: _selectedSeason,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isActueel ? 'Voorlopige lijst A' : 'Stand Divisie A',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StandDerdeDivisie(
                          divisie: 'Derde Divisie A',
                          seizoen: _selectedSeason,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 700,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isActueel ? 'Voorlopige lijst B' : 'Stand Divisie B',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StandDerdeDivisie(
                          divisie: 'Derde Divisie B',
                          seizoen: _selectedSeason,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StandDerdeDivisie extends StatelessWidget {
  final String divisie;
  final String seizoen;

  const StandDerdeDivisie({
    super.key,
    required this.divisie,
    required this.seizoen,
  });

  bool get _isActueel => seizoen == kActueelSeizoenWaarde;

  Stream<QuerySnapshot<Map<String, dynamic>>> _currentStandStream() {
    return SeasonPaths.currentSeasonStandings.snapshots();
  }

  Stream<QuerySnapshot> _archiveStandStream() {
    return FirebaseFirestore.instance
        .collection('standings_archive')
        .doc(seizoen)
        .collection('divisions')
        .doc(_divisieCode(divisie))
        .collection('teams')
        .snapshots();
  }

  Future<Map<String, List<String>>> _vormMapFuture() async {
    if (!_isActueel) return {};
    final data = await const DivisionDataService().loadDivision(divisie);
    return berekenVormPerTeam(
      data.matches.map((match) => match.data).toList(),
    );
  }

  bool _matchesDivision(Map<String, dynamic> data) {
    final rawDivision =
        (data['division'] ?? data['divisie'] ?? data['competition'] ?? '')
            .toString()
            .trim();

    if (rawDivision.isEmpty) return false;

    return SeasonConfig.normalizeDivisionCode(rawDivision) ==
        SeasonConfig.normalizeDivisionCode(divisie);
  }

  List<StandEntry> _buildCurrentSeasonEntriesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final entries = docs
        .where((doc) {
          if (doc.id == '_meta') return false;
          return _matchesDivision(doc.data());
        })
        .map(StandEntry.fromCurrentStandingDoc)
        .where((entry) {
          return entry.naam.trim().isNotEmpty;
        })
        .toList();

    entries.sort((a, b) {
      int c;

      c = b.punten.compareTo(a.punten);
      if (c != 0) return c;

      c = b.doelsaldo.compareTo(a.doelsaldo);
      if (c != 0) return c;

      c = b.doelpuntenVoor.compareTo(a.doelpuntenVoor);
      if (c != 0) return c;

      return a.naam.compareTo(b.naam);
    });

    return entries;
  }

  List<StandEntry> _buildArchiveEntries(List<QueryDocumentSnapshot> docs) {
    final entries = docs.map(StandEntry.fromArchiveDoc).where((entry) {
      return entry.naam.trim().isNotEmpty;
    }).toList();

    entries.sort((a, b) {
      if (a.positie > 0 && b.positie > 0) {
        return a.positie.compareTo(b.positie);
      }

      int c;

      c = b.punten.compareTo(a.punten);
      if (c != 0) return c;

      c = a.gespeeld.compareTo(b.gespeeld);
      if (c != 0) return c;

      c = b.doelsaldo.compareTo(a.doelsaldo);
      if (c != 0) return c;

      c = b.doelpuntenVoor.compareTo(a.doelpuntenVoor);
      if (c != 0) return c;

      return a.naam.compareTo(b.naam);
    });

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (_isActueel) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _currentStandStream(),
        builder: (context, standSnap) {
          if (standSnap.hasError) {
            _log.warning(
              'Firestore-fout bij laden actuele stand: ${standSnap.error}',
            );
          }

          if (!standSnap.hasData && !standSnap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }

          final seasonEntries = standSnap.hasData
              ? _buildCurrentSeasonEntriesFromDocs(standSnap.data!.docs)
              : <StandEntry>[];
          return FutureBuilder<DivisionData?>(
            future: seasonEntries.isEmpty
                ? const DivisionDataService()
                    .loadDivision(divisie)
                    .then<DivisionData?>((value) => value)
                : Future<DivisionData?>.value(),
            builder: (context, divisionSnap) {
              if (seasonEntries.isEmpty && !divisionSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = seasonEntries.isNotEmpty
                  ? seasonEntries
                  : (divisionSnap.data?.teams ?? const <DivisionTeam>[])
                      .map(StandEntry.fromDivisionTeam)
                      .toList();
              return FutureBuilder<Map<String, List<String>>>(
                future: _vormMapFuture(),
                builder: (context, vormSnap) {
                  if (!vormSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildTable(
                    context: context,
                    entries: entries,
                    vormMap: vormSnap.data ?? {},
                  );
                },
              );
            },
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _archiveStandStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _log.severe('Firestore-fout: ${snapshot.error}');
          return const Center(
            child: Text('Fout bij laden van stand.'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = _buildArchiveEntries(snapshot.data!.docs);

        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Voor dit seizoen is nog geen eindstand beschikbaar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5F6F66)),
            ),
          );
        }

        return _buildTable(
          context: context,
          entries: entries,
          vormMap: const {},
        );
      },
    );
  }

  Widget _buildTable({
    required BuildContext context,
    required List<StandEntry> entries,
    required Map<String, List<String>> vormMap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final isNarrow = screenWidth < 360;

    final bool showLogos = entries.isNotEmpty;
    final double wPos = isDesktop ? 26 : 24;
    final double wLogo = showLogos ? (isDesktop ? 28 : 24) : 0;
    final double wGap = showLogos ? (isDesktop ? 8 : 4) : 0;
    final double wStat = isDesktop ? 26 : 22;
    final double wPoints = isDesktop ? 32 : 28;
    final double wDS = isDesktop ? 32 : 28;
    final double wDvDt = isDesktop ? 50 : 44;

    final Set<String> periodeSet = {
      for (final n in (kPeriodeKampioenen[divisie] ?? const [])) _normName(n),
    };

    final showVorm = _isActueel && screenWidth > 380;
    final showDvDt = !isNarrow;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildHeaderRow(
            isDesktop: isDesktop,
            isMobile: screenWidth < 600,
            wPos: wPos,
            wLogo: wLogo,
            wGap: wGap,
            wStat: wStat,
            wPoints: wPoints,
            wDS: wDS,
            wDvDt: wDvDt,
            showDvDt: showDvDt,
          ),
          const Divider(),
          ListView.separated(
            separatorBuilder: (_, __) {
              return Divider(
                height: 1,
                color: Colors.grey.shade200,
              );
            },
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final club = entries[index];
              final positie =
                  _isActueel || club.positie == 0 ? index + 1 : club.positie;

              Color? bgColor;

              if (!_isActueel) {
                if (positie == 1) {
                  bgColor = Colors.green.withAlpha(40);
                } else if (positie >= entries.length - 1) {
                  bgColor = Colors.red.withAlpha(50);
                } else if (positie >= entries.length - 3) {
                  bgColor = Colors.red.withAlpha(25);
                }
              }

              final isPeriodekampioen = _isActueel &&
                  (periodeSet.contains(club.code) ||
                      periodeSet.contains(club.docCode));

              final vorm = vormMap[club.code] ?? [];

              return Container(
                color: bgColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: wPos,
                      child: Text('$positie.'),
                    ),
                    if (showLogos)
                      SizedBox(
                        width: wLogo,
                        height: wLogo,
                        child: Image.asset(
                          club.logoAsset ?? kDefaultTeamLogoAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Image.asset(
                              kDefaultTeamLogoAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) {
                                return const Icon(
                                  Icons.shield_outlined,
                                  size: 22,
                                  color: Color(0xFF2E7D32),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    if (showLogos) SizedBox(width: wGap),
                    if (isDesktop)
                      SizedBox(
                        width: 150,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                club.naam,
                                style: const TextStyle(fontSize: 15.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPeriodekampioen)
                              const Padding(
                                padding: EdgeInsets.only(left: 3),
                                child: Text(
                                  '🏅',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    club.naam,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPeriodekampioen)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 3),
                                    child: Text(
                                      '🏅',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                            if (showVorm && vorm.isNotEmpty)
                              const SizedBox(height: 2),
                            if (showVorm && vorm.isNotEmpty)
                              VormVakjes(
                                vorm: vorm,
                                compact: true,
                              ),
                          ],
                        ),
                      ),
                    _buildStatText(
                      '${club.gespeeld}',
                      width: wStat,
                    ),
                    _buildStatText(
                      '${club.gewonnen}',
                      width: wStat,
                    ),
                    _buildStatText(
                      '${club.gelijk}',
                      width: wStat,
                    ),
                    _buildStatText(
                      '${club.verloren}',
                      width: wStat,
                    ),
                    _buildStatText(
                      '${club.punten}',
                      isBold: true,
                      width: wPoints,
                    ),
                    _buildStatText(
                      '${club.doelsaldo}',
                      width: wDS,
                    ),
                    if (showDvDt)
                      _buildStatText(
                        '${club.doelpuntenVoor}-${club.doelpuntenTegen}',
                        width: wDvDt,
                      ),
                    if (showVorm && isDesktop) const SizedBox(width: 8),
                    if (showVorm && isDesktop) VormVakjes(vorm: vorm),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatText(
    String text, {
    bool isBold = false,
    double width = 35,
  }) {
    return Container(
      width: width,
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildHeaderRow({
    required bool isDesktop,
    required bool isMobile,
    required double wPos,
    required double wLogo,
    required double wGap,
    required double wStat,
    required double wPoints,
    required double wDS,
    required double wDvDt,
    required bool showDvDt,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            SizedBox(width: wPos),
            if (wLogo > 0) SizedBox(width: wLogo),
            if (wLogo > 0) SizedBox(width: wGap),
            if (isDesktop)
              const SizedBox(width: 150)
            else
              const Expanded(
                flex: 2,
                child: SizedBox.shrink(),
              ),
            SizedBox(
              width: wStat,
              child: const Text(
                'GS',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            SizedBox(
              width: wStat,
              child: const Text(
                'W',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            SizedBox(
              width: wStat,
              child: const Text(
                'G',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            SizedBox(
              width: wStat,
              child: const Text(
                'V',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            SizedBox(
              width: wPoints,
              child: const Text(
                'Pnt',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(
              width: wDS,
              child: const Text(
                'DS',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (showDvDt)
              SizedBox(
                width: wDvDt,
                child: const Text(
                  'DV-DT',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
