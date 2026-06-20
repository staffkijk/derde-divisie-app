import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../wedstrijd.dart';
import '../../../wedstrijden_data.dart';
import '../../widgets/voorspel_wedstrijd_card.dart';

class WedstrijdenPouleDdaScreen extends StatefulWidget {
  final String divisie;   // bv. "Derde Divisie A" of "Divisie A"
  final String pouleId;

  const WedstrijdenPouleDdaScreen({
    super.key,
    required this.divisie,
    required this.pouleId,
  });

  @override
  State<WedstrijdenPouleDdaScreen> createState() =>
      _WedstrijdenPouleDdaScreenState();
}

class _WedstrijdenPouleDdaScreenState extends State<WedstrijdenPouleDdaScreen> {
  static const String _fsCompetitie = 'Derde Divisie A';

  int _huidigeSpeelronde = 1;
  DateTime? _deadline;

  // Basislijst voor de gekozen speelronde
  List<Wedstrijd> _wedstrijden = [];

  // Firestore live data (matches)
  final Map<String, DateTime> _fsDatums = {};
  final Map<String, int?> _werkelijkeUitslagThuis = {};
  final Map<String, int?> _werkelijkeUitslagUit = {};

  // User-voorspellingen voor deze poule (per matchId)
  final Map<String, TextEditingController> _thuisControllers = {};
  final Map<String, TextEditingController> _uitControllers = {};
  final Map<String, int?> _behaaldePunten = {};

  // Sync status van deelnemer in deze poule
  bool _syncEnabled = false;

  // Listeners
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _matchesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _predictionsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deelnemerSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    _predictionsSub?.cancel();
    _deelnemerSub?.cancel();
    for (final c in _thuisControllers.values) {
      c.dispose();
    }
    for (final c in _uitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _listenDeelnemerSyncStatus();
    _bepaalEerstvolgendeSpeelronde();
    _laadWedstrijdenBasisVoorSpeelronde(_huidigeSpeelronde);
    _listenMatchesFirestore(_huidigeSpeelronde);
    _listenPouleVoorspellingen(); // live punten/voorspellingen
    setState(() {});
  }

