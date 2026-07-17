import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import '../../data/models/wedstrijd.dart';
import '../../data/services/wedstrijden_data.dart';
import 'package:derde_divisie/helpers/sync_service.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/data/services/analytics_service.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';
import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/features/voorspellen/prediction_round_resolver.dart';
import 'package:derde_divisie/features/voorspellen/widgets/prediction_score_picker.dart';

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
  final Set<String> _savingPredictionIds = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _seasonMatchesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _matchesSub;
  bool _usingSeasonMatches = false;
  String? _favoriteTeamId;
  bool _favoriteOnly = false;

  List<int> get _availableRounds {
    final rounds = getWedstrijden(widget.divisie)
        .map((wedstrijd) => wedstrijd.speelronde)
        .where((round) => round > 0)
        .toSet()
        .toList()
      ..sort();
    return rounds.isEmpty ? [_huidigeSpeelronde] : rounds;
  }

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
    _listenSeasonMatchesFirestore(_huidigeSpeelronde);
    _listenMatchesFirestore(_huidigeSpeelronde);
    await _laadVoorspellingen();
    setState(() {});
  }

  void _bepaalHuidigeSpeelrondeOpDatum() {
    final alleWedstrijden = getWedstrijden(widget.divisie);
    _huidigeSpeelronde = PredictionRoundResolver.resolve(
          matches: PredictionRoundResolver.fromWedstrijden(
            alleWedstrijden,
            'A',
          ),
          division: 'A',
          now: DateTime.now(),
        ) ??
        1;
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
    return DivisionDataService.matchBelongsToDivision(data, 'A');
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
      (snapshot) async {
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

        final overrideUntil = await _getRoundOverrideUntil(
          competitionCode: _competitionCode(),
          speelronde: speelronde,
        );

        _deadline = overrideUntil ??
            DateTime(earliest.year, earliest.month, earliest.day, 12);

        if (mounted) setState(() {});
      },
    );
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
      if (_usingSeasonMatches) return;

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
    if (_savingPredictionIds.contains(wedstrijd.id)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _savingPredictionIds.add(wedstrijd.id);

    try {
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
      await ActivityLogService().log(
        eventType: ActivityEventType.predictionSaved,
        entityType: 'match',
        entityId: wedstrijd.id,
        metadata: {
          'division': widget.divisie,
          'round': wedstrijd.speelronde,
        },
      );
      await AnalyticsService.instance.trackPredictionSaved(
        division: 'A',
        round: wedstrijd.speelronde,
        matchId: wedstrijd.id,
        source: 'division_predictions',
      );
    } finally {
      _savingPredictionIds.remove(wedstrijd.id);
      if (mounted) setState(() {});
    }
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
    final predictedCount = visibleMatches
        .where((match) =>
            _voorspellingThuis[match.id] != null &&
            _voorspellingUit[match.id] != null)
        .length;
    final missingCount = visibleMatches.length - predictedCount;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactControls(
                predictedCount: predictedCount,
                totalCount: visibleMatches.length,
                missingCount: missingCount,
                deadlineText: deadlineTekst,
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
                              horizontal: 4,
                              vertical: 4,
                            ),
                            padding: EdgeInsets.all(isMobile ? 8 : 10),
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
                                    PredictionScorePicker(
                                      homeScore: voorspellingThuis,
                                      awayScore: voorspellingUit,
                                      locked: isLocked,
                                      semanticLabel:
                                          'Voorspelling ${w.thuis} tegen ${w.uit}',
                                      onScoreSelected: (score) {
                                        setState(() {
                                          _voorspellingThuis[id] = score.home;
                                          _voorspellingUit[id] = score.away;
                                        });
                                        _opslaanVoorspelling(
                                          w,
                                          score.home,
                                          score.away,
                                        );
                                      },
                                    ),
                                    _buildTeamWithLogo(w.uit, alignRight: true),
                                  ],
                                ),
                                const SizedBox(height: 5),
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
      await ActivityLogService().log(
        eventType: ActivityEventType.roundSelected,
        metadata: {
          'division': widget.divisie,
          'round': round,
        },
      );
      if (mounted) setState(() {});
    }

    final rounds = _availableRounds;
    final selectedRound =
        rounds.contains(_huidigeSpeelronde) ? _huidigeSpeelronde : rounds.first;
    final selectedIndex = rounds.indexOf(selectedRound);

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Vorige speelronde',
          onPressed: selectedIndex > 0
              ? () => selectRound(rounds[selectedIndex - 1])
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        DropdownButton<int>(
          value: selectedRound,
          items: [
            for (final round in rounds)
              DropdownMenuItem(
                value: round,
                child: Text(isMobile ? 'Ronde $round' : 'Speelronde $round'),
              ),
          ],
          onChanged: (round) {
            if (round != null) selectRound(round);
          },
        ),
        IconButton(
          tooltip: 'Volgende speelronde',
          onPressed: selectedIndex < rounds.length - 1
              ? () => selectRound(rounds[selectedIndex + 1])
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCompactControls({
    required int predictedCount,
    required int totalCount,
    required int missingCount,
    required String deadlineText,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, isMobile ? 4 : 8, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 6 : 8,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRondeSelector(),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  '$predictedCount van $totalCount voorspeld'
                  '${missingCount > 0 ? ' - $missingCount ontbreekt' : ''}',
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.schedule_outlined, size: 16),
                label: Text('Deadline: $deadlineText'),
              ),
              if (_favoriteTeamId != null)
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  selected: _favoriteOnly,
                  label: const Text('Favoriete club'),
                  avatar: const Icon(Icons.favorite_outline, size: 17),
                  onSelected: (value) => setState(() => _favoriteOnly = value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamWithLogo(String team, {required bool alignRight}) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Expanded(
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!alignRight)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TeamLogo(teamName: team, size: isMobile ? 30 : 38),
            ),
          Flexible(
            child: Text(
              team,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 13.5 : 17.0,
              ),
            ),
          ),
          if (alignRight)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TeamLogo(teamName: team, size: isMobile ? 30 : 38),
            ),
        ],
      ),
    );
  }
}
