import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../wedstrijd.dart';
import '../wedstrijden_data.dart';
import '../voorspellen.dart';

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

  @override
  void initState() {
    super.initState();
    _laadWedstrijdenVoorSpeelronde(_huidigeSpeelronde);
  }

  void _laadWedstrijdenVoorSpeelronde(int speelronde) {
    final alleWedstrijden = getWedstrijden(widget.divisie);
    final wedstrijdenVoorRonde =
        alleWedstrijden.where((w) => w.speelronde == speelronde).toList();
    wedstrijdenVoorRonde.sort((a, b) => a.datum.compareTo(b.datum));
    DateTime? eersteDatum = wedstrijdenVoorRonde.isNotEmpty
        ? wedstrijdenVoorRonde.first.datum
        : null;

    setState(() {
      _wedstrijden = wedstrijdenVoorRonde;
      _deadline = eersteDatum != null
          ? DateTime(eersteDatum.year, eersteDatum.month, eersteDatum.day, 12)
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voorspel wedstrijden ${widget.divisie}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 34,
              itemBuilder: (context, index) {
                final ronde = index + 1;
                final isSelected = _huidigeSpeelronde == ronde;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text('Ronde $ronde'),
                    selected: isSelected,
                    selectedColor: Colors.orange.shade100,
                    onSelected: (_) {
                      setState(() {
                        _huidigeSpeelronde = ronde;
                        _laadWedstrijdenVoorSpeelronde(ronde);
                      });
                    },
                  ),
                );
              },
            ),
          ),
          if (_deadline != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Deadline voorspellen: ${DateFormat('EEEE d-MM-yyyy – HH:mm', 'nl').format(_deadline!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _wedstrijden.length,
              itemBuilder: (context, index) {
                final wedstrijd = _wedstrijden[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${wedstrijd.thuis} - ${wedstrijd.uit}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Datum: ${DateFormat('yyyy-MM-dd').format(wedstrijd.datum)}'),
                          const SizedBox(height: 8),
                          VoorspellingWidget(
                            key: ValueKey(wedstrijd.id),
                            wedstrijd: wedstrijd,
                            deadline: _deadline,
                          ),
                        ],
                      ),
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
}
