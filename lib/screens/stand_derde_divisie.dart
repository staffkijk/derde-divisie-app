// lib/screens/stand_derde_divisie.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:derde_divisie/screens/periode_standen_screen.dart';

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
  'Derde Divisie A': ['DVS33 Ermelo', 'Sparta Nijkerk', 'ADO20'],
  'Derde Divisie B': ['VVSB', 'FC Lisse', 'Rijnvogels'],
};

class SeasonTeam {
  final String name;
  final String logoAsset;

  const SeasonTeam(this.name, this.logoAsset);
}

const String _defaultTeamLogo = 'assets/images/default_logo.png';

const List<SeasonTeam> seasonTeams20262027 = [
  SeasonTeam('ACV', 'assets/images/logo_ACV.png'),
  SeasonTeam("ADO'20", 'assets/images/logo_ADO20.png'),
  SeasonTeam("Blauw Geel '38", 'assets/images/logo_BlauwGeel38JUMBO.png'),
  SeasonTeam("DVS'33 Ermelo", 'assets/images/logo_DVS33Ermelo.png'),
  SeasonTeam('EVV Echt', 'assets/images/logo_EVVEcht.png'),
  SeasonTeam("Excelsior '31", 'assets/images/logo_Excelsior31.png'),
  SeasonTeam('Excelsior Maassluis', 'assets/images/logo_ExcelsiorMaassluis.png'),
  SeasonTeam('FC Lisse', 'assets/images/logo_FCLisse.png'),
  SeasonTeam('FC Rijnvogels', 'assets/images/logo_Rijnvogels.png'),
  SeasonTeam('Harkemase Boys', 'assets/images/logo_HarkemaseBoys.png'),
  SeasonTeam('HVV Hollandia', 'assets/images/logo_Hollandia.png'),
  SeasonTeam('Purmersteijn', 'assets/images/logo_Purmersteijn.png'),
  SeasonTeam('RBC', 'assets/images/logo_RBC.png'),
  SeasonTeam('RKSV Groene Ster', 'assets/images/logo_GroeneSter.png'),
  SeasonTeam('SC Genemuiden', 'assets/images/logo_SCGenemuiden.png'),
  SeasonTeam("Sportlust '46", 'assets/images/logo_Sportlust46.png'),
  SeasonTeam('SV Poortugaal', 'assets/images/logo_Poortugaal.png'),
  SeasonTeam('SV TEC', 'assets/images/logo_TEC.png'),
  SeasonTeam('SVZW', 'assets/images/logo_SVZW.png'),
  SeasonTeam('TOGB', 'assets/images/logo_TOGB.png'),
  SeasonTeam("UDI'19", 'assets/images/logo_UDI19.png'),
  SeasonTeam('USV Hercules', 'assets/images/logo_Hercules.png'),
  SeasonTeam('VV Achilles Veen', 'assets/images/logo_AchillesVeen.png'),
  SeasonTeam('VV Dongen', 'assets/images/logo_dongen.png'),
  SeasonTeam('VV DOVO', 'assets/images/logo_DOVO.png'),
  SeasonTeam('VV Eemdijk', 'assets/images/logo_Eemdijk.png'),
  SeasonTeam('VV Gemert', 'assets/images/logo_Gemert.png'),
  SeasonTeam('VV Goes', 'assets/images/logo_Goes.png'),
  SeasonTeam('VV Hoogeveen', 'assets/images/logo_Hoogeveen.png'),
  SeasonTeam('VV Noordwijk', 'assets/images/logo_Noordwijk.png'),
  SeasonTeam('VV Scherpenzeel', 'assets/images/logo_Scherpenzeel.png'),
  SeasonTeam('VV Sparta Nijkerk', 'assets/images/logo_SpartaNijkerk.png'),
  SeasonTeam('VV Staphorst', 'assets/images/logo_Staphorst.png'),
  SeasonTeam('VV UNA', 'assets/images/logo_UNA.png'),
  SeasonTeam('VV Zwaluwen', 'assets/images/logo_Zwaluwen.png'),
  SeasonTeam('VVSB', 'assets/images/logo_VVSB.png'),
];

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
    d['doelpuntenVoor'] ??
        d['goalsFor'] ??
        d['dv'],
  );

  final dt = _toInt(
    d['doelpuntenTegen'] ??
        d['goalsAgainst'] ??
        d['dt'],
  );

  return dv - dt;
}

