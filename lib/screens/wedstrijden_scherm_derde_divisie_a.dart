import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../wedstrijd.dart';
import '../../wedstrijden_data.dart';
import 'package:derde_divisie/helpers/sync_service.dart';

class WedstrijdenSchermDerdeDivisieA extends StatefulWidget {
  final String divisie;

  const WedstrijdenSchermDerdeDivisieA({super.key, required this.divisie});

  @override
  State<WedstrijdenSchermDerdeDivisieA> createState() =>
      _WedstrijdenSchermDerdeDivisieAState();
}

class _WedstrijdenSchermDerdeDivisieAState
    extends State<WedstrijdenSchermDerdeDivisieA> {
  int _huidigeSpeelronde = 1;
  DateTime? _deadline;
  List<Wedstrijd> _wedstrijden = [];

  final Map<String, DateTime> _fsDatums = {};
  final Map<String, int?> _werkelijkeUitslagThuis = {};
  final Map<String, int?> _werkelijkeUitslagUit = {};
  final Map<String, int?> _behaaldePunten = {};
  final Map<String, int?> _voorspellingThuis = {};
  final Map<String, int?> _voorspellingUit = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _matchesSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    super.dispose();
  }

  String _competitionCode() => widget.divisie.contains('A') ? 'dda' : 'ddb';

  String _fsCompetitieNaam() =>
      widget.divisie.contains('A') ? 'Derde Divisie A' : 'Derde Divisie B';

  Future<DateTime?> _getRoundOverrideUntil({
    required String competitionCode, // 'dda' | 'ddb'
    required int speelronde,
  }) async {
    final docId = '${competitionCode}_$speelronde';
    final snap = await FirebaseFirestore.instance
        .collection('round_overrides')
        .doc(docId)
        .get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final ts = data['reopenUntil'];
    if (ts is! Timestamp) return null;

    final untilUtc = ts.toDate().toUtc();
    if (DateTime.now().toUtc().isAfter(untilUtc)) return null;

    // In UI werken we met lokale tijd (DateFormat 'nl' gebruikt local)
    return untilUtc.toLocal();
  }

  Future<void> _init() async {
    _bepaalHuidigeSpeelrondeOpDatum();
    _laadWedstrijdenBasisVoorSpeelronde(_huidigeSpeelronde);
    _listenMatchesFirestore(_huidigeSpeelronde);
    await _laadVoorspellingen();
    setState(() {});
  }

  void _bepaalHuidigeSpeelrondeOpDatum() {
    final vandaag = DateTime.now();
    final alleWedstrijden = getWedstrijden(widget.divisie);
    final toekomstige = alleWedstrijden
        .where((w) => w.datum.isAfter(vandaag))
        .map((w) => w.speelronde)
        .toList();

    if (toekomstige.isNotEmpty) {
      _huidigeSpeelronde =
          toekomstige.reduce((a, b) => a < b ? a : b).clamp(1, 34);
    } else {
      _huidigeSpeelronde = alleWedstrijden
          .map((w) => w.speelronde)
          .reduce((a, b) => a > b ? a : b);
    }
  }

  void _laadWedstrijdenBasisVoorSpeelronde(int speelronde) {
    final alleWedstrijden = getWedstrijden(widget.divisie);
    final wedstrijdenVoorRonde =
        alleWedstrijden.where((w) => w.speelronde == speelronde).toList();
    wedstrijdenVoorRonde.sort((a, b) => a.datum.compareTo(b.datum));
    _wedstrijden = wedstrijdenVoorRonde;

    _werkelijkeUitslagThuis.clear();
    _werkelijkeUitslagUit.clear();
    _behaaldePunten.clear();
    _fsDatums.clear();
    _deadline = null;
  }

  void _listenMatchesFirestore(int speelronde) {
    _matchesSub?.cancel();

    final fsCompetitie = _fsCompetitieNaam();
    final competitionCode = _competitionCode();

    _matchesSub = FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: fsCompetitie)
        .where('speelronde', isEqualTo: speelronde)
        .snapshots()
        .listen((snapshot) async {
      DateTime? earliest;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ts = data['datum'];
        if (ts is Timestamp) {
          final dt = ts.toDate(); // lokaal
          _fsDatums[doc.id] = dt;
          if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        }
        _werkelijkeUitslagThuis[doc.id] = data['uitslagThuis'];
        _werkelijkeUitslagUit[doc.id] = data['uitslagUit'];
      }

      // ✅ 1) Override check (1 ronde heropenen via Firestore)
      final overrideUntil = await _getRoundOverrideUntil(
        competitionCode: competitionCode,
        speelronde: speelronde,
      );

      if (overrideUntil != null) {
        _deadline = overrideUntil; // toon en lock t.o.v. override
      } else {
        // ✅ 2) Default gedrag: 12:00 op dag van vroegste wedstrijd (lokale tijd)
        _deadline = (earliest != null)
            ? DateTime(earliest.year, earliest.month, earliest.day, 12)
            : null;
      }

      if (mounted) setState(() {});
    });
  }

  Future<void> _laadVoorspellingen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('voorspellingen')
        .where('gebruikerId', isEqualTo: user.uid)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final id = data['wedstrijdId'].toString();
      _voorspellingThuis[id] = data['scoreThuis'];
      _voorspellingUit[id] = data['scoreUit'];
      _behaaldePunten[id] = data['punten'] ?? 0;
    }
  }

  Future<void> _opslaanVoorspelling(
      Wedstrijd wedstrijd, int? thuis, int? uit) async {
    if (thuis == null || uit == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('voorspellingen')
        .doc('${user.uid}_${wedstrijd.id}')
        .set({
      'gebruikerId': user.uid,
      'wedstrijdId': wedstrijd.id,
      'scoreThuis': thuis,
      'scoreUit': uit,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _voorspellingThuis[wedstrijd.id] = thuis;
    _voorspellingUit[wedstrijd.id] = uit;

    final compCode = _competitionCode();

    await SyncService.instance.onGeneralPredictionChangedCompetition(
      userId: user.uid,
      competition: compCode,
      round: wedstrijd.speelronde,
      matchId: wedstrijd.id,
      generalPrediction: {'scoreThuis': thuis, 'scoreUit': uit},
    );

    await SyncService.instance.onGeneralPredictionChangedOneTeam(
      userId: user.uid,
      matchId: wedstrijd.id,
      generalPrediction: {'scoreThuis': thuis, 'scoreUit': uit},
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deadlineTekst = (_deadline != null)
        ? DateFormat('EEEE d-MM-yyyy – HH:mm', 'nl').format(_deadline!)
        : 'n.v.t.';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildRondeSelector(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade100),
                  ),
                  child: Text(
                    'Deadline voorspellen: $deadlineTekst',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _wedstrijden.length,
                  itemBuilder: (context, index) {
                    final w = _wedstrijden[index];
                    final id = w.id;
                    final thuis = _werkelijkeUitslagThuis[id];
                    final uit = _werkelijkeUitslagUit[id];
                    final uitslagBekend = thuis != null && uit != null;
                    final punten = _behaaldePunten[id] ?? 0;

                    final isLocked = (_deadline != null)
                        ? DateTime.now().isAfter(_deadline!)
                        : false;

                    final voorspellingThuis = _voorspellingThuis[id];
                    final voorspellingUit = _voorspellingUit[id];

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildTeamWithLogo(w.thuis, alignRight: false),
                              _buildVerticalPickerBox(
                                huidigeWaarde: voorspellingThuis,
                                disabled: isLocked,
                                onSelected: (v) {
                                  setState(() {
                                    _voorspellingThuis[id] = v;
                                  });
                                  if (!isLocked) {
                                    _opslaanVoorspelling(w, v, voorspellingUit);
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              const Text('-'),
                              const SizedBox(width: 6),
                              _buildVerticalPickerBox(
                                huidigeWaarde: voorspellingUit,
                                disabled: isLocked,
                                onSelected: (v) {
                                  setState(() {
                                    _voorspellingUit[id] = v;
                                  });
                                  if (!isLocked) {
                                    _opslaanVoorspelling(w, voorspellingThuis, v);
                                  }
                                },
                              ),
                              _buildTeamWithLogo(w.uit, alignRight: true),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (uitslagBekend)
                            Column(
                              children: [
                                Text(
                                  'Eindstand: $thuis - $uit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: punten > 0
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Behaalde punten: $punten pt',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: punten > 0
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRondeSelector() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 34,
        controller: ScrollController(
            initialScrollOffset: (_huidigeSpeelronde * 70).toDouble()),
        itemBuilder: (context, index) {
          final ronde = index + 1;
          final isSelected = _huidigeSpeelronde == ronde;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('R$ronde'),
              selected: isSelected,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selectedColor: Colors.orange.shade200,
              onSelected: (_) async {
                setState(() {
                  _huidigeSpeelronde = ronde;
                  _laadWedstrijdenBasisVoorSpeelronde(ronde);
                  _listenMatchesFirestore(ronde);
                });
                await _laadVoorspellingen();
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }

  /// 🔢 Verticale popup picker met directe update
  Widget _buildVerticalPickerBox({
    required int? huidigeWaarde,
    required bool disabled,
    required Function(int?) onSelected,
  }) {
    return PopupMenuButton<int?>(
      enabled: !disabled,
      onSelected: (v) {
        onSelected(v);
      },
      itemBuilder: (context) => [
        const PopupMenuItem<int?>(
          value: null,
          child: Text('—', style: TextStyle(color: Colors.grey)),
        ),
        for (var i = 0; i <= 9; i++)
          PopupMenuItem<int?>(
            value: i,
            child: Center(child: Text(i.toString())),
          ),
      ],
      child: Container(
        width: 42,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled ? Colors.grey.shade300 : Colors.grey.shade400,
          ),
        ),
        child: Text(
          huidigeWaarde?.toString() ?? '',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamWithLogo(String team, {required bool alignRight}) {
    final cleanTeam = team.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final imagePath = 'assets/images/logo_$cleanTeam.png';

    return Expanded(
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!alignRight)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _teamLogoWidget(imagePath),
            ),
          Flexible(
            child: Text(
              team,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17.0),
            ),
          ),
          if (alignRight)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _teamLogoWidget(imagePath),
            ),
        ],
      ),
    );
  }

  Widget _teamLogoWidget(String imagePath) {
    return Image.asset(
      imagePath,
      width: 38,
      height: 38,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/default_logo.png',
        width: 38,
        height: 38,
      ),
    );
  }
}
