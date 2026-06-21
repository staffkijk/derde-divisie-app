import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('PeriodeStanden');

const List<String> clubsDivisieA = [
  'DOVO',
  'Eemdijk',
  'Scherpenzeel',
  'Staphorst',
  'DVS33 Ermelo',
  'Sparta Nijkerk',
  'TEC',
  'Urk',
  'Hoogeveen',
  'HSC21',
  'Sportlust46',
  'Excelsior31',
  'Hercules',
  'SC Genemuiden',
  'Huizen',
  'Harkemase Boys',
  'Rohda Raalte',
  'ADO20',
];

const List<String> clubsDivisieB = [
  'Noordwijk',
  'Scheveningen',
  'SteDoCo',
  'Zwaluwen',
  'Kloetinge',
  'RBC',
  'Groene Ster',
  'Rijnvogels',
  'UNA',
  'ASWH',
  'UDI19',
  'TOGB',
  'FC Lisse',
  'Gemert',
  'sv Meerssen',
  'Blauw Geel38 JUMBO',
  'Goes',
  'VVSB',
];

String _normClubKey(String value) {
  return value
      .toUpperCase()
      .replaceAll('’', '')
      .replaceAll("'", '')
      .replaceAll(' ', '')
      .replaceAll('/', '')
      .replaceAll('.', '')
      .replaceAll('-', '')
      .trim();
}

class PeriodeStandenScreen extends StatelessWidget {
  const PeriodeStandenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 1,
          title: const Text('Periodestanden'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Divisie A'),
              Tab(text: 'Divisie B'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PeriodeTabView(divisieLetter: 'A'),
            PeriodeTabView(divisieLetter: 'B'),
          ],
        ),
      ),
    );
  }
}

class PeriodeTabView extends StatelessWidget {
  final String divisieLetter;

  const PeriodeTabView({
    super.key,
    required this.divisieLetter,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    final widgets = [
      PeriodeStandWidget(periode: 1, divisieLetter: divisieLetter),
      PeriodeStandWidget(periode: 2, divisieLetter: divisieLetter),
      PeriodeStandWidget(periode: 3, divisieLetter: divisieLetter),
    ];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widgets
                  .map(
                    (w) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: w,
                      ),
                    ),
                  )
                  .toList(),
            )
          : ListView.separated(
              itemCount: widgets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, index) => widgets[index],
            ),
    );
  }
}

class PeriodeStandWidget extends StatelessWidget {
  final int periode;
  final String divisieLetter;

  const PeriodeStandWidget({
    super.key,
    required this.periode,
    required this.divisieLetter,
  });

  List<String> get clubs {
    return divisieLetter == 'A' ? clubsDivisieA : clubsDivisieB;
  }

  String clubNaamNaarBestandsnaam(String clubNaam) {
    final cleanName = clubNaam
        .replaceAll(' ', '')
        .replaceAll('/', '')
        .replaceAll("'", '')
        .replaceAll('’', '')
        .replaceAll('.', '')
        .replaceAll('-', '');

    return 'assets/images/logo_$cleanName.png';
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final divisieDocId = divisieLetter == 'A' ? 'dda' : 'ddb';

    return SizedBox(
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periode $periode - Divisie $divisieLetter',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('periodestanden')
                  .doc(divisieDocId)
                  .collection('periode_$periode')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _log.warning(
                    'Fout in periode $periode divisie $divisieLetter: ${snapshot.error}',
                  );

                  return const Text('Fout bij laden van deze periode.');
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final Map<String, Map<String, dynamic>> dataMap = {};

                for (final doc in docs) {
                  final data = doc.data();
                  final clubUitData = (data['club'] ?? '').toString().trim();

                  if (clubUitData.isNotEmpty) {
                    dataMap[_normClubKey(clubUitData)] = data;
                  }

                  dataMap.putIfAbsent(_normClubKey(doc.id), () => data);
                }

                final List<Map<String, dynamic>> gecombineerdeData =
                    clubs.map((club) {
                  final data = dataMap[_normClubKey(club)];

                  final doelpuntenVoor = _toInt(data?['doelpuntenVoor']);
                  final doelpuntenTegen = _toInt(data?['doelpuntenTegen']);

                  return {
                    'club': club,
                    'gespeeld': _toInt(data?['gespeeld']),
                    'gewonnen': _toInt(data?['gewonnen']),
                    'gelijk': _toInt(data?['gelijk']),
                    'verloren': _toInt(data?['verloren']),
                    'punten': _toInt(data?['punten']),
                    'doelpuntenVoor': doelpuntenVoor,
                    'doelpuntenTegen': doelpuntenTegen,
                    'doelsaldo': data?['doelsaldo'] == null
                        ? doelpuntenVoor - doelpuntenTegen
                        : _toInt(data?['doelsaldo']),
                  };
                }).toList();

                gecombineerdeData.sort((a, b) {
                  if (a['punten'] != b['punten']) {
                    return (b['punten'] as int).compareTo(a['punten'] as int);
                  }

                  if (a['gespeeld'] != b['gespeeld']) {
                    return (a['gespeeld'] as int)
                        .compareTo(b['gespeeld'] as int);
                  }

                  if (a['doelsaldo'] != b['doelsaldo']) {
                    return (b['doelsaldo'] as int)
                        .compareTo(a['doelsaldo'] as int);
                  }

                  if (a['doelpuntenVoor'] != b['doelpuntenVoor']) {
                    return (b['doelpuntenVoor'] as int)
                        .compareTo(a['doelpuntenVoor'] as int);
                  }

                  if (a['doelpuntenTegen'] != b['doelpuntenTegen']) {
                    return (a['doelpuntenTegen'] as int)
                        .compareTo(b['doelpuntenTegen'] as int);
                  }

                  return (a['club'] as String).compareTo(b['club'] as String);
                });

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 8,
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Club')),
                      DataColumn(label: Text('G')),
                      DataColumn(label: Text('W')),
                      DataColumn(label: Text('G')),
                      DataColumn(label: Text('V')),
                      DataColumn(
                        label: Text(
                          'Pnt',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(label: Text('DS')),
                      DataColumn(label: Text('DV-DT')),
                    ],
                    rows: List.generate(gecombineerdeData.length, (index) {
                      final team = gecombineerdeData[index];
                      final clubNaam = team['club'] as String;
                      final logoPath = clubNaamNaarBestandsnaam(clubNaam);

                      final rowColor =
                          index == 0 ? Colors.green.shade100 : null;

                      return DataRow(
                        color: rowColor != null
                            ? WidgetStateProperty.all(rowColor)
                            : null,
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(
                            Row(
                              children: [
                                Image.asset(
                                  logoPath,
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/default_logo.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(child: Text(clubNaam)),
                              ],
                            ),
                          ),
                          DataCell(Text('${team['gespeeld']}')),
                          DataCell(Text('${team['gewonnen']}')),
                          DataCell(Text('${team['gelijk']}')),
                          DataCell(Text('${team['verloren']}')),
                          DataCell(Text('${team['punten']}')),
                          DataCell(Text('${team['doelsaldo']}')),
                          DataCell(
                            Text(
                              '${team['doelpuntenVoor']}-${team['doelpuntenTegen']}',
                            ),
                          ),
                        ],
                      );
                    }),
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