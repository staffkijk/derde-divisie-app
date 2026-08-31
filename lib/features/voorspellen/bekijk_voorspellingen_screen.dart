import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/voorspellen/user_display_name.dart';

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
  bool _laadfout = false;
  bool _eindstandLaadfout = false;
  bool voorspellingenZichtbaar = true;
  String gebruikersnaam = 'Gebruiker';

  String _gekozenDivisie = 'A';

  final Map<int, List<_PredictionViewItem>> _perSpeelronde = {};
  List<int> _tabsRondes = [];

  List<String> _eindstandVolgorde = [];
  bool _heeftEindstand = false;
  Map<String, Map<String, dynamic>>? _matchesById;

  @override
  void initState() {
    super.initState();
    _gekozenDivisie = (widget.contextType == 'B') ? 'B' : 'A';
    _laadAlles();
  }

  Future<void> _laadAlles() async {
    if (mounted) {
      setState(() {
        geladen = false;
        _laadfout = false;
      });
    }
    try {
      await _laadGebruikerData();
      try {
        await _laadVoorspellingenVoorContext();
      } catch (_) {
        _laadfout = true;
      }
      try {
        await _laadEindstandVoorContext();
      } catch (_) {
        _eindstandLaadfout = true;
      }
    } catch (_) {
      _laadfout = true;
    } finally {
      if (mounted) setState(() => geladen = true);
    }
  }

  Future<void> _laadGebruikerData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = doc.data();
    if (data != null) {
      gebruikersnaam = resolveUserDisplayName(data, fallback: 'Gebruiker');
      voorspellingenZichtbaar = data['voorspellingenZichtbaar'] ?? true;
    }
  }

  Future<void> _laadVoorspellingenVoorContext() async {
    _perSpeelronde.clear();
    _tabsRondes.clear();
    final byMatch = <String, Map<String, dynamic>>{};
    Object? seasonError;
    Object? legacyError;
    try {
      final season = await SeasonPaths.currentSeasonPredictions
          .where('gebruikerId', isEqualTo: widget.userId)
          .get();
      for (final doc in season.docs) {
        final id = (doc.data()['wedstrijdId'] ?? doc.data()['matchId'] ?? '')
            .toString();
        if (id.isNotEmpty) byMatch[id] = doc.data();
      }
    } catch (error) {
      seasonError = error;
    }
    try {
      final legacy = await FirebaseFirestore.instance
          .collection('voorspellingen')
          .where('gebruikerId', isEqualTo: widget.userId)
          .get();
      for (final doc in legacy.docs) {
        final id = (doc.data()['wedstrijdId'] ?? doc.data()['matchId'] ?? '')
            .toString();
        if (id.isNotEmpty) byMatch.putIfAbsent(id, () => doc.data());
      }
    } catch (error) {
      legacyError = error;
    }
    if (seasonError != null && legacyError != null) throw seasonError;
    final matches = await _loadMatchesById();
    final items = byMatch.values
        .map((prediction) => _bouwItem(prediction, matches))
        .toList();
    final target =
        widget.contextType == 'algemeen' ? _gekozenDivisie : widget.contextType;
    for (final item in items.whereType<_PredictionViewItem>()) {
      final division =
          item.divisie ?? (item.wedstrijdId.startsWith('B') ? 'B' : 'A');
      if (division != target || !_magTonen(item.wedstrijdDatum)) continue;
      _perSpeelronde.putIfAbsent(item.speelronde, () => []).add(item);
    }
    _tabsRondes = _perSpeelronde.keys.toList()..sort();
  }

  Future<void> _laadEindstandVoorContext() async {
    _eindstandVolgorde = [];
    _heeftEindstand = false;

    final doelDivisie =
        widget.contextType == 'algemeen' ? _gekozenDivisie : widget.contextType;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
    for (final coll in ['eindstand_voorspellingen']) {
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

  Future<Map<String, Map<String, dynamic>>> _loadMatchesById() async {
    final cached = _matchesById;
    if (cached != null) return cached;
    final result = <String, Map<String, dynamic>>{};
    Object? seasonError;
    try {
      final season = await SeasonPaths.currentSeasonMatches.get();
      for (final doc in season.docs) {
        if (doc.id != '_meta') result[doc.id] = doc.data();
      }
    } catch (error) {
      seasonError = error;
    }
    if (result.isEmpty) {
      try {
        final legacy =
            await FirebaseFirestore.instance.collection('matches').get();
        for (final doc in legacy.docs) {
          result.putIfAbsent(doc.id, () => doc.data());
        }
      } catch (_) {
        if (seasonError != null) rethrow;
      }
    }
    _matchesById = result;
    return result;
  }

  _PredictionViewItem? _bouwItem(
    Map<String, dynamic> voorspelling,
    Map<String, Map<String, dynamic>> matches,
  ) {
    final wedstrijdId =
        (voorspelling['wedstrijdId'] ?? voorspelling['matchId'] ?? '')
            .toString();
    if (wedstrijdId.isEmpty) return null;
    final m = matches[wedstrijdId];
    if (m == null) return null;
    int? asInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    DateTime? asDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    }

    final division =
        (m['division'] ?? m['competitie'] ?? '').toString().toUpperCase();
    return _PredictionViewItem(
      wedstrijdId: wedstrijdId,
      speelronde: asInt(m['round'] ?? m['speelronde'] ?? m['ronde']) ?? 0,
      wedstrijdDatum:
          asDate(m['kickoff'] ?? m['datum'] ?? m['timestamp'] ?? m['date']) ??
              DateTime.fromMillisecondsSinceEpoch(0),
      thuis: (m['homeTeamName'] ?? m['homeTeam'] ?? m['thuisteam'] ?? '?')
          .toString(),
      uit: (m['awayTeamName'] ?? m['awayTeam'] ?? m['uitteam'] ?? '?')
          .toString(),
      uitslagThuis: asInt(m['homeScore'] ?? m['uitslagThuis']),
      uitslagUit: asInt(m['awayScore'] ?? m['uitslagUit']),
      divisie: division.contains('B')
          ? 'B'
          : division.contains('A')
              ? 'A'
              : null,
      scoreThuis:
          (voorspelling['scoreThuis'] ?? voorspelling['homeScore'] ?? '-')
              .toString(),
      scoreUit: (voorspelling['scoreUit'] ?? voorspelling['awayScore'] ?? '-')
          .toString(),
      punten: asInt(voorspelling['punten']),
      verwerkt:
          voorspelling['verwerkt'] == true || voorspelling['processed'] == true,
    );
  }

  bool _magTonen(DateTime wedstrijdDatum) {
    final deadline = DateTime(
        wedstrijdDatum.year, wedstrijdDatum.month, wedstrijdDatum.day, 12);
    return voorspellingenZichtbaar || DateTime.now().isAfter(deadline);
  }

  Widget _teamColumn(String naam) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamLogo(teamName: naam, size: 36),
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
    if (_eindstandLaadfout || !_heeftEindstand) {
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
                TeamLogo(teamName: team, size: 28),
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
      _laadfout = false;
      _eindstandLaadfout = false;
    });
    try {
      await _laadVoorspellingenVoorContext();
      try {
        await _laadEindstandVoorContext();
      } catch (_) {
        _eindstandLaadfout = true;
      }
    } catch (_) {
      _laadfout = true;
    } finally {
      if (mounted) setState(() => geladen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!geladen) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_laadfout) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('De voorspellingen konden niet worden geladen.'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _laadAlles, child: const Text('Opnieuw proberen')),
            ],
          ),
        ),
      );
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
