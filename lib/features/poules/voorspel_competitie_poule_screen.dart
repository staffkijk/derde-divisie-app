import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('TeamcodeUpdater');

class VoorspelCompetitiePouleScreen extends StatefulWidget {
  final String pouleId;
  final String competitie; // bv. 'dda' of 'ddb'

  const VoorspelCompetitiePouleScreen({
    super.key,
    required this.pouleId,
    required this.competitie,
  });

  @override
  State<VoorspelCompetitiePouleScreen> createState() =>
      _VoorspelCompetitiePouleScreenState();
}

class _VoorspelCompetitiePouleScreenState
    extends State<VoorspelCompetitiePouleScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  List<DocumentSnapshot> wedstrijden = [];
  Map<String, Map<String, String>> voorspellingen = {};
  Map<String, int> behaaldePunten = {};
  Map<String, int?> werkelijkeThuis = {};
  Map<String, int?> werkelijkeUit = {};

  bool isLoading = true;

  String _mapCompetitie(String c) {
    switch (c.toLowerCase()) {
      case 'dda':
        return 'Derde Divisie A';
      case 'ddb':
        return 'Derde Divisie B';
      default:
        return c;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWedstrijdenEnVoorspellingen();
  }

  Future<void> _loadWedstrijdenEnVoorspellingen() async {
    final comp = _mapCompetitie(widget.competitie);

    final matchesSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: comp)
        .get();

    final predictionsSnapshot = await FirebaseFirestore.instance
        .collection('poule_predictions')
        .where('pouleId', isEqualTo: widget.pouleId)
        .where('gebruikerId', isEqualTo: userId)
        .get();

    wedstrijden = matchesSnapshot.docs;
    wedstrijden.sort((a, b) {
      final aDate = (a['datum'] as Timestamp).toDate();
      final bDate = (b['datum'] as Timestamp).toDate();
      return aDate.compareTo(bDate);
    });

    for (final doc in predictionsSnapshot.docs) {
      final data = doc.data();
      final wedstrijdId = data['wedstrijdId'];
      voorspellingen[wedstrijdId] = {
        'home': (data['scoreThuis'] ?? '').toString(),
        'away': (data['scoreUit'] ?? '').toString(),
      };
      if (data.containsKey('punten')) {
        behaaldePunten[wedstrijdId] = data['punten'];
      }
    }

    for (final doc in wedstrijden) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      werkelijkeThuis[id] =
          data['uitslagThuis'] is int ? data['uitslagThuis'] : null;
      werkelijkeUit[id] = data['uitslagUit'] is int ? data['uitslagUit'] : null;
    }

    setState(() => isLoading = false);
  }

  bool _magNogVoorspellen(DateTime wedstrijdDatum) {
    final deadline = DateTime(
      wedstrijdDatum.year,
      wedstrijdDatum.month,
      wedstrijdDatum.day,
      12,
    );
    return DateTime.now().isBefore(deadline);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voorspel teamwedstrijden')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: wedstrijden.length,
              itemBuilder: (context, index) {
                final match = wedstrijden[index];
                final data = match.data() as Map<String, dynamic>;
                final wedstrijdId = match.id;
                final date = (data['datum'] as Timestamp).toDate();
                final magVoorspellen = _magNogVoorspellen(date);

                final homeText = voorspellingen[wedstrijdId]?['home'] ?? '';
                final awayText = voorspellingen[wedstrijdId]?['away'] ?? '';

                final thuisUitslag = werkelijkeThuis[wedstrijdId];
                final uitUitslag = werkelijkeUit[wedstrijdId];
                final punten = behaaldePunten[wedstrijdId];

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['thuisteam']} - ${data['uitteam']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Speeldatum: ${DateFormat('EEEE d-MM-yyyy – HH:mm', 'nl').format(date)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        magVoorspellen
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: homeText,
                                      decoration:
                                          const InputDecoration(hintText: 'H'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        voorspellingen[wedstrijdId] ??= {};
                                        voorspellingen[wedstrijdId]!['home'] =
                                            val;
                                        _saveVoorspelling(wedstrijdId);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: awayText,
                                      decoration:
                                          const InputDecoration(hintText: 'A'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        voorspellingen[wedstrijdId] ??= {};
                                        voorspellingen[wedstrijdId]!['away'] =
                                            val;
                                        _saveVoorspelling(wedstrijdId);
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : const Text('Deadline voorbij'),
                        const SizedBox(height: 6),
                        if (thuisUitslag != null && uitUitslag != null)
                          Text(
                            'Uitslag: $thuisUitslag - $uitUitslag',
                            style: const TextStyle(color: Colors.black87),
                          )
                        else
                          const Text('Uitslag nog niet bekend'),
                        if (punten != null &&
                            thuisUitslag != null &&
                            uitUitslag != null)
                          Text(
                            'Behaalde punten: +$punten',
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _saveVoorspelling(String wedstrijdId) async {
    final prediction = voorspellingen[wedstrijdId];
    if (prediction == null) return;

    final scoreThuis = int.tryParse(prediction['home'] ?? '');
    final scoreUit = int.tryParse(prediction['away'] ?? '');

    if (scoreThuis == null || scoreUit == null) return;

    final docId = '${widget.pouleId}_${userId}_$wedstrijdId';
    _log.info('✅ Alles verwerkt');
    _log.info('⏺ Opslaan: $docId');

    await FirebaseFirestore.instance
        .collection('poule_predictions')
        .doc(docId)
        .set({
      'gebruikerId': userId,
      'pouleId': widget.pouleId,
      'wedstrijdId': wedstrijdId,
      'scoreThuis': scoreThuis,
      'scoreUit': scoreUit,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
