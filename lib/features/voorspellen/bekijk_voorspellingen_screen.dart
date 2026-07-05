import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BekijkVoorspellingenScreen extends StatefulWidget {
  final String userId;

  /// 'algemeen' (met A/B toggle), of geforceerd 'A' of 'B'
  final String contextType;

  const BekijkVoorspellingenScreen({
    super.key,
    required this.userId,
    required this.contextType,
  });

  @override
  State<BekijkVoorspellingenScreen> createState() =>
      _BekijkVoorspellingenScreenState();
}

class _BekijkVoorspellingenScreenState
    extends State<BekijkVoorspellingenScreen> {
  bool geladen = false;
  bool voorspellingenZichtbaar = true;
  String gebruikersnaam = 'Gebruiker';

  String _gekozenDivisie = 'A';

  final Map<int, List<_PredictionViewItem>> _perSpeelronde = {};
  List<int> _tabsRondes = [];

  List<String> _eindstandVolgorde = [];
  bool _heeftEindstand = false;

  @override
  void initState() {
    super.initState();
    _gekozenDivisie = (widget.contextType == 'B') ? 'B' : 'A';
    _laadAlles();
  }

  Future<void> _laadAlles() async {
    await _laadGebruikerData();
    await _laadVoorspellingenVoorContext();
    await _laadEindstandVoorContext();
    setState(() => geladen = true);
  }

  Future<void> _laadGebruikerData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = doc.data();
    if (data != null) {
      gebruikersnaam = data['username'] ?? 'Gebruiker';
      voorspellingenZichtbaar = data['voorspellingenZichtbaar'] ?? true;
    }
  }

  Future<void> _laadVoorspellingenVoorContext() async {
    _perSpeelronde.clear();
    _tabsRondes.clear();

    final snapshot = await FirebaseFirestore.instance
        .collection('voorspellingen')
        .where('gebruikerId', isEqualTo: widget.userId)
        .get();

    final futures = <Future<_PredictionViewItem?>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final wedstrijdId = data['wedstrijdId'] as String? ?? '';
      if (wedstrijdId.isEmpty) continue;
      futures.add(_bouwItem(data));
    }

    final items = await Future.wait(futures);
    final geldigeItems = items.whereType<_PredictionViewItem>().toList();

    final doelDivisie =
        widget.contextType == 'algemeen' ? _gekozenDivisie : widget.contextType;

    for (final it in geldigeItems) {
      final divisie =
          it.divisie ?? (it.wedstrijdId.startsWith('B') ? 'B' : 'A');
      if (doelDivisie != 'algemeen' && divisie != doelDivisie) continue;
      if (!_magTonen(it.wedstrijdId, it.wedstrijdDatum)) continue;
      _perSpeelronde.putIfAbsent(it.speelronde, () => []).add(it);
    }

    _tabsRondes = _perSpeelronde.keys.toList()..sort();
  }

  Future<void> _laadEindstandVoorContext() async {
    _eindstandVolgorde = [];
    _heeftEindstand = false;

    final doelDivisie =
        widget.contextType == 'algemeen' ? _gekozenDivisie : widget.contextType;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
    for (final coll in [
      'eindstand_voorspellingen',
      'eindstandVoorspellingen'
    ]) {
      final q1 = await FirebaseFirestore.instance
          .collection(coll)
          .where('gebruikerId', isEqualTo: widget.userId)
          .where('divisie', isEqualTo: doelDivisie)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        docs = q1.docs;
        break;
      }
      final q2 = await FirebaseFirestore.instance
          .collection(coll)
          .where('userId', isEqualTo: widget.userId)
          .where('divisie', isEqualTo: doelDivisie)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        docs = q2.docs;
        break;
      }
    }

    if (docs.isEmpty) {
      _heeftEindstand = false;
      return;
    }

    final data = docs.first.data();
    List<dynamic>? arr = data['ranking'] ??
        data['volgorde'] ??
        data['teams'] ??
        data['voorspelling'];

    if (arr != null) {
      _eindstandVolgorde = arr.map((e) => e.toString()).toList();
      final now = DateTime.now();
      final unlock = DateTime(now.year, 8, 31, 12);
      if (voorspellingenZichtbaar || now.isAfter(unlock)) {
        _heeftEindstand = _eindstandVolgorde.isNotEmpty;
      }
    }
  }

  Future<_PredictionViewItem?> _bouwItem(
      Map<String, dynamic> voorspelling) async {
    try {
      final wedstrijdId = voorspelling['wedstrijdId'] as String;
      final matchSnap = await FirebaseFirestore.instance
          .collection('matches')
          .doc(wedstrijdId)
          .get();
      if (!matchSnap.exists) return null;

      final m = matchSnap.data() as Map<String, dynamic>;
      final thuis = m['thuisteam'] as String? ?? '?';
      final uit = m['uitteam'] as String? ?? '?';
      final uitslagThuis = m['uitslagThuis'] as int?;
      final uitslagUit = m['uitslagUit'] as int?;
      final speelronde = (m['speelronde'] ?? m['ronde'] ?? 0) as int;
      final datum = (m['datum'] as Timestamp).toDate();
      final competitie = (m['competitie'] as String?)?.toUpperCase();

      return _PredictionViewItem(
        wedstrijdId: wedstrijdId,
        speelronde: speelronde,
        wedstrijdDatum: datum,
        thuis: thuis,
        uit: uit,
        uitslagThuis: uitslagThuis,
        uitslagUit: uitslagUit,
        divisie: (competitie == 'A' || competitie == 'B') ? competitie : null,
        scoreThuis: (voorspelling['scoreThuis']?.toString() ?? '-'),
        scoreUit: (voorspelling['scoreUit']?.toString() ?? '-'),
        punten: voorspelling['punten'] as int?,
        verwerkt: voorspelling['verwerkt'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  bool _magTonen(String wedstrijdId, DateTime wedstrijdDatum) {
    final isCorrectContext = widget.contextType == 'algemeen' ||
        (widget.contextType == 'A' && wedstrijdId.startsWith('A')) ||
        (widget.contextType == 'B' && wedstrijdId.startsWith('B'));

    final deadlineVerstreken = DateTime.now().isAfter(DateTime(
        wedstrijdDatum.year, wedstrijdDatum.month, wedstrijdDatum.day, 12));

    return isCorrectContext && (voorspellingenZichtbaar || deadlineVerstreken);
  }

  String getLogoPath(String team) {
    final cleanName = team
        .replaceAll(" ", "")
        .replaceAll("'", "")
        .replaceAll("/", "")
        .replaceAll(".", "")
        .replaceAll("-", "");
    return 'assets/images/logo_$cleanName.png';
  }

  Widget _teamColumn(String naam) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          getLogoPath(naam),
          width: 36,
          height: 36,
          errorBuilder: (_, __, ___) => const Icon(Icons.shield),
        ),
        const SizedBox(height: 6),
        Text(
          naam,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _centerColumn({
    required String voorspelling,
    int? uitslagThuis,
    int? uitslagUit,
    int? punten,
    required bool verwerkt,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            voorspelling,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (verwerkt && uitslagThuis != null && uitslagUit != null)
            Text('Uitslag: $uitslagThuis - $uitslagUit',
                style: const TextStyle(fontSize: 13)),
          if (punten != null && verwerkt)
            Text('🎯 $punten pt',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _voorspellingCard(_PredictionViewItem it) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Expanded(child: _teamColumn(it.thuis)),
            Expanded(
              flex: 2,
              child: _centerColumn(
                voorspelling: '${it.scoreThuis} - ${it.scoreUit}',
                uitslagThuis: it.uitslagThuis,
                uitslagUit: it.uitslagUit,
                punten: it.punten,
                verwerkt: it.verwerkt,
              ),
            ),
            Expanded(child: _teamColumn(it.uit)),
          ],
        ),
      ),
    );
  }

  Widget _eindstandView() {
    if (!_heeftEindstand) {
      return const Center(
          child: Text('Geen zichtbare eindstand-voorspelling.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _eindstandVolgorde.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.transparent),
      itemBuilder: (_, i) {
        final positie = i + 1;
        final team = _eindstandVolgorde[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$positie',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Image.asset(getLogoPath(team),
                    width: 28,
                    height: 28,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(team, style: const TextStyle(fontSize: 16))),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _wisselDivisie(String nieuw) async {
    if (_gekozenDivisie == nieuw) return;
    setState(() {
      geladen = false;
      _gekozenDivisie = nieuw;
    });
    await _laadVoorspellingenVoorContext();
    await _laadEindstandVoorContext();
    setState(() => geladen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!geladen) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final titel = widget.contextType == 'algemeen'
        ? 'Voorspellingen van $gebruikersnaam'
        : 'Voorspellingen (${widget.contextType}) van $gebruikersnaam';

    final tabs = <Tab>[];
    final views = <Widget>[];

    // Altijd Eindstand eerst tonen
    tabs.add(const Tab(text: 'Eindstand'));
    views.add(_eindstandView());

    for (final ronde in _tabsRondes) {
      tabs.add(Tab(text: 'Speelronde $ronde'));
      final items = _perSpeelronde[ronde]!
        ..sort((a, b) => a.wedstrijdDatum.compareTo(b.wedstrijdDatum));
      views.add(ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => _voorspellingCard(items[i]),
      ));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titel),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: tabs.isNotEmpty
                ? TabBar(
                    isScrollable: true,
                    tabs: tabs,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.white,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        body: Column(
          children: [
            if (widget.contextType == 'algemeen')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Divisie A'),
                      selected: _gekozenDivisie == 'A',
                      onSelected: (_) => _wisselDivisie('A'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Divisie B'),
                      selected: _gekozenDivisie == 'B',
                      onSelected: (_) => _wisselDivisie('B'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: tabs.isNotEmpty
                  ? TabBarView(children: views)
                  : Center(child: Text('Geen zichtbare voorspellingen.')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionViewItem {
  final String wedstrijdId;
  final int speelronde;
  final DateTime wedstrijdDatum;
  final String thuis;
  final String uit;
  final int? uitslagThuis;
  final int? uitslagUit;
  final String? divisie;
  final String scoreThuis;
  final String scoreUit;
  final int? punten;
  final bool verwerkt;

  _PredictionViewItem({
    required this.wedstrijdId,
    required this.speelronde,
    required this.wedstrijdDatum,
    required this.thuis,
    required this.uit,
    required this.uitslagThuis,
    required this.uitslagUit,
    required this.divisie,
    required this.scoreThuis,
    required this.scoreUit,
    required this.punten,
    required this.verwerkt,
  });
}