  void _listenDeelnemerSyncStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _deelnemerSub?.cancel();
    _deelnemerSub = FirebaseFirestore.instance
        .collection('poules')
        .doc(widget.pouleId)
        .collection('deelnemers')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      final enabled = (data?['syncEnabled'] == true);
      if (enabled != _syncEnabled && mounted) {
        setState(() => _syncEnabled = enabled);
      }
    });
  }

  void _bepaalEerstvolgendeSpeelronde() {
    final vandaag = DateTime.now();
    final alleWedstrijden = getWedstrijden(widget.divisie);
    final lijst = alleWedstrijden
        .where((w) => w.datum.isAfter(vandaag))
        .map((w) => w.speelronde)
        .toList();
    _huidigeSpeelronde =
        lijst.isEmpty ? 1 : lijst.reduce((a, b) => a < b ? a : b).clamp(1, 34);
  }

  void _laadWedstrijdenBasisVoorSpeelronde(int speelronde) {
    final alleWedstrijden = getWedstrijden(widget.divisie);
    final wedstrijdenVoorRonde =
        alleWedstrijden.where((w) => w.speelronde == speelronde).toList()
          ..sort((a, b) => a.datum.compareTo(b.datum));

    _wedstrijden = wedstrijdenVoorRonde;

    // Controllers opbouwen per matchId
    _thuisControllers.clear();
    _uitControllers.clear();
    for (final w in _wedstrijden) {
      _thuisControllers[w.id] = TextEditingController();
      _uitControllers[w.id] = TextEditingController();
    }

    // caches leeg; listeners vullen ze
    _fsDatums.clear();
    _werkelijkeUitslagThuis.clear();
    _werkelijkeUitslagUit.clear();
    _behaaldePunten.clear();
    _deadline = null;
  }

  void _listenMatchesFirestore(int speelronde) {
    _matchesSub?.cancel();

    _matchesSub = FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: _fsCompetitie)
        .where('speelronde', isEqualTo: speelronde)
        .snapshots()
        .listen((snap) {
      DateTime? earliest;

      for (final d in snap.docs) {
        final data = d.data();

        // datum (ondersteun 'datum' of 'timestamp')
        final ts = data['datum'] ?? data['timestamp'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          _fsDatums[d.id] = dt;
          if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        }

        // officiële uitslag (kan null zijn)
        _werkelijkeUitslagThuis[d.id] = data['uitslagThuis'];
        _werkelijkeUitslagUit[d.id] = data['uitslagUit'];
      }

      _deadline = (earliest != null)
          ? DateTime(earliest.year, earliest.month, earliest.day, 12)
          : null;

      if (mounted) setState(() {});
    });
  }

  /// Live listener voor poule-voorspellingen van de huidige gebruiker
  /// in de huidige speelronde (poule_predictions = DDA).
  void _listenPouleVoorspellingen() {
    _predictionsSub?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ids = _wedstrijden.map((w) => w.id).toList();
    if (ids.isEmpty) {
      setState(() {
        _behaaldePunten.clear();
      });
      return;
    }

    // Firestore whereIn accepteert max 10 items. Ronde 3A heeft 9 matches → ok.
    _predictionsSub = FirebaseFirestore.instance
        .collection('poule_predictions')
        .where('pouleId', isEqualTo: widget.pouleId)
        .where('gebruikerId', isEqualTo: user.uid)
        .where('matchId', whereIn: ids) // ✅ matchId-consistent
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        final matchId = (data['matchId'] ?? data['wedstrijdId']).toString();

        // zet controllers (voorkom cursor-jump door alleen te updaten als tekst anders is)
        final thuisTxt = data['scoreThuis']?.toString() ?? '';
        final uitTxt   = data['scoreUit']?.toString() ?? '';
        final tc = _thuisControllers[matchId];
        final uc = _uitControllers[matchId];
        if (tc != null && tc.text != thuisTxt) tc.text = thuisTxt;
        if (uc != null && uc.text != uitTxt)   uc.text = uitTxt;

        // punten tonen zodra verwerkt
        _behaaldePunten[matchId] = data['punten'];
      }
      if (mounted) setState(() {});
    });
  }

  bool _isGeldigGetal(String s) {
    final n = int.tryParse(s);
    return n != null && n >= 0;
  }

  Future<void> _opslaanVoorspelling(Wedstrijd w, String thuis, String uit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_isGeldigGetal(thuis) || !_isGeldigGetal(uit)) return;

    // Alleen opslaan als synchronisatie UIT staat en deadline niet verstreken is
    final isLocked = (_deadline != null) ? DateTime.now().isAfter(_deadline!) : false;
    if (_syncEnabled || isLocked) return;

    await FirebaseFirestore.instance
        .collection('poule_predictions') // DDA
        .doc('${widget.pouleId}_${user.uid}_${w.id}')
        .set({
      'pouleId': widget.pouleId,
      'gebruikerId': user.uid,
      'matchId': w.id,            // ✅ consistente sleutel
      'wedstrijdId': w.id,        // (compat - mag blijven)
      'scoreThuis': int.parse(thuis),
      'scoreUit': int.parse(uit),
      'syncedFromGeneral': false, // expliciet handmatig
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final deadlineTekst = (_deadline != null)
        ? DateFormat('EEEE d-MM-yyyy – HH:mm', 'nl').format(_deadline!)
        : 'n.v.t.';

    final bool rondeLocked = (_deadline != null) ? DateTime.now().isAfter(_deadline!) : false;
    final bool inputsDisabled = _syncEnabled || rondeLocked;

    return Scaffold(
      appBar: AppBar(title: const Text('Voorspel Derde Divisie A (Poule)')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Info-balk wanneer sync aan staat
            if (_syncEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.sync, color: Colors.blue),
                    title: const Text('Synchronisatie is ingeschakeld'),
                    subtitle: const Text(
                      'Je voorspellingen in deze poule volgen je algemene voorspellingen (tot de deadline). '
                      'Wil je hier handmatig voorspellen? Zet synchronisatie uit op het pouledetail-scherm.',
                    ),
                  ),
                ),
              ),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 34,
                itemBuilder: (context, index) {
                  final ronde = index + 1;
                  final selected = _huidigeSpeelronde == ronde;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('Ronde $ronde'),
                      selected: selected,
                      selectedColor: Colors.orange.shade100,
                      onSelected: (_) async {
                        setState(() {
                          _huidigeSpeelronde = ronde;
                          _laadWedstrijdenBasisVoorSpeelronde(ronde);
                          _listenMatchesFirestore(ronde);
                        });
                        _listenPouleVoorspellingen(); // herstart listener voor nieuwe ronde
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Deadline voorspellen: $deadlineTekst',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _wedstrijden.length,
                itemBuilder: (context, index) {
                  final w = _wedstrijden[index];
                  final id = w.id; // = matchId

                  // datum uit Firestore (fallback lokaal)
                  final DateTime datum = _fsDatums[id] ?? w.datum;
                  final datumTekst = DateFormat('yyyy-MM-dd').format(datum);

                  // officiële uitslag
                  final thuisScore = _werkelijkeUitslagThuis[id];
                  final uitScore = _werkelijkeUitslagUit[id];

                  // eigen voorspelling
                  final ingevuld =
                      (_thuisControllers[id]?.text.isNotEmpty ?? false) &&
                      (_uitControllers[id]?.text.isNotEmpty ?? false);
                  final int? eigenThuis =
                      ingevuld ? int.tryParse(_thuisControllers[id]!.text) : null;
                  final int? eigenUit =
                      ingevuld ? int.tryParse(_uitControllers[id]!.text) : null;

                  // punten (tonen als zowel uitslag als voorspelling bekend zijn)
                  final int? punten = (thuisScore != null && uitScore != null && ingevuld)
                      ? _behaaldePunten[id]
                      : null;

                  return VoorspelWedstrijdCard(
                    thuisteam: w.thuis,
                    uitteam: w.uit,
                    datum: datumTekst,
                    thuisController: _thuisControllers[id]!,
                    uitController: _uitControllers[id]!,
                    isDisabled: inputsDisabled, // 🔒 geblokkeerd bij sync of na deadline
                    werkelijkeThuis: thuisScore,
                    werkelijkeUit: uitScore,
                    behaaldePunten: punten,
                    eigenVoorspellingThuis: eigenThuis,
                    eigenVoorspellingUit: eigenUit,
                    onThuisScoreChanged: (value) {
                      if (!inputsDisabled) {
                        _opslaanVoorspelling(w, value, _uitControllers[id]!.text);
                      }
                    },
                    onUitScoreChanged: (value) {
                      if (!inputsDisabled) {
                        _opslaanVoorspelling(w, _thuisControllers[id]!.text, value);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
