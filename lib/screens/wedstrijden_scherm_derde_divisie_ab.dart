import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../wedstrijd.dart';
import '../wedstrijden_dda.dart';
import '../wedstrijden_ddb.dart';

class WedstrijdenSchermDerdeDivisieAB extends StatefulWidget {
  const WedstrijdenSchermDerdeDivisieAB({super.key});

  @override
  State<WedstrijdenSchermDerdeDivisieAB> createState() =>
      _WedstrijdenSchermDerdeDivisieABState();
}

class _WedstrijdenSchermDerdeDivisieABState
    extends State<WedstrijdenSchermDerdeDivisieAB> {
  int geselecteerdeSpeelronde = 1;
  Map<String, Map<String, String>> voorspellingen = {};
  Map<String, TextEditingController> controllers = {};
  DateTime? deadline;

  final List<Wedstrijd> alleWedstrijden = [
    ...wedstrijdenDerdeDivisieA,
    ...wedstrijdenDerdeDivisieB,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    geselecteerdeSpeelronde = _bepaalEerstvolgendeSpeelronde();
    _bepaalDeadline();
    await _laadVoorspellingen();
    setState(() {});
  }

  int _bepaalEerstvolgendeSpeelronde() {
    final vandaag = DateTime.now();
    final lijst = alleWedstrijden
        .where((w) => w.datum.isAfter(vandaag))
        .map((w) => w.speelronde)
        .toList();
    if (lijst.isEmpty) return 1;
    lijst.sort();
    return lijst.first.clamp(1, 34);
  }

  void _bepaalDeadline() {
    final wedstrijdenRonde = alleWedstrijden
        .where((w) => w.speelronde == geselecteerdeSpeelronde)
        .toList();

    if (wedstrijdenRonde.isEmpty) {
      deadline = null;
    } else {
      wedstrijdenRonde.sort((a, b) => a.datum.compareTo(b.datum));
      final eerste = wedstrijdenRonde.first.datum;
      deadline = DateTime(eerste.year, eerste.month, eerste.day, 12);
    }
  }

  bool _isDeadlinePassed() {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!);
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
      final wedstrijdId = data['wedstrijdId'].toString();
      voorspellingen[wedstrijdId] = {
        'thuis': data['scoreThuis']?.toString() ?? '',
        'uit': data['scoreUit']?.toString() ?? '',
      };
    }
  }

  Future<void> _opslaanVoorspelling(
      Wedstrijd wedstrijd, String thuis, String uit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isGeldigGetal(thuis) || !_isGeldigGetal(uit)) return;

    await FirebaseFirestore.instance
        .collection('voorspellingen')
        .doc('${user.uid}_${wedstrijd.id}')
        .set({
      'gebruikerId': user.uid,
      'wedstrijdId': wedstrijd.id,
      'scoreThuis': thuis,
      'scoreUit': uit,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      voorspellingen[wedstrijd.id] = {
        'thuis': thuis,
        'uit': uit,
      };
    });
  }

  bool _isGeldigGetal(String input) {
    final getal = int.tryParse(input);
    return getal != null && getal >= 0;
  }

  TextEditingController _getController(
      String wedstrijdId, String type, String value) {
    final key = '$wedstrijdId-$type';
    if (!controllers.containsKey(key)) {
      controllers[key] = TextEditingController(text: value);
    }
    return controllers[key]!;
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gefilterdeWedstrijden = alleWedstrijden
        .where((w) => w.speelronde == geselecteerdeSpeelronde)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Voorspel wedstrijden AB')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(34, (index) {
                final ronde = index + 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('Ronde $ronde'),
                    selected: geselecteerdeSpeelronde == ronde,
                    onSelected: (_) {
                      setState(() {
                        geselecteerdeSpeelronde = ronde;
                        _bepaalDeadline();
                      });
                    },
                  ),
                );
              }),
            ),
          ),
          if (deadline != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Deadline: ${DateFormat('EEEE dd-MM-yyyy – HH:mm', 'nl').format(deadline!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: gefilterdeWedstrijden.isEmpty
                ? const Center(child: Text('Geen wedstrijden gevonden.'))
                : ListView.builder(
                    itemCount: gefilterdeWedstrijden.length,
                    itemBuilder: (context, index) {
                      final wedstrijd = gefilterdeWedstrijden[index];
                      final voorspelling = voorspellingen[wedstrijd.id] ?? {};
                      final thuisScore = voorspelling['thuis'] ?? '';
                      final uitScore = voorspelling['uit'] ?? '';
                      final isPassed = _isDeadlinePassed();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  '${wedstrijd.thuis} - ${wedstrijd.uit}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Datum: ${DateFormat('dd-MM-yyyy').format(wedstrijd.datum)}',
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _scoreField(wedstrijd, 'thuis', thuisScore,
                                      uitScore, isPassed),
                                  const SizedBox(width: 8),
                                  const Text('-'),
                                  const SizedBox(width: 8),
                                  _scoreField(wedstrijd, 'uit', uitScore,
                                      thuisScore, isPassed),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _scoreField(Wedstrijd wedstrijd, String type, String current,
      String other, bool isDisabled) {
    final controller =
        _getController(wedstrijd.id, type, current); // unieke controller

    return SizedBox(
      width: 40,
      child: TextField(
        enabled: !isDisabled,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '0'),
        controller: controller,
        onChanged: (value) {
          if (_isGeldigGetal(value)) {
            final thuis = type == 'thuis' ? value : other;
            final uit = type == 'uit' ? value : other;
            _opslaanVoorspelling(wedstrijd, thuis, uit);
          }
        },
      ),
    );
  }
}
