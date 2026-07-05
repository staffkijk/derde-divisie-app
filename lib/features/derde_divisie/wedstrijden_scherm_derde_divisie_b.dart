import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/models/wedstrijd.dart';
import 'package:derde_divisie/data/services/wedstrijden_ddb.dart';
import 'package:derde_divisie/helpers/sync_service.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';
import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/config/season_config.dart';

class WedstrijdenSchermDerdeDivisieB extends StatefulWidget {
  final String divisie;

  const WedstrijdenSchermDerdeDivisieB({super.key, required this.divisie});

  @override
  State<WedstrijdenSchermDerdeDivisieB> createState() =>
      _WedstrijdenSchermDerdeDivisieBState();
}

class _WedstrijdenSchermDerdeDivisieBState
    extends State<WedstrijdenSchermDerdeDivisieB> {
  int _huidigeSpeelronde = 1;
  DateTime? _deadline;
  List<Wedstrijd> _wedstrijden = [];

  final Map<String, DateTime> _fsDatums = {};
  final Map<String, int?> _werkelijkeUitslagThuis = {};
  final Map<String, int?> _werkelijkeUitslagUit = {};
  final Map<String, int?> _behaaldePunten = {};
  final Map<String, int?> _voorspellingThuis = {};
  final Map<String, int?> _voorspellingUit = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _seasonMatchesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _matchesSub;
  bool _usingSeasonMatches = false;
  String? _expandedQuickPickId;
  String? _favoriteTeamId;
  bool _favoriteOnly = false;

  @override
  void initState() {
    super.initState();
    _init();
    _loadFavoriteTeam();
  }

  Future<void> _loadFavoriteTeam() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = snapshot.data();
    final team = SeasonConfig.teamById(
          (data?['favoriteTeamSlug'] ?? '').toString(),
        ) ??
        SeasonConfig.teamByName(
          (data?['favoriteTeamName'] ?? data?['favorieteClub'] ?? '')
              .toString(),
        );
    if (mounted && team != null) setState(() => _favoriteTeamId = team.id);
  }

  @override
  void dispose() {
    _seasonMatchesSub?.cancel();
    _matchesSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _bepaalHuidigeSpeelrondeOpDatum();
    _laadWedstrijdenBasisVoorSpeelronde(_huidigeSpeelronde);
    _listenSeasonMatchesFirestore(_huidigeSpeelronde);
    _listenMatchesFirestore(_huidigeSpeelronde);
    await _laadVoorspellingen();
    setState(() {});
  }

  /// 🔹 Automatische speelronde o.b.v. datum
  void _bepaalHuidigeSpeelrondeOpDatum() {
    final vandaag = DateTime.now();
    final toekomstige = wedstrijdenDerdeDivisieB
        .where((w) => w.datum.isAfter(vandaag))
        .map((w) => w.speelronde)
        .toList();

    if (toekomstige.isNotEmpty) {
      _huidigeSpeelronde =
          toekomstige.reduce((a, b) => a < b ? a : b).clamp(1, 34);
    } else {
      _huidigeSpeelronde = wedstrijdenDerdeDivisieB
          .map((w) => w.speelronde)
          .reduce((a, b) => a > b ? a : b);
    }
  }

  void _laadWedstrijdenBasisVoorSpeelronde(int speelronde) {
    final wedstrijdenVoorRonde = wedstrijdenDerdeDivisieB
        .where((w) => w.speelronde == speelronde)
        .toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
    _wedstrijden = wedstrijdenVoorRonde;

    _werkelijkeUitslagThuis.clear();
    _werkelijkeUitslagUit.clear();
    _behaaldePunten.clear();
    _fsDatums.clear();
    _deadline = null;
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  int? _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();

      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _readDate(Map<String, dynamic> data) {
    final value = data['date'] ?? data['datum'];
    DateTime? parsed;

    if (value is Timestamp) {
      parsed = value.toDate();
    } else if (value is DateTime) {
      parsed = value;
    } else if (value != null) {
      parsed = DateTime.tryParse(value.toString());
    }

    if (parsed == null) return null;

    final time = _readString(data, const ['kickoffTime', 'tijd']);
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return parsed;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return parsed;

    return DateTime(parsed.year, parsed.month, parsed.day, hour, minute);
  }

  bool _matchesDivision(Map<String, dynamic> data) {
    return DivisionDataService.matchBelongsToDivision(data, 'B');
  }

  List<Wedstrijd> _parseSeasonMatches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int speelronde,
  ) {
    final wedstrijden = <Wedstrijd>[];
    final fsDatums = <String, DateTime>{};
    final werkelijkeUitslagThuis = <String, int?>{};
    final werkelijkeUitslagUit = <String, int?>{};

    for (final doc in docs) {
      if (doc.id == '_meta') continue;

      final data = doc.data();
      if (!_matchesDivision(data)) continue;

      final round = _readInt(data, const ['round', 'speelronde']);
      if (round == null) continue;
      if (round != speelronde) continue;

      final homeTeam = _readString(data, const [
        'homeTeam',
        'thuisTeam',
        'thuisteam',
      ]);
      final awayTeam = _readString(data, const [
        'awayTeam',
        'uitTeam',
        'uitteam',
      ]);
      final date = _readDate(data);

      if (homeTeam.isEmpty || awayTeam.isEmpty || date == null) continue;

      final matchId =
          _readString(data, const ['matchId', 'wedstrijdId']).isNotEmpty
              ? _readString(data, const ['matchId', 'wedstrijdId'])
              : doc.id;

      fsDatums[matchId] = date;
      werkelijkeUitslagThuis[matchId] = _readInt(data, const [
        'homeScore',
        'thuisScore',
        'uitslagThuis',
      ]);
      werkelijkeUitslagUit[matchId] = _readInt(data, const [
        'awayScore',
        'uitScore',
        'uitslagUit',
      ]);

      wedstrijden.add(
        Wedstrijd(
          id: matchId,
          speelronde: round,
          datum: date,
          thuis: homeTeam,
          uit: awayTeam,
        ),
      );
    }

    wedstrijden.sort((a, b) {
      final roundCompare = a.speelronde.compareTo(b.speelronde);
      if (roundCompare != 0) return roundCompare;
      return a.datum.compareTo(b.datum);
    });

    if (wedstrijden.isNotEmpty) {
      _fsDatums
        ..clear()
        ..addAll(fsDatums);
      _werkelijkeUitslagThuis
        ..clear()
        ..addAll(werkelijkeUitslagThuis);
      _werkelijkeUitslagUit
        ..clear()
        ..addAll(werkelijkeUitslagUit);
    }

    return wedstrijden;
  }

  void _listenSeasonMatchesFirestore(int speelronde) {
    _seasonMatchesSub?.cancel();

    _seasonMatchesSub = SeasonPaths.currentSeasonMatches.snapshots().listen(
      (snapshot) {
        final seasonMatches = _parseSeasonMatches(snapshot.docs, speelronde);
        final hasSeasonMatches = seasonMatches.isNotEmpty;

        _usingSeasonMatches = hasSeasonMatches;

        if (!hasSeasonMatches) {
          _laadWedstrijdenBasisVoorSpeelronde(speelronde);
          if (mounted) setState(() {});
          return;
        }

        _wedstrijden = seasonMatches;

        final earliest = seasonMatches
            .map((w) => w.datum)
            .reduce((a, b) => a.isBefore(b) ? a : b);

        _deadline = DateTime(earliest.year, earliest.month, earliest.day, 12);

        if (mounted) setState(() {});
      },
    );
  }

  void _listenMatchesFirestore(int speelronde) {
    _matchesSub?.cancel();

    _matchesSub = FirebaseFirestore.instance
        .collection('matches')
        .where('competitie', isEqualTo: 'Derde Divisie B')
        .where('speelronde', isEqualTo: speelronde)
        .snapshots()
        .listen((snapshot) {
      if (_usingSeasonMatches) return;

      DateTime? earliest;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ts = data['datum'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          _fsDatums[doc.id] = dt;
          if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        }
        _werkelijkeUitslagThuis[doc.id] = data['uitslagThuis'];
        _werkelijkeUitslagUit[doc.id] = data['uitslagUit'];
      }

      _deadline = (earliest != null)
          ? DateTime(earliest.year, earliest.month, earliest.day, 12)
          : null;

      setState(() {});
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

    await SyncService.instance.onGeneralPredictionChangedCompetition(
      userId: user.uid,
      competition: 'ddb',
      round: wedstrijd.speelronde,
      matchId: wedstrijd.id,
      generalPrediction: {'scoreThuis': thuis, 'scoreUit': uit},
    );

    await SyncService.instance.onGeneralPredictionChangedOneTeam(
      userId: user.uid,
      matchId: wedstrijd.id,
      generalPrediction: {'scoreThuis': thuis, 'scoreUit': uit},
    );
    await ActivityLogService().log(
      eventType: ActivityEventType.predictionSaved,
      entityType: 'match',
      entityId: wedstrijd.id,
      metadata: {
        'division': widget.divisie,
        'round': wedstrijd.speelronde,
      },
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deadlineTekst = (_deadline != null)
        ? DateFormat('EEEE d-MM-yyyy – HH:mm', 'nl').format(_deadline!)
        : 'n.v.t.';
    final visibleMatches = _favoriteOnly && _favoriteTeamId != null
        ? _wedstrijden.where((match) {
            final home = SeasonConfig.teamByName(match.thuis)?.id;
            final away = SeasonConfig.teamByName(match.uit)?.id;
            return home == _favoriteTeamId || away == _favoriteTeamId;
          }).toList()
        : _wedstrijden;

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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
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
              if (_favoriteTeamId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilterChip(
                    selected: _favoriteOnly,
                    label: const Text('Alleen mijn favoriete club'),
                    avatar: const Icon(Icons.favorite_outline, size: 17),
                    onSelected: (value) =>
                        setState(() => _favoriteOnly = value),
                  ),
                ),
              Expanded(
                child: visibleMatches.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Het programma voor deze divisie is nog niet bekend.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: visibleMatches.length,
                        itemBuilder: (context, index) {
                          final w = visibleMatches[index];
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildTeamWithLogo(w.thuis,
                                        alignRight: false),
                                    _buildVerticalPickerBox(
                                      huidigeWaarde: voorspellingThuis,
                                      disabled: isLocked,
                                      onSelected: (v) {
                                        setState(() {
                                          _voorspellingThuis[id] = v;
                                        });
                                        if (!isLocked) {
                                          _opslaanVoorspelling(
                                              w, v, voorspellingUit);
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
                                          _opslaanVoorspelling(
                                              w, voorspellingThuis, v);
                                        }
                                      },
                                    ),
                                    _buildTeamWithLogo(w.uit, alignRight: true),
                                  ],
                                ),
                                if (!isLocked) ...[
                                  Align(
                                    alignment: Alignment.center,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _expandedQuickPickId =
                                              _expandedQuickPickId == id
                                                  ? null
                                                  : id;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.bolt_outlined,
                                        size: 17,
                                      ),
                                      label: const Text('Snelle uitslag'),
                                    ),
                                  ),
                                  if (_expandedQuickPickId == id)
                                    _buildQuickScores(w),
                                ],
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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
    Future<void> selectRound(int round) async {
      setState(() {
        _huidigeSpeelronde = round;
        _laadWedstrijdenBasisVoorSpeelronde(round);
        _listenSeasonMatchesFirestore(round);
        _listenMatchesFirestore(round);
      });
      await _laadVoorspellingen();
      if (mounted) setState(() {});
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Vorige speelronde',
          onPressed: _huidigeSpeelronde > 1
              ? () => selectRound(_huidigeSpeelronde - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        DropdownButton<int>(
          value: _huidigeSpeelronde,
          items: List.generate(
            34,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('Speelronde ${index + 1}'),
            ),
          ),
          onChanged: (round) {
            if (round != null) selectRound(round);
          },
        ),
        IconButton(
          tooltip: 'Volgende speelronde',
          onPressed: _huidigeSpeelronde < 34
              ? () => selectRound(_huidigeSpeelronde + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildQuickScores(Wedstrijd wedstrijd) {
    const scores = [
      [1, 0],
      [2, 0],
      [2, 1],
      [1, 1],
      [0, 0],
      [0, 1],
      [0, 2],
      [1, 2],
      [1, 3],
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: scores.map((score) {
        final selected = _voorspellingThuis[wedstrijd.id] == score[0] &&
            _voorspellingUit[wedstrijd.id] == score[1];
        return ChoiceChip(
          label: Text('${score[0]}-${score[1]}'),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _voorspellingThuis[wedstrijd.id] = score[0];
              _voorspellingUit[wedstrijd.id] = score[1];
            });
            _opslaanVoorspelling(wedstrijd, score[0], score[1]);
          },
        );
      }).toList(),
    );
  }

  /// 🔢 Verticale popup picker met directe update
  Widget _buildVerticalPickerBox(
      {required int? huidigeWaarde,
      required bool disabled,
      required Function(int?) onSelected}) {
    return PopupMenuButton<int?>(
      enabled: !disabled,
      onSelected: (v) => onSelected(v),
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
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
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
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 17.0),
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
