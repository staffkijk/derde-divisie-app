import 'package:flutter/material.dart';

import 'package:derde_divisie/data/services/analytics_service.dart';
import 'stand_derde_divisie_screen.dart';

class HistoricalStandingsScreen extends StatefulWidget {
  const HistoricalStandingsScreen({
    super.key,
    this.initialSeason = '2025-2026',
    this.initialDivision = 'A',
  });

  final String initialSeason;
  final String initialDivision;

  @override
  State<HistoricalStandingsScreen> createState() =>
      _HistoricalStandingsScreenState();
}

class _HistoricalStandingsScreenState extends State<HistoricalStandingsScreen> {
  late String _season;
  late String _division;

  @override
  void initState() {
    super.initState();
    _season = kArchiefSeizoenen.contains(widget.initialSeason)
        ? widget.initialSeason
        : kArchiefSeizoenen.first;
    _division = widget.initialDivision == 'B' ? 'B' : 'A';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackHistoryViewed(source: 'history_screen');
    });
  }

  void _trackHistoryViewed({required String source}) {
    AnalyticsService.instance.trackHistoryViewed(
      division: _division,
      season: _season,
      source: source,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historische eindstanden')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth >= 900 ? 28 : 14,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Eindstanden per seizoen',
                      style: TextStyle(
                        color: Color(0xFF153B2A),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kies een seizoen en divisie om de volledige eindstand te bekijken.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String>(
                            value: _season,
                            decoration:
                                const InputDecoration(labelText: 'Seizoen'),
                            items: kArchiefSeizoenen
                                .map(
                                  (season) => DropdownMenuItem(
                                    value: season,
                                    child: Text(season.replaceAll('-', '/')),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _season = value);
                                _trackHistoryViewed(source: 'season_filter');
                              }
                            },
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'A', label: Text('Divisie A')),
                            ButtonSegment(value: 'B', label: Text('Divisie B')),
                          ],
                          selected: {_division},
                          onSelectionChanged: (selection) {
                            setState(() => _division = selection.first);
                            _trackHistoryViewed(source: 'division_filter');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE3EADF)),
                      ),
                      child: StandDerdeDivisie(
                        divisie: 'Derde Divisie $_division',
                        seizoen: _season,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
