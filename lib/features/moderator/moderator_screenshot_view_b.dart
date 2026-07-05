import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:derde_divisie/helpers/club_logo_helper.dart';

class ModeratorScreenshotViewB extends StatelessWidget {
  final int speelronde;

  const ModeratorScreenshotViewB({super.key, required this.speelronde});

  Future<List<Map<String, dynamic>>> _getProgrammaEnUitslagen() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: 'Derde Divisie B')
        .where('speelronde', isEqualTo: speelronde)
        .orderBy('datum')
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _getStand() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('standen')
        .where('divisie', isEqualTo: 'B')
        .get();

    List<Map<String, dynamic>> lijst =
        snapshot.docs.map((doc) => doc.data()).toList();

    lijst.sort((a, b) {
      int punten = (b['punten'] ?? 0).compareTo(a['punten'] ?? 0);
      if (punten != 0) return punten;

      int gespeeld = (a['gespeeld'] ?? 0).compareTo(b['gespeeld'] ?? 0);
      if (gespeeld != 0) return gespeeld;

      int doelsaldoA = (a['doelpuntenVoor'] ?? 0) - (a['doelpuntenTegen'] ?? 0);
      int doelsaldoB = (b['doelpuntenVoor'] ?? 0) - (b['doelpuntenTegen'] ?? 0);
      int doelsaldo = doelsaldoB.compareTo(doelsaldoA);
      if (doelsaldo != 0) return doelsaldo;

      int doelpuntenVoor =
          (b['doelpuntenVoor'] ?? 0).compareTo(a['doelpuntenVoor'] ?? 0);
      if (doelpuntenVoor != 0) return doelpuntenVoor;

      return (a['team'] ?? '')
          .toString()
          .compareTo((b['team'] ?? '').toString());
    });

    return lijst;
  }

  Widget _buildRij(String thuis, String uit, String tijd, String? uitslag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            getLogo(thuis, size: 20),
            const SizedBox(width: 4),
            Text(thuis),
          ]),
          Text(tijd),
          Row(children: [
            Text(uit),
            const SizedBox(width: 4),
            getLogo(uit, size: 20),
          ]),
          if (uitslag != null)
            Text(uitslag, style: const TextStyle(fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Color? _achtergrondKleur(int positie) {
    if (positie == 0) return Colors.green.shade100;
    if (positie >= 16) return Colors.red.shade100;
    if (positie >= 14) return Colors.orange.shade100;
    return null;
  }

  Widget _buildStandRij(Map<String, dynamic> team, int index) {
    final ds = (team['doelpuntenVoor'] ?? 0) - (team['doelpuntenTegen'] ?? 0);
    return Container(
      color: _achtergrondKleur(index),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      child: Row(
        children: [
          SizedBox(width: 16, child: Text('${index + 1}')),
          const SizedBox(width: 6),
          getLogo(team['team'], size: 18),
          const SizedBox(width: 4),
          Expanded(
              child:
                  Text(team['team'] ?? '-', overflow: TextOverflow.ellipsis)),
          Text('${team['gespeeld'] ?? 0}  '),
          Text('${team['gewonnen'] ?? 0}  '),
          Text('${team['gelijk'] ?? 0}  '),
          Text('${team['verloren'] ?? 0}  '),
          Text('${team['punten'] ?? 0}  '),
          Text('$ds  '),
          Text(
              '${team['doelpuntenVoor'] ?? 0}-${team['doelpuntenTegen'] ?? 0}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder(
          future: Future.wait([
            _getProgrammaEnUitslagen(),
            _getStand(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final programma = snapshot.data![0] as List<Map<String, dynamic>>;
            final stand = snapshot.data![1] as List<Map<String, dynamic>>;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Derde Divisie B – Speelronde $speelronde',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Wedstrijdprogramma:',
                      style: TextStyle(decoration: TextDecoration.underline)),
                  const SizedBox(height: 4),
                  ...programma.map((match) => _buildRij(
                        match['thuisteam'] ?? '',
                        match['uitteam'] ?? '',
                        match['tijd'] ?? '',
                        match['uitslagThuis'] != null &&
                                match['uitslagUit'] != null
                            ? '${match['uitslagThuis']}-${match['uitslagUit']}'
                            : null,
                      )),
                  const Divider(thickness: 1.5),
                  const Text('Stand:',
                      style: TextStyle(decoration: TextDecoration.underline)),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey.shade200,
                    child: const Row(
                      children: [
                        SizedBox(width: 26),
                        Expanded(child: Text('Team')),
                        Text('G W G V Pnt DS DV-DT'),
                      ],
                    ),
                  ),
                  ...stand
                      .asMap()
                      .entries
                      .map((entry) => _buildStandRij(entry.value, entry.key)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
