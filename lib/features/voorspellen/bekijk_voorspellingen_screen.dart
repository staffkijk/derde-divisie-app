import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/voorspellen/prediction_details_loader.dart';
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
  bool voorspellingenZichtbaar = true;
  String gebruikersnaam = 'Gebruiker';
  String? _laadFout;

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
    _laadFout = null;
    try {
      await _laadGebruikerData().timeout(const Duration(seconds: 20));
      await _laadVoorspellingenVoorContext()
          .timeout(const Duration(seconds: 30));

      // Een eindstandvoorspelling is aanvullend. Als die niet kan worden
      // geladen, mogen de wedstrijdvoorspellingen niet op een spinner blijven
      // hangen.
      try {
        await _laadEindstandVoorContext().timeout(const Duration(seconds: 15));
      } catch (error, stackTrace) {
        developer.log(
          'Eindstandvoorspelling van gebruiker kon niet worden geladen',
          name: 'BekijkVoorspellingen',
          error: error,
          stackTrace: stackTrace,
        );
        _eindstandVolgorde = [];
        _heeftEindstand = false;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Voorspellingen van gebruiker konden niet worden geladen',
        name: 'BekijkVoorspellingen',
        error: error,
        stackTrace: stackTrace,
      );
      _laadFout =
          'De voorspellingen konden niet worden geladen. Probeer het opnieuw.';
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

    final details = await PredictionDetailsLoader().load(widget.userId);
    final byMatch = details.predictions;
    final matchesById = details.matches;
    final doelDivisie =
        widget.contextType == 'algemeen' ? _gekozenDivisie : widget.contextType;

    for (final entry in byMatch.entries) {
      final prediction = entry.value;
      final wedstrijdId = entry.key;
      if (wedstrijdId.isEmpty) continue;

      final matchData = matchesById[wedstrijdId];
      if (matchData == null) continue;

      final item = _bouwItem(
        voorspelling: prediction,
        wedstrijdId: wedstrijdId,
        wedstrijd: matchData,
      );
      if (item == null) continue;

      final divisie =
          item.divisie ?? (item.wedstrijdId.startsWith('B') ? 'B' : 'A');
      if (doelDivisie != 'algemeen' && divisie != doelDivisie) continue;
      if (!_magTonen(item.wedstrijdDatum)) continue;

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
    // Alleen de huidige, door Firestore Rules ondersteunde collectie lezen.
    // De oude camelCase fallback had geen read-rule. Bij gebruikers zonder
    // eindstanddocument leverde die daarom permission-denied op, waarna het
    // scherm op de laadspinner bleef staan.
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

  _PredictionViewItem? _bouwItem({
    required Map<String, dynamic> voorspelling,
    required String wedstrijdId,
    required Map<String, dynamic> wedstrijd,
  }) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = wedstrijd[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    int? readInt(List<String> keys) {
      for (final key in keys) {
        final value = wedstrijd[key];
        if (value is num) return value.toInt();
        final parsed = int.tryParse(value?.toString() ?? '');
        if (parsed != null) return parsed;
      }
      return null;
    }

    int? predictionInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final thuis = readString(
      const ['homeTeamName', 'homeTeam', 'thuisTeam', 'thuisteam'],
    );
    final uit = readString(
      const ['awayTeamName', 'awayTeam', 'uitTeam', 'uitteam'],
    );
    final speelronde = readInt(const ['round', 'speelronde', 'ronde']);
    final datum = MatchDateTimeFormatter.dateTimeFromData(wedstrijd);

    if (thuis.isEmpty ||
        uit.isEmpty ||
        speelronde == null ||
        speelronde <= 0 ||
        datum == null) {
      return null;
    }

    final rawDivisie =
        (wedstrijd['division'] ?? wedstrijd['competitie'] ?? '').toString();
    final normalizedDivisie = SeasonConfig.normalizeDivisionCode(rawDivisie);
    final divisie = normalizedDivisie == 'A' || normalizedDivisie == 'B'
        ? normalizedDivisie
        : null;

    return _PredictionViewItem(
      wedstrijdId: wedstrijdId,
      speelronde: speelronde,
      wedstrijdDatum: datum,
      thuis: thuis,
      uit: uit,
      uitslagThuis: readInt(const ['homeScore', 'thuisScore', 'uitslagThuis']),
      uitslagUit: readInt(const ['awayScore', 'uitScore', 'uitslagUit']),
      divisie: divisie,
      scoreThuis: (voorspelling['scoreThuis']?.toString() ?? '-'),
      scoreUit: (voorspelling['scoreUit']?.toString() ?? '-'),
      punten: predictionInt(voorspelling['punten']),
      verwerkt: voorspelling['verwerkt'] == true,
    );
  }

  bool _magTonen(DateTime wedstrijdDatum) {
    final deadlineVerstreken = DateTime.now().isAfter(DateTime(
      wedstrijdDatum.year,
      wedstrijdDatum.month,
      wedstrijdDatum.day,
      12,
    ));

    return voorspellingenZichtbaar || deadlineVerstreken;
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
      _laadFout = null;
      _gekozenDivisie = nieuw;
    });

    try {
      await _laadVoorspellingenVoorContext();
      try {
        await _laadEindstandVoorContext();
      } catch (error, stackTrace) {
        developer.log(
          'Eindstandvoorspelling na divisiewissel kon niet worden geladen',
          name: 'BekijkVoorspellingen',
          error: error,
          stackTrace: stackTrace,
        );
        _eindstandVolgorde = [];
        _heeftEindstand = false;
      }
    } catch (error, stackTrace) {
      developer.log(
        'Voorspellingen na divisiewissel konden niet worden geladen',
        name: 'BekijkVoorspellingen',
        error: error,
        stackTrace: stackTrace,
      );
      _laadFout =
          'De voorspellingen konden niet worden geladen. Probeer het opnieuw.';
    } finally {
      if (mounted) setState(() => geladen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!geladen) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_laadFout != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voorspellingen')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                Text(
                  _laadFout!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => geladen = false);
                    _laadAlles();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Opnieuw proberen'),
                ),
              ],
            ),
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