String _divisieCode(String divisie) {
  if (divisie.toLowerCase().contains(' b')) return 'B';
  return 'A';
}

bool _isDivisieA(String divisie) {
  return _divisieCode(divisie) == 'A';
}

Map<String, List<String>> berekenVormPerTeam(
  List<Map<String, dynamic>> matches,
) {
  final Map<String, List<Map<String, dynamic>>> perTeam = {};

  for (final m in matches) {
    final home = (m['homeTeamCode'] ?? '').toString().toLowerCase();
    final away = (m['awayTeamCode'] ?? '').toString().toLowerCase();

    void add(String teamCode, bool isHome) {
      if (teamCode.isEmpty) return;

      final thuisGoals = _toInt(m['uitslagThuis']);
      final uitGoals = _toInt(m['uitslagUit']);

      final diff = isHome ? thuisGoals - uitGoals : uitGoals - thuisGoals;
      final result = diff > 0
          ? 'W'
          : diff == 0
              ? 'G'
              : 'V';

      perTeam.putIfAbsent(teamCode, () => []);
      perTeam[teamCode]!.add({
        'datum': m['datum'] is Timestamp
            ? (m['datum'] as Timestamp).toDate()
            : DateTime(2000),
        'result': result,
      });
    }

    add(home, true);
    add(away, false);
  }

  final Map<String, List<String>> resultaat = {};

  perTeam.forEach((team, lijst) {
    lijst.sort(
      (a, b) => (b['datum'] as DateTime).compareTo(a['datum'] as DateTime),
    );

    resultaat[team] = lijst.take(5).map((e) => e['result'] as String).toList();
  });

  return resultaat;
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
      naam: team.name,
      code: _normName(team.name),
      docCode: _normName(team.name),
      logoAsset: team.logoAsset,
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

  factory StandEntry.fromArchiveDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final naam = (data['teamName'] ?? data['club'] ?? '').toString();

    return StandEntry(
      data: data,
      naam: naam,
      code: _normName(naam),
      docCode: _normName(doc.id),
      logoAsset: null,
      positie: _toInt(data['position'] ?? data['positie']),
      gespeeld: _toInt(data['played'] ?? data['gespeeld']),
      gewonnen: _toInt(data['won'] ?? data['wins'] ?? data['gewonnen']),
      gelijk: _toInt(data['drawn'] ?? data['draws'] ?? data['gelijk']),
      verloren: _toInt(data['lost'] ?? data['losses'] ?? data['verloren']),
      punten: _toInt(data['points'] ?? data['punten']),
      doelpuntenVoor: _toInt(
        data['goalsFor'] ??
            data['doelpuntenVoor'] ??
            data['dv'],
      ),
      doelpuntenTegen: _toInt(
        data['goalsAgainst'] ??
            data['doelpuntenTegen'] ??
            data['dt'],
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

    final snap = await FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: divisie)
        .where('verwerkt', isEqualTo: true)
        .get();

    final matches = snap.docs
        .map((d) => d.data())
        .cast<Map<String, dynamic>>()
        .toList();

    return berekenVormPerTeam(matches);
  }

  List<StandEntry> _buildCurrentSeasonEntries() {
    final teams = List<SeasonTeam>.from(seasonTeams20262027)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selectedTeams = _isDivisieA(divisie)
        ? teams.take(18).toList()
        : teams.skip(18).toList();

    return selectedTeams.map(StandEntry.fromSeasonTeam).toList();
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
      return FutureBuilder<Map<String, List<String>>>(
        future: _vormMapFuture(),
        builder: (context, vormSnap) {
          if (!vormSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildTable(
            context: context,
            entries: _buildCurrentSeasonEntries(),
            vormMap: vormSnap.data ?? {},
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
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Geen archiefstand gevonden voor $seizoen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
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

    final bool showLogos = _isActueel;
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
              final positie = _isActueel || club.positie == 0
                  ? index + 1
                  : club.positie;

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
                          club.logoAsset ?? _defaultTeamLogo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Image.asset(
                              _defaultTeamLogo,
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
                    if (showVorm && isDesktop)
                      const SizedBox(width: 8),
                    if (showVorm && isDesktop)
                      VormVakjes(vorm: vorm),
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
                'G',
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