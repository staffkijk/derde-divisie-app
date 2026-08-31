// lib/features/moderator/moderator_menu_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:derde_divisie/data/config/team_logo_assets.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/result_processing_service.dart';

typedef ModeratorMatchesStreamFactory = Stream<List<ModeratorMatchData>>
    Function(
  String division,
  int round,
);

typedef ModeratorResultWriter = Future<void> Function({
  required String matchId,
  required String division,
  required int round,
  required int homeScore,
  required int awayScore,
});

class ModeratorMenuScreen extends StatefulWidget {
  const ModeratorMenuScreen({
    super.key,
    this.matchesStreamFactory,
    this.resultWriter,
  });

  final ModeratorMatchesStreamFactory? matchesStreamFactory;
  final ModeratorResultWriter? resultWriter;

  @override
  State<ModeratorMenuScreen> createState() => _ModeratorMenuScreenState();
}

class _ModeratorMenuScreenState extends State<ModeratorMenuScreen> {
  static const _darkGreen = Color(0xFF153B2A);
  static const _cream = Color(0xFFF3F6F1);

  String _division = 'A';
  int _round = 1;
  bool _savingAll = false;
  final _processor = const ResultProcessingService();

  final Map<String, TextEditingController> _homeControllers = {};
  final Map<String, TextEditingController> _awayControllers = {};
  late Stream<List<ModeratorMatchData>> _matchesStream;

  @override
  void initState() {
    super.initState();
    _matchesStream = _createMatchesStream();
  }

  Query<Map<String, dynamic>> _matchesQuery() {
    return SeasonPaths.currentSeasonMatches
        .where('division', isEqualTo: _division)
        .where('round', isEqualTo: _round);
  }

  Stream<List<ModeratorMatchData>> _createMatchesStream() {
    final factory = widget.matchesStreamFactory;
    if (factory != null) return factory(_division, _round);
    return _matchesQuery().snapshots().map(
          (snapshot) =>
              snapshot.docs.map(ModeratorMatchData.fromSnapshot).toList(),
        );
  }

  @override
  void dispose() {
    for (final controller in _homeControllers.values) {
      controller.dispose();
    }

    for (final controller in _awayControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _clearControllers() {
    for (final controller in _homeControllers.values) {
      controller.dispose();
    }

    for (final controller in _awayControllers.values) {
      controller.dispose();
    }

    _homeControllers.clear();
    _awayControllers.clear();
  }

  TextEditingController _homeControllerFor(ModeratorMatchData match) {
    return _homeControllers.putIfAbsent(
      match.id,
      () => TextEditingController(
        text: match.homeScore?.toString() ?? '',
      ),
    );
  }

  TextEditingController _awayControllerFor(ModeratorMatchData match) {
    return _awayControllers.putIfAbsent(
      match.id,
      () => TextEditingController(
        text: match.awayScore?.toString() ?? '',
      ),
    );
  }

  Future<void> _saveMatch(ModeratorMatchData match) async {
    final homeController = _homeControllerFor(match);
    final awayController = _awayControllerFor(match);

    final homeText = homeController.text.trim();
    final awayText = awayController.text.trim();

    if (homeText.isEmpty || awayText.isEmpty) {
      _showSnack(
          'Vul voor ${match.homeTeam} tegen ${match.awayTeam} beide scores in.');
      return;
    }

    final homeScore = int.tryParse(homeText);
    final awayScore = int.tryParse(awayText);

    if (homeScore == null || awayScore == null) {
      _showSnack('Gebruik alleen hele getallen als uitslag.');
      return;
    }

    await _writeResult(
      match: match,
      homeScore: homeScore,
      awayScore: awayScore,
    );

    if (!mounted) return;

    _showSnack('${match.homeTeam} tegen ${match.awayTeam} opgeslagen.');
  }

  Future<void> _saveAll(List<ModeratorMatchData> matches) async {
    if (_savingAll) return;

    final updates = <_PendingResult>[];

    for (final match in matches) {
      final homeText = _homeControllerFor(match).text.trim();
      final awayText = _awayControllerFor(match).text.trim();

      if (homeText.isEmpty && awayText.isEmpty) continue;

      if (homeText.isEmpty || awayText.isEmpty) {
        _showSnack(
            'Niet opgeslagen: ${match.homeTeam} tegen ${match.awayTeam} is onvolledig.');
        return;
      }

      final homeScore = int.tryParse(homeText);
      final awayScore = int.tryParse(awayText);

      if (homeScore == null || awayScore == null) {
        _showSnack('Niet opgeslagen: gebruik alleen hele getallen.');
        return;
      }

      updates.add(
        _PendingResult(
          match: match,
          homeScore: homeScore,
          awayScore: awayScore,
        ),
      );
    }

    if (updates.isEmpty) {
      _showSnack('Er zijn geen uitslagen ingevuld.');
      return;
    }

    setState(() => _savingAll = true);

    try {
      for (final update in updates) {
        await _writeResult(
          match: update.match,
          homeScore: update.homeScore,
          awayScore: update.awayScore,
        );
      }

      if (!mounted) return;

      _showSnack('${updates.length} uitslagen opgeslagen.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Opslaan mislukt: $e');
    } finally {
      if (mounted) {
        setState(() => _savingAll = false);
      }
    }
  }

  Future<void> _writeResult({
    required ModeratorMatchData match,
    required int homeScore,
    required int awayScore,
  }) async {
    final writer = widget.resultWriter;
    if (writer != null) {
      await writer(
        matchId: match.id,
        division: match.division,
        round: match.round,
        homeScore: homeScore,
        awayScore: awayScore,
      );
      return;
    }
    await _processor.saveFinishedResult(
      matchRef: match.reference!,
      homeScore: homeScore,
      awayScore: awayScore,
      division: match.division,
      round: match.round,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      homeTeamSlug: match.homeTeamSlug,
      awayTeamSlug: match.awayTeamSlug,
    );
  }

  Future<void> _setStatus(ModeratorMatchData match, String status) async {
    try {
      await _processor.clearResultAndSetStatus(
        matchRef: match.reference!,
        status: status,
      );
      _homeControllerFor(match).clear();
      _awayControllerFor(match).clear();
      if (mounted) {
        _showSnack(
          status == 'postponed'
              ? 'Wedstrijd gemarkeerd als In te halen.'
              : status == 'cancelled'
                  ? 'Wedstrijd afgelast.'
                  : 'Wedstrijd gestaakt.',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Status opslaan mislukt: $e');
    }
  }

  void _setQuickScore(ModeratorMatchData match, int home, int away) {
    _homeControllerFor(match).text = '$home';
    _awayControllerFor(match).text = '$away';
  }

  Future<void> _clearResult(ModeratorMatchData match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Uitslag verwijderen?'),
          content: Text(
            'De uitslag van ${match.homeTeam} tegen ${match.awayTeam} wordt verwijderd en de wedstrijd gaat terug naar Gepland.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _processor.clearResultAndSetStatus(
        matchRef: match.reference!,
        status: 'scheduled',
      );

      _homeControllers[match.id]?.text = '';
      _awayControllers[match.id]?.text = '';

      if (!mounted) return;
      _showSnack('Uitslag verwijderd.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Verwijderen mislukt: $e');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text('Uitslagen invoeren'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 24 : 8),
                  child: Column(
                    children: [
                      _HeaderCard(
                        division: _division,
                        round: _round,
                        onDivisionChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _division = value;
                            _clearControllers();
                            _matchesStream = _createMatchesStream();
                          });
                        },
                        onRoundChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _round = value;
                            _clearControllers();
                            _matchesStream = _createMatchesStream();
                          });
                        },
                      ),
                      SizedBox(height: isDesktop ? 16 : 8),
                      Expanded(
                        child: StreamBuilder<List<ModeratorMatchData>>(
                          stream: _matchesStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return _StateCard(
                                icon: Icons.error_outline,
                                title: 'Wedstrijden konden niet worden geladen',
                                text:
                                    'Controleer de Firestore index voor division, round en roundMatchIndex.',
                                color: Colors.red.shade700,
                              );
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final matches = snapshot.data ?? [];

                            if (matches.isEmpty) {
                              return const _StateCard(
                                icon: Icons.scoreboard_outlined,
                                title: 'Geen wedstrijden gevonden',
                                text:
                                    'Voor deze divisie en speelronde staan geen wedstrijden in Firestore.',
                                color: _darkGreen,
                              );
                            }

                            matches.sort(ModeratorMatchData.compareForInput);

                            return Column(
                              children: [
                                _BulkBar(
                                  matchesCount: matches.length,
                                  saving: _savingAll,
                                  onSaveAll: () => _saveAll(matches),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: matches.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final match = matches[index];

                                      return _ResultRow(
                                        key: ValueKey('result-${match.id}'),
                                        match: match,
                                        compact: !isDesktop,
                                        homeController:
                                            _homeControllerFor(match),
                                        awayController:
                                            _awayControllerFor(match),
                                        onSave: () => _saveMatch(match),
                                        onClear: () => _clearResult(match),
                                        onQuickScore: (home, away) =>
                                            _setQuickScore(match, home, away),
                                        onStatus: (status) =>
                                            _setStatus(match, status),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.division,
    required this.round,
    required this.onDivisionChanged,
    required this.onRoundChanged,
  });

  final String division;
  final int round;
  final ValueChanged<String?> onDivisionChanged;
  final ValueChanged<int?> onRoundChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final divisionSelect = _SelectBox<String>(
      key: const ValueKey('moderator-division-select'),
      value: division,
      items: const [
        DropdownMenuItem(value: 'A', child: Text('Divisie A')),
        DropdownMenuItem(value: 'B', child: Text('Divisie B')),
      ],
      onChanged: onDivisionChanged,
      expanded: compact,
    );
    final roundSelect = _SelectBox<int>(
      key: const ValueKey('moderator-round-select'),
      value: round,
      items: List.generate(
        34,
        (index) => DropdownMenuItem(
          value: index + 1,
          child: Text('Speelronde ${index + 1}'),
        ),
      ),
      onChanged: onRoundChanged,
      expanded: compact,
    );
    final controls = compact
        ? Row(
            children: [
              Expanded(child: divisionSelect),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: roundSelect),
            ],
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [divisionSelect, roundSelect],
          );

    return Container(
      key: const ValueKey('moderator-results-controls'),
      padding: EdgeInsets.all(compact ? 8 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
        border: Border.all(color: const Color(0xFFE3EADF)),
        boxShadow: compact
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: compact
          ? controls
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uitslagen invoeren',
                        style: TextStyle(
                          color: Color(0xFF153B2A),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vul uitslagen in per divisie en speelronde. Opslaan zet de wedstrijd op Afgelopen.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                controls,
              ],
            ),
    );
  }
}

class _SelectBox<T> extends StatelessWidget {
  const _SelectBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.expanded = false,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EADF)),
        ),
        child: DropdownButton<T>(
          isExpanded: expanded,
          value: value,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.matchesCount,
    required this.saving,
    required this.onSaveAll,
  });

  final int matchesCount;
  final bool saving;
  final VoidCallback onSaveAll;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16, vertical: compact ? 6 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined,
              color: Color(0xFF2F8F3B), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              compact
                  ? '$matchesCount wedstrijden'
                  : '$matchesCount wedstrijden gevonden',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF153B2A), fontWeight: FontWeight.w800),
            ),
          ),
          if (compact)
            IconButton(
              key: const ValueKey('save-all-results'),
              tooltip: 'Alles opslaan',
              onPressed: saving ? null : onSaveAll,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
            )
          else
            ElevatedButton.icon(
              key: const ValueKey('save-all-results'),
              onPressed: saving ? null : onSaveAll,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Opslaan' : 'Alles opslaan'),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.match,
    required this.compact,
    required this.homeController,
    required this.awayController,
    required this.onSave,
    required this.onClear,
    required this.onQuickScore,
    required this.onStatus,
  });

  final ModeratorMatchData match;
  final bool compact;
  final TextEditingController homeController;
  final TextEditingController awayController;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final void Function(int home, int away) onQuickScore;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final hasScore = match.homeScore != null && match.awayScore != null;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: compact ? _buildCompact(hasScore) : _buildWide(hasScore),
    );
  }

  Widget _buildWide(bool hasScore) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _TeamBlock(
            name: match.homeTeam,
            slug: match.homeTeamSlug,
            alignEnd: false,
          ),
        ),
        const SizedBox(width: 12),
        _ScoreInput(
          key: ValueKey('home-score-${match.id}'),
          controller: homeController,
        ),
        const SizedBox(width: 8),
        const Text(
          '-',
          style: TextStyle(
            color: Color(0xFF153B2A),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        _ScoreInput(
          key: ValueKey('away-score-${match.id}'),
          controller: awayController,
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: _TeamBlock(
            name: match.awayTeam,
            slug: match.awayTeamSlug,
            alignEnd: true,
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          tooltip: 'Snelle uitslag',
          icon: const Icon(Icons.bolt_rounded, color: Color(0xFF2F8F3B)),
          onSelected: (value) {
            final scores = value.split('-').map(int.parse).toList();
            onQuickScore(scores[0], scores[1]);
          },
          itemBuilder: (_) =>
              const ['1-0', '2-0', '2-1', '1-1', '0-1', '0-2', '1-2']
                  .map(
                    (score) => PopupMenuItem(value: score, child: Text(score)),
                  )
                  .toList(),
        ),
        _StatusPill(status: match.status),
        PopupMenuButton<String>(
          tooltip: 'Status zonder uitslag',
          onSelected: onStatus,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'postponed', child: Text('In te halen')),
            PopupMenuItem(value: 'cancelled', child: Text('Afgelast')),
            PopupMenuItem(value: 'abandoned', child: Text('Gestaakt')),
          ],
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Opslaan',
          onPressed: onSave,
          icon: const Icon(
            Icons.save_outlined,
            color: Color(0xFF153B2A),
          ),
        ),
        IconButton(
          tooltip: 'Uitslag verwijderen',
          onPressed: hasScore ? onClear : null,
          icon: Icon(
            Icons.delete_outline,
            color: hasScore ? Colors.red.shade700 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(bool hasScore) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TeamBlock(
                name: match.homeTeam,
                slug: match.homeTeamSlug,
                alignEnd: false,
              ),
            ),
            const SizedBox(width: 10),
            _ScoreInput(
              key: ValueKey('home-score-${match.id}'),
              controller: homeController,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TeamBlock(
                name: match.awayTeam,
                slug: match.awayTeamSlug,
                alignEnd: false,
              ),
            ),
            const SizedBox(width: 10),
            _ScoreInput(
              key: ValueKey('away-score-${match.id}'),
              controller: awayController,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatusPill(status: match.status),
            PopupMenuButton<String>(
              tooltip: 'Status',
              onSelected: onStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'postponed', child: Text('In te halen')),
                PopupMenuItem(value: 'cancelled', child: Text('Afgelast')),
                PopupMenuItem(value: 'abandoned', child: Text('Gestaakt')),
              ],
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Uitslag wissen',
              onPressed: hasScore ? onClear : null,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton.filled(
              tooltip: 'Opslaan',
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 44,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(
          signed: false,
          decimal: false,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAF6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        style: const TextStyle(
          color: Color(0xFF153B2A),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.name,
    required this.slug,
    required this.alignEnd,
  });

  final String name;
  final String slug;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final logo = teamLogoAssetFromValues([slug, name]) ?? kDefaultTeamLogoAsset;

    final children = [
      SizedBox(
        width: 32,
        height: 32,
        child: Image.asset(
          logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.shield_outlined,
            color: Color(0xFF2F8F3B),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          name.isEmpty ? slug : name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF153B2A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ];

    return Row(
      textDirection: alignEnd ? TextDirection.rtl : TextDirection.ltr,
      children: children,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    final color = _statusColor(status);
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'finished':
        return '';
      case 'postponed':
        return 'Uitgesteld';
      case 'cancelled':
        return 'Afgelast';
      case 'abandoned':
        return 'Gestaakt';
      case 'scheduled':
      default:
        return '';
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'finished':
        return const Color(0xFF2F8F3B);
      case 'postponed':
        return Colors.blueGrey.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'abandoned':
        return Colors.red.shade700;
      case 'scheduled':
      default:
        return const Color(0xFF153B2A);
    }
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE3EADF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667067),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingResult {
  const _PendingResult({
    required this.match,
    required this.homeScore,
    required this.awayScore,
  });

  final ModeratorMatchData match;
  final int homeScore;
  final int awayScore;
}

class ModeratorMatchData {
  const ModeratorMatchData({
    this.reference,
    required this.id,
    required this.division,
    required this.round,
    required this.roundMatchIndex,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamSlug,
    required this.awayTeamSlug,
    required this.status,
    required this.homeScore,
    required this.awayScore,
  });

  final DocumentReference<Map<String, dynamic>>? reference;
  final String id;
  final String division;
  final int round;
  final int roundMatchIndex;
  final String homeTeam;
  final String awayTeam;
  final String homeTeamSlug;
  final String awayTeamSlug;
  final String status;
  final int? homeScore;
  final int? awayScore;

  factory ModeratorMatchData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ModeratorMatchData(
      reference: doc.reference,
      id: doc.id,
      division: _string(data['division'], ''),
      round: _int(data['round'], 0),
      roundMatchIndex: _int(data['roundMatchIndex'], 0),
      homeTeam: _string(
        data['homeTeamName'] ??
            data['homeTeam'] ??
            data['thuisteam'] ??
            data['home'],
        '',
      ),
      awayTeam: _string(
        data['awayTeamName'] ??
            data['awayTeam'] ??
            data['uitteam'] ??
            data['away'],
        '',
      ),
      homeTeamSlug: _string(
        data['homeTeamSlug'] ?? data['homeSlug'] ?? data['homeTeamCode'],
        '',
      ),
      awayTeamSlug: _string(
        data['awayTeamSlug'] ?? data['awaySlug'] ?? data['awayTeamCode'],
        '',
      ),
      status: _string(data['status'], 'scheduled'),
      homeScore: _nullableInt(
        data['homeScore'] ?? data['uitslagThuis'],
      ),
      awayScore: _nullableInt(
        data['awayScore'] ?? data['uitslagUit'],
      ),
    );
  }

  static int compareForInput(ModeratorMatchData a, ModeratorMatchData b) {
    final indexResult = a.roundMatchIndex.compareTo(b.roundMatchIndex);
    if (indexResult != 0) return indexResult;
    return a.homeTeam.compareTo(b.homeTeam);
  }

  static String _string(dynamic value, String fallback) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
