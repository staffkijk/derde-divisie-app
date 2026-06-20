// lib/screens/stand_derde_divisie_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:derde_divisie/screens/periode_standen_screen.dart';

final Logger _log = Logger('StandDerdeDivisie');

/// ⬇️ Handmatig instellen van periodekampioenen per divisie
/// Vul hier de clubnamen in zoals je ze normaal schrijft.
/// Voorbeeld:
/// 'Derde Divisie A': ["Kloetinge", "Sportlust'46"],
const Map<String, List<String>> kPeriodeKampioenen = {
  'Derde Divisie A': ['DVS33 Ermelo','Sparta Nijkerk','ADO20'],
  'Derde Divisie B': ['VVSB','FC Lisse','Rijnvogels']
};


/// Normaliseer clubnaam naar dezelfde code-vorm als in de tabel
String _normName(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int _calcDoelsaldo(Map<String, dynamic> d) {
  final ds = d['doelsaldo'];
  if (ds != null) return _toInt(ds);
  final dv = _toInt(d['doelpuntenVoor'] ?? d['dv']);
  final dt = _toInt(d['doelpuntenTegen'] ?? d['dt']);
  return dv - dt;
}

/// 🔹 Bereken alle vormen lokaal op basis van Firestore-data
Map<String, List<String>> berekenVormPerTeam(List<Map<String, dynamic>> matches) {
  final Map<String, List<Map<String, dynamic>>> perTeam = {};

  for (final m in matches) {
    final home = (m['homeTeamCode'] ?? '').toString().toLowerCase();
    final away = (m['awayTeamCode'] ?? '').toString().toLowerCase();

    void add(String teamCode, bool isHome) {
      final thuisGoals = m['uitslagThuis'] ?? 0;
      final uitGoals = m['uitslagUit'] ?? 0;
      final diff = isHome ? (thuisGoals - uitGoals) : (uitGoals - thuisGoals);
      final result = diff > 0 ? 'W' : (diff == 0 ? 'G' : 'V');
      perTeam.putIfAbsent(teamCode, () => []);
      perTeam[teamCode]!.add({
        'datum': (m['datum'] is Timestamp)
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
    lijst.sort((a, b) => (b['datum'] as DateTime).compareTo(a['datum'] as DateTime));
    resultaat[team] = lijst.take(5).map((e) => e['result'] as String).toList();
  });

  return resultaat;
}

/// 🔹 Vormvakjes met fade-in animatie
class VormVakjes extends StatefulWidget {
  final List<String> vorm;
  final bool compact;

  const VormVakjes({super.key, required this.vorm, this.compact = false});

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
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
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
              color: _kleur(v).withOpacity(0.9),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StandDerdeDivisieScreen extends StatelessWidget {
  const StandDerdeDivisieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text(
                'Bekijk periodestanden',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          ),
          const SizedBox(height: 16),

          if (!isWide) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Stand Divisie A',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const StandDerdeDivisie(divisie: 'Derde Divisie A'),
            const Divider(thickness: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Stand Divisie B',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const StandDerdeDivisie(divisie: 'Derde Divisie B'),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Stand Divisie A',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        StandDerdeDivisie(divisie: 'Derde Divisie A'),
                      ],
                    ),
                  ),
                  // verticale scheidslijn
                  Container(
                    width: 1,
                    height: 700,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Stand Divisie B',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        StandDerdeDivisie(divisie: 'Derde Divisie B'),
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

  const StandDerdeDivisie({super.key, required this.divisie});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final isNarrow = screenWidth < 360; // zeer smal (oude telefoons)

    // Kolombreedtes dynamisch zodat het niet overloopt op mobiel
    final double wPos = isDesktop ? 26 : 24;
    final double wLogo = isDesktop ? 26 : 24;
    final double wGap = isDesktop ? 6 : 4;
    final double wStat = isDesktop ? 26 : 22; // G/W/G/V
    final double wPoints = isDesktop ? 32 : 28; // Pnt
    final double wDS = isDesktop ? 32 : 28; // DS
    final double wDvDt = isDesktop ? 50 : 44; // DV-DT

    // Set met genormaliseerde periodekampioenen voor de huidige divisie
    final Set<String> periodeSet = {
      for (final n in (kPeriodeKampioenen[divisie] ?? const [])) _normName(n)
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: FirebaseFirestore.instance
            .collection('matches')
            .where('competitie', isEqualTo: divisie)
            .where('verwerkt', isEqualTo: true)
            .get()
            .then((snap) => snap.docs),
        builder: (context, matchSnap) {
          if (!matchSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches =
              matchSnap.data!.map((d) => d.data() as Map<String, dynamic>).toList();
          final vormMap = berekenVormPerTeam(matches);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('standen')
                .where('competitie', isEqualTo: divisie)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _log.severe('🔥 Firestore-fout: ${snapshot.error}');
                return const Center(child: Text('Fout bij laden van stand.'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

                final clubs = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final naam = (data['club'] ?? '').toString();
                final code = _normName(naam);
                final docCode = _normName(doc.id);
                final gespeeld = _toInt(data['gespeeld']);
                final punten = _toInt(data['punten']);
                final dv = _toInt(data['doelpuntenVoor'] ?? data['dv']);
                final dt = _toInt(data['doelpuntenTegen'] ?? data['dt']);
                final ds = _calcDoelsaldo(data);

                return {
                  'doc': data,
                  'naam': naam,
                  'code': code,
                  'docCode': docCode,
                  'gespeeld': gespeeld,
                  'punten': punten,
                  'doelpuntenVoor': dv,
                  'doelpuntenTegen': dt,
                  'doelsaldo': ds,
                };
              }).toList();

              clubs.sort((a, b) {
                int c;
                c = (_toInt(b['punten'])).compareTo(_toInt(a['punten']));
                if (c != 0) return c;
                c = (_toInt(a['gespeeld'])).compareTo(_toInt(b['gespeeld']));
                if (c != 0) return c;
                c = (_toInt(b['doelsaldo'])).compareTo(_toInt(a['doelsaldo']));
                if (c != 0) return c;
                c = (_toInt(b['doelpuntenVoor']))
                    .compareTo(_toInt(a['doelpuntenVoor']));
                if (c != 0) return c;
                return (a['naam'] as String).compareTo(b['naam'] as String);
              });

              final showVorm = screenWidth > 380; // verberg bij smalle schermen
              final showDvDt = !isNarrow; // DV-DT kolom verbergen op héél smal

              return Column(
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
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: clubs.length,
                    itemBuilder: (context, index) {
                      final club = clubs[index];
                      final data = club['doc'] as Map<String, dynamic>;
                      final positie = index + 1;

                      Color? bgColor;
                      if (positie == 1) {
                        bgColor = Colors.green.withAlpha(40);
                      } else if (positie >= clubs.length - 1) {
                        bgColor = Colors.red.withAlpha(50);
                      } else if (positie >= clubs.length - 3) {
                        bgColor = Colors.red.withAlpha(25);
                      }

                      final logoNaam =
                          'assets/images/logo_${(club['naam'] as String).replaceAll(' ', '')}.png';
                      final isPeriodekampioen =
    periodeSet.contains(club['code']) ||
    periodeSet.contains(club['docCode']);
                      final vorm = vormMap[club['code']] ?? [];

                      return Container(
                        color: bgColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(width: wPos, child: Text('$positie.')),
                            SizedBox(
                              width: wLogo,
                              height: wLogo,
                              child: Image.asset(
                                logoNaam,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                            SizedBox(width: wGap),
                            if (isDesktop)
                              SizedBox(
                                width: 150,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        club['naam'] as String,
                                        style: const TextStyle(fontSize: 15.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isPeriodekampioen)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 3),
                                        child: Text('🏅', style: TextStyle(fontSize: 13)),
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
                                            club['naam'] as String,
                                            style: const TextStyle(fontSize: 15.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isPeriodekampioen)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 3),
                                            child: Text('🏅', style: TextStyle(fontSize: 13)),
                                          ),
                                      ],
                                    ),
                                    if (!isDesktop && showVorm && vorm.isNotEmpty)
                                      const SizedBox(height: 2),
                                    if (!isDesktop && showVorm && vorm.isNotEmpty)
                                      VormVakjes(vorm: vorm, compact: true),
                                  ],
                                ),
                              ),
                            _buildStatText('${club['gespeeld']}', width: wStat),
                            _buildStatText('${data['gewonnen'] ?? 0}', width: wStat),
                            _buildStatText('${data['gelijk'] ?? 0}', width: wStat),
                            _buildStatText('${data['verloren'] ?? 0}', width: wStat),
                            _buildStatText('${club['punten']}', isBold: true, width: wPoints),
                            _buildStatText('${club['doelsaldo']}', width: wDS),
                            if (showDvDt)
                              _buildStatText(
                                '${club['doelpuntenVoor']}-${club['doelpuntenTegen']}',
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
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatText(String text, {bool isBold = false, double width = 35}) {
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
            SizedBox(width: wLogo),
            SizedBox(width: wGap),
            // Teamnaam-kolom: desktop vast, mobiel flexibel
            if (isDesktop)
              const SizedBox(width: 150)
            else
              const Expanded(
                flex: 2,
                child: SizedBox.shrink(),
              ),
            SizedBox(
              width: wStat,
              child: const Text('G', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace')),
            ),
            SizedBox(
              width: wStat,
              child: const Text('W', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace')),
            ),
            SizedBox(
              width: wStat,
              child: const Text('G', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace')),
            ),
            SizedBox(
              width: wStat,
              child: const Text('V', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace')),
            ),
            SizedBox(
              width: wPoints,
              child: const Text('Pnt', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
            SizedBox(
              width: wDS,
              child: const Text('DS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
            if (showDvDt)
              SizedBox(
                width: wDvDt,
                child: const Text('DV-DT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ),
          ],
        ),
      ),
    );
  }
}
