import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EindstandVoorspellingScreen extends StatefulWidget {
  final String divisie; // 'A' of 'B'
  const EindstandVoorspellingScreen({super.key, required this.divisie});

  @override
  State<EindstandVoorspellingScreen> createState() =>
      _EindstandVoorspellingScreenState();
}

class _EindstandVoorspellingScreenState extends State<EindstandVoorspellingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UI-lijst (namen) + parallelle keys (voor matching)
  List<String> clubs = [];
  List<String> clubKeys = [];

  bool isLoading = true;
  bool isBuitenDeadline = false;

  // na deadline tonen we: werkelijke plek + punten per regel
  Map<String, int> _echtePosities = {}; // key -> 0-based positie
  List<int> _puntenPerRegel = [];
  int _totaalPunten = 0;

  // Deadline voor voorspellingen
  final DateTime deadline = DateTime(2025, 8, 31, 23, 59);

  @override
  void initState() {
    super.initState();
    _laadClubsEnVoorspelling();
  }

  String _competitieNaam() => 'Derde Divisie ${widget.divisie}';

  // ---------- helpers ----------
  // Normaliseer naar een robuuste key (valt terug op naam als codes ontbreken)
  String _key(String? s) {
    if (s == null) return '';
    var t = s
        .replaceAll('’', '')
        .replaceAll("'", '')
        .replaceAll('\u00A0', '')
        .replaceAll(' ', '')
        .replaceAll('/', '')
        .replaceAll('.', '')
        .replaceAll('-', '')
        .toUpperCase()
        .trim();

    // Speciale fixes voor bekende varianten
    if (t.contains('ADO20')) t = 'ADO20'; // ADO ’20 varianten
    if (t == 'SCGENEMUIDEN') t = 'GENEMUIDEN'; // vaak zonder SC
    return t;
  }

  String _logoPath(String club) => 'assets/images/logo_${club
      .replaceAll("’", "")
      .replaceAll("'", "")
      .replaceAll(" ", "")
      .replaceAll("/", "")}.png';

  // ---------- data laden ----------
  Future<void> _laadClubsEnVoorspelling() async {
    final gebruiker = _auth.currentUser;
    if (gebruiker == null) return;

    final standaardClubs = widget.divisie == 'A'
        ? [
            'DOVO', 'Eemdijk', 'Scherpenzeel', 'Staphorst', "DVS'33 Ermelo",
            'Sparta Nijkerk', 'TEC', 'Urk', 'Hoogeveen', "HSC'21",
            "Sportlust'46", "Excelsior'31", 'Hercules', 'SC Genemuiden',
            'Huizen', 'Harkemase Boys', 'Rohda Raalte', "ADO '20"
          ]
        : [
            'Noordwijk', 'Scheveningen', 'SteDoCo', 'Zwaluwen', 'Kloetinge',
            'RBC', 'Groene Ster', 'Rijnvogels', 'UNA', 'ASWH',
            "UDI'19", 'TOGB', 'FC Lisse', 'Gemert', 'sv Meerssen',
            "Blauw Geel'38/JUMBO", 'Goes', 'VVSB'
          ];

    final docId = '${gebruiker.uid}_${widget.divisie}';
    final doc = await _firestore.collection('eindstand_voorspellingen').doc(docId).get();

    isBuitenDeadline = DateTime.now().isAfter(deadline);

    final lijst = doc.exists
        ? List<String>.from(doc.data()?['voorspelling'] ?? standaardClubs)
        : standaardClubs;

    setState(() {
      clubs = lijst;
      clubKeys = lijst.map(_key).toList();
      _puntenPerRegel = List.filled(lijst.length, 0);
      isLoading = false;
    });

    if (isBuitenDeadline) {
      await _berekenEchteEindstandEnPunten();
    }
  }

  // ---------- tussenstand + punten berekenen ----------
  Future<void> _berekenEchteEindstandEnPunten() async {
    final competitie = _competitieNaam();

    final snap = await _firestore
        .collection('matches')
        .where('competitie', isEqualTo: competitie)
        .get();

    // Alleen wedstrijden met score
    final docs = snap.docs.where((d) {
      final m = d.data();
      return m['uitslagThuis'] is int && m['uitslagUit'] is int;
    }).toList();

    // key -> stats
    final clubPunten = <String, Map<String, int>>{};
    void initClub(String key) {
      clubPunten.putIfAbsent(key, () => {
        'punten': 0,
        'doelsaldo': 0,
        'gespeeld': 0,
        'doelpuntenVoor': 0,
      });
    }

    for (final doc in docs) {
      final m = doc.data();

      // ✅ Primair op teamcode matchen, anders op genormaliseerde naam
      final homeKey = _key((m['homeTeamCode'] ?? m['thuisteam'])?.toString());
      final awayKey = _key((m['awayTeamCode'] ?? m['uitteam'])?.toString());
      if (homeKey.isEmpty || awayKey.isEmpty) continue;

      final h = m['uitslagThuis'] as int;
      final a = m['uitslagUit'] as int;

      initClub(homeKey);
      initClub(awayKey);

      clubPunten[homeKey]!['gespeeld'] = clubPunten[homeKey]!['gespeeld']! + 1;
      clubPunten[awayKey]!['gespeeld'] = clubPunten[awayKey]!['gespeeld']! + 1;

      clubPunten[homeKey]!['doelpuntenVoor'] =
          clubPunten[homeKey]!['doelpuntenVoor']! + h;
      clubPunten[awayKey]!['doelpuntenVoor'] =
          clubPunten[awayKey]!['doelpuntenVoor']! + a;

      clubPunten[homeKey]!['doelsaldo'] =
          clubPunten[homeKey]!['doelsaldo']! + (h - a);
      clubPunten[awayKey]!['doelsaldo'] =
          clubPunten[awayKey]!['doelsaldo']! + (a - h);

      if (h > a) {
        clubPunten[homeKey]!['punten'] = clubPunten[homeKey]!['punten']! + 3;
      } else if (h < a) {
        clubPunten[awayKey]!['punten'] = clubPunten[awayKey]!['punten']! + 3;
      } else {
        clubPunten[homeKey]!['punten'] = clubPunten[homeKey]!['punten']! + 1;
        clubPunten[awayKey]!['punten'] = clubPunten[awayKey]!['punten']! + 1;
      }
    }

    // sorteren met jouw tie-breakers
    final ranking = clubPunten.entries.toList()
      ..sort((a, b) {
        final A = a.value, B = b.value;
        final av = (A['punten']! * 1000000) +
            ((1000 - A['gespeeld']!) * 10000) +
            (A['doelsaldo']! * 100) +
            A['doelpuntenVoor']!;
        final bv = (B['punten']! * 1000000) +
            ((1000 - B['gespeeld']!) * 10000) +
            (B['doelsaldo']! * 100) +
            B['doelpuntenVoor']!;
        return bv.compareTo(av);
      });

    // key -> 0-based rank
    _echtePosities = {
      for (int i = 0; i < ranking.length; i++) ranking[i].key: i,
    };

    // punten per regel (vergelijken op key)
    final punten = List<int>.filled(clubs.length, 0);
    var totaal = 0;
    for (int i = 0; i < clubKeys.length; i++) {
      final key = clubKeys[i];
      final echteIndex = _echtePosities[key];
      if (echteIndex == null) continue;

      int p = 0;
      if (echteIndex == 0 && i == 0) {
        p = 30;
      } else if (echteIndex == i) {
        p = 10;
      } else if ((echteIndex - i).abs() == 1) {
        p = 6;
      } else if ((echteIndex - i).abs() == 2) {
        p = 2;
      }
      punten[i] = p;
      totaal += p;
    }

    setState(() {
      _puntenPerRegel = punten;
      _totaalPunten = totaal;
    });
  }

  // ---------- opslaan ----------
  Future<void> _slaVoorspellingOp() async {
    final gebruiker = _auth.currentUser;
    if (gebruiker == null || isBuitenDeadline) return;
    final docId = '${gebruiker.uid}_${widget.divisie}';
    await _firestore.collection('eindstand_voorspellingen').doc(docId).set({
      'gebruikerId': gebruiker.uid,
      'divisie': widget.divisie,
      'voorspelling': clubs,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- UI ----------
  Widget _buildClubTile(int index, String club) {
    final key = clubKeys[index];
    final echteIndex = _echtePosities[key]; // 0-based
    final punten = (index < _puntenPerRegel.length) ? _puntenPerRegel[index] : 0;

    final onderregel = (isBuitenDeadline && echteIndex != null)
        ? 'Werkelijke plek: ${echteIndex + 1}   ·   +$punten'
        : null;

    final correctKleur = (isBuitenDeadline && echteIndex == index)
        ? Colors.green[700]
        : null;

    return Card(
      key: ValueKey('$key-$index'),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white,
      child: ListTile(
        tileColor: Colors.white,
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Text('${index + 1}'),
        ),
        title: Row(
          children: [
            Image.asset(
              _logoPath(club),
              width: 28,
              height: 28,
              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                club,
                style: TextStyle(
                  color: correctKleur,
                  fontWeight: isBuitenDeadline && (echteIndex == index)
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        subtitle: onderregel == null ? null : Text(onderregel, style: const TextStyle(fontSize: 12)),
        trailing: isBuitenDeadline ? const SizedBox(width: 20) : const Icon(Icons.drag_handle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bovenregel = isBuitenDeadline
        ? 'Eindstand vergrendeld – totaal: $_totaalPunten punten'
        : 'Je kunt je voorspelling aanpassen tot 31 augustus 2025';

    return Scaffold(
      appBar: AppBar(title: Text('Eindstand voorspellen – Divisie ${widget.divisie}')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF9F2EE),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    bovenregel,
                    style: TextStyle(
                      color: isBuitenDeadline ? Colors.red : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: true,
                    itemCount: clubs.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (isBuitenDeadline) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final club = clubs.removeAt(oldIndex);
                        final key  = clubKeys.removeAt(oldIndex);
                        clubs.insert(newIndex, club);
                        clubKeys.insert(newIndex, key);
                      });
                      await _slaVoorspellingOp();
                    },
                    itemBuilder: (context, index) => _buildClubTile(index, clubs[index]),
                  ),
                ),
              ],
            ),
    );
  }
}
