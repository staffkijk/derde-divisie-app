import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/config/team_logo_assets.dart';
import '../../data/config/season_config.dart';
import '../../data/firestore/season_paths.dart';
import '../../data/services/division_data_service.dart';
import '../../core/utils/match_formatters.dart';
import '../../core/widgets/team_logo.dart';
import '../moderator/result_processing_service.dart';
import '../clubs/club_detail_screen.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({
    super.key,
    required this.division,
    this.season = SeasonConfig.activeSeasonId,
    this.showAllMatches = false,
  });

  final String division;
  final String season;
  final bool showAllMatches;

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  static const _darkGreen = Color(0xFF153B2A);
  static const _cream = Color(0xFFF3F6F1);

  int _selectedRound = 1;
  bool _isModerator = false;
  late final List<int> _rounds;

  @override
  void initState() {
    super.initState();
    _rounds = List<int>.generate(34, (index) => index + 1);
    _loadModeratorStatus();
    _selectRelevantRound();
  }

  Future<void> _selectRelevantRound() async {
    try {
      final snapshot = await SeasonPaths.matches(widget.season)
          .where('division', isEqualTo: widget.division)
          .get();
      final openRounds = snapshot.docs
          .where((doc) {
            final status = (doc.data()['status'] ?? 'scheduled').toString();
            return status == 'scheduled' || status == 'postponed';
          })
          .map((doc) => _MatchDoc._int(doc.data()['round'], 0))
          .where((round) => round > 0)
          .toList()
        ..sort();
      final allRounds = snapshot.docs
          .map((doc) => _MatchDoc._int(doc.data()['round'], 0))
          .where((round) => round > 0)
          .toList()
        ..sort();
      final relevant = openRounds.isNotEmpty
          ? openRounds.first
          : allRounds.isNotEmpty
              ? allRounds.last
              : 1;
      if (mounted) setState(() => _selectedRound = relevant);
    } catch (error) {
      debugPrint('Eerstvolgende speelronde kon niet worden bepaald: $error');
    }
  }

  Future<void> _loadModeratorStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) setState(() => _isModerator = false);
      return;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = userDoc.data();
      final isModerator =
          data?['ismoderator'] == true || data?['isModerator'] == true;

      if (mounted) setState(() => _isModerator = isModerator);
    } catch (e) {
      debugPrint('Fout bij laden moderatorstatus programma: $e');
      if (mounted) setState(() => _isModerator = false);
    }
  }

  Query<Map<String, dynamic>> _matchesQuery() {
    final divisionQuery = SeasonPaths.matches(widget.season)
        .where('division', isEqualTo: widget.division);
    if (widget.showAllMatches) return divisionQuery;
    return divisionQuery.where('round', isEqualTo: _selectedRound);
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Programma Derde Divisie ${widget.division}';

    return Container(
      color: _cream,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              _HeaderCard(
                title: title,
                selectedRound: _selectedRound,
                rounds: _rounds,
                showRoundSelector: !widget.showAllMatches,
                onRoundChanged: (round) {
                  if (round == null) return;
                  setState(() => _selectedRound = round);
                },
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _matchesQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _StateCard(
                        icon: Icons.error_outline,
                        title: 'Programma kon niet worden geladen',
                        text:
                            'Controleer de Firestore index voor division, round en roundMatchIndex.',
                        color: Colors.red.shade700,
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = (snapshot.data?.docs ?? [])
                        .where(
                          (doc) => DivisionDataService.matchBelongsToDivision(
                            doc.data(),
                            widget.division,
                          ),
                        )
                        .toList();

                    if (docs.isEmpty) {
                      return const _StateCard(
                        icon: Icons.calendar_month_outlined,
                        title: 'Nog geen wedstrijden gevonden',
                        text:
                            'Voor deze divisie en speelronde staan nog geen wedstrijden in Firestore.',
                        color: _darkGreen,
                      );
                    }

                    final matches = docs
                        .map((doc) => _MatchDoc.fromSnapshot(doc))
                        .toList()
                      ..sort(_MatchDoc.compareForPublicDisplay);

                    return _MatchesList(
                      matches: matches,
                      isModerator: _isModerator,
                      onEdit: _openEditDialog,
                      showRoundHeaders: widget.showAllMatches,
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

  Future<void> _openEditDialog(_MatchDoc match) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditMatchDialog(match: match),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wedstrijd is bijgewerkt.')),
      );
    }
  }
}

class _HeaderCard extends StatelessWidget {
  static const _border = Color(0xFFE3EADF);

  const _HeaderCard({
    required this.title,
    required this.selectedRound,
    required this.rounds,
    required this.onRoundChanged,
    required this.showRoundSelector,
  });

  final String title;
  final int selectedRound;
  final List<int> rounds;
  final ValueChanged<int?> onRoundChanged;
  final bool showRoundSelector;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TitleBlock(title: title),
                if (showRoundSelector) ...[
                  const SizedBox(height: 14),
                  _RoundSelector(
                    selectedRound: selectedRound,
                    rounds: rounds,
                    onRoundChanged: onRoundChanged,
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(child: _TitleBlock(title: title)),
                if (showRoundSelector) ...[
                  const SizedBox(width: 18),
                  _RoundSelector(
                    selectedRound: selectedRound,
                    rounds: rounds,
                    onRoundChanged: onRoundChanged,
                  ),
                ],
              ],
            ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);
  static const _green = Color(0xFF2F8F3B);
  static const _textMuted = Color(0xFF667067);

  const _TitleBlock({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.calendar_month, color: _green),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Wedstrijden per speelronde met datum, tijd, status en uitslag.',
                style: TextStyle(color: _textMuted, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundSelector extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);
  static const _border = Color(0xFFE3EADF);

  const _RoundSelector({
    required this.selectedRound,
    required this.rounds,
    required this.onRoundChanged,
  });

  final int selectedRound;
  final List<int> rounds;
  final ValueChanged<int?> onRoundChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: DropdownButton<int>(
          value: selectedRound,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: rounds
              .map(
                (round) => DropdownMenuItem<int>(
                  value: round,
                  child: Text(
                    'Speelronde $round',
                    style: const TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onRoundChanged,
        ),
      ),
    );
  }
}

class _MatchesList extends StatelessWidget {
  const _MatchesList({
    required this.matches,
    required this.isModerator,
    required this.onEdit,
    required this.showRoundHeaders,
  });

  final List<_MatchDoc> matches;
  final bool isModerator;
  final ValueChanged<_MatchDoc> onEdit;
  final bool showRoundHeaders;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<_MatchDoc>>{};

    for (final match in matches) {
      final date = match.date.isEmpty ? 'Datum onbekend' : match.date;
      final key = showRoundHeaders
          ? '${match.round.toString().padLeft(2, '0')}|$date'
          : date;
      grouped.putIfAbsent(key, () => []).add(match);
    }

    final dates = grouped.keys.toList();

    return ListView.separated(
      itemCount: dates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final key = dates[index];
        final dayMatches = grouped[key] ?? [];
        final date = showRoundHeaders ? key.split('|').skip(1).join('|') : key;

        return _DateGroupCard(
          date: date,
          round: showRoundHeaders ? dayMatches.first.round : null,
          weekdayNL: dayMatches.first.weekdayNL,
          matches: dayMatches,
          isModerator: isModerator,
          onEdit: onEdit,
        );
      },
    );
  }
}

class _DateGroupCard extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);
  static const _border = Color(0xFFE3EADF);
  static const _textMuted = Color(0xFF667067);

  const _DateGroupCard({
    required this.date,
    this.round,
    required this.weekdayNL,
    required this.matches,
    required this.isModerator,
    required this.onEdit,
  });

  final String date;
  final int? round;
  final String weekdayNL;
  final List<_MatchDoc> matches;
  final bool isModerator;
  final ValueChanged<_MatchDoc> onEdit;

  @override
  Widget build(BuildContext context) {
    final displayDate = _formatDate(date, weekdayNL);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined, color: _darkGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    round == null
                        ? displayDate
                        : 'Speelronde $round · $displayDate',
                    style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${matches.length} wedstrijden',
                  style: const TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...matches.map(
            (match) => _MatchRow(
              match: match,
              isModerator: isModerator,
              onEdit: () => onEdit(match),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String date, String weekdayNL) {
    final parsed = DateTime.tryParse(date);

    if (parsed == null) {
      if (weekdayNL.isEmpty) return date;
      return '$weekdayNL $date';
    }

    return MatchDateTimeFormatter.dayHeader(parsed);
  }
}

class _MatchRow extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);
  static const _border = Color(0xFFE3EADF);

  const _MatchRow({
    required this.match,
    required this.isModerator,
    required this.onEdit,
  });

  final _MatchDoc match;
  final bool isModerator;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 12 : 7,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: compact ? _buildCompact(context) : _buildWide(context),
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _TeamBlock(
            name: match.homeTeam,
            slug: match.homeTeamSlug,
            logoValues: [
              match.homeTeamLogoAsset,
              match.homeTeamLogo,
              match.homeLogoAsset,
              match.homeLogo,
              match.homeTeamSlug,
              match.homeTeam,
            ],
            alignEnd: false,
            onTap: () => _openClub(
              context,
              match.homeTeamSlug,
              match.homeTeam,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _CenterBlock(match: match),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: _TeamBlock(
            name: match.awayTeam,
            slug: match.awayTeamSlug,
            logoValues: [
              match.awayTeamLogoAsset,
              match.awayTeamLogo,
              match.awayLogoAsset,
              match.awayLogo,
              match.awayTeamSlug,
              match.awayTeam,
            ],
            alignEnd: true,
            onTap: () => _openClub(
              context,
              match.awayTeamSlug,
              match.awayTeam,
            ),
          ),
        ),
        const SizedBox(width: 14),
        _StatusBadge(status: match.status),
        if (isModerator) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Wedstrijd bewerken',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: _darkGreen),
          ),
        ],
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TeamBlock(
                name: match.homeTeam,
                slug: match.homeTeamSlug,
                logoValues: [
                  match.homeTeamLogoAsset,
                  match.homeTeamLogo,
                  match.homeLogoAsset,
                  match.homeLogo,
                  match.homeTeamSlug,
                  match.homeTeam,
                ],
                alignEnd: false,
                onTap: () => _openClub(
                  context,
                  match.homeTeamSlug,
                  match.homeTeam,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CenterBlock(match: match),
            const SizedBox(width: 10),
            Expanded(
              child: _TeamBlock(
                name: match.awayTeam,
                slug: match.awayTeamSlug,
                logoValues: [
                  match.awayTeamLogoAsset,
                  match.awayTeamLogo,
                  match.awayLogoAsset,
                  match.awayLogo,
                  match.awayTeamSlug,
                  match.awayTeam,
                ],
                alignEnd: true,
                onTap: () => _openClub(
                  context,
                  match.awayTeamSlug,
                  match.awayTeam,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatusBadge(status: match.status),
            const Spacer(),
            if (isModerator)
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Bewerken'),
              ),
          ],
        ),
      ],
    );
  }

  void _openClub(BuildContext context, String slug, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubDetailScreen(teamSlug: slug, teamName: name),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);

  const _TeamBlock({
    required this.name,
    required this.slug,
    required this.logoValues,
    required this.alignEnd,
    this.onTap,
  });

  final String name;
  final String slug;
  final List<Object?> logoValues;
  final bool alignEnd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final children = [
      _TeamLogo(
        values: logoValues,
        fallbackText: name.isEmpty ? slug : name,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          name.isEmpty ? slug : name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(
            color: _darkGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          textDirection: alignEnd ? TextDirection.rtl : TextDirection.ltr,
          children: children,
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({
    required this.values,
    required this.fallbackText,
  });

  final Iterable<Object?> values;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      teamName: fallbackText,
      assetPath: teamLogoAssetFromValues(values),
      size: 32,
    );
  }
}

class _CenterBlock extends StatelessWidget {
  static const _darkGreen = Color(0xFF153B2A);
  static const _green = Color(0xFF2F8F3B);

  const _CenterBlock({required this.match});

  final _MatchDoc match;

  @override
  Widget build(BuildContext context) {
    final hasScore = match.homeScore != null && match.awayScore != null;
    final showScore = hasScore && match.status == 'finished';

    final centerText = showScore
        ? '${match.homeScore} - ${match.awayScore}'
        : match.kickoffTime.isEmpty
            ? 'Tijd nnb'
            : match.kickoffTime;

    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            showScore ? _green.withValues(alpha: .12) : const Color(0xFFF8FAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showScore
              ? _green.withValues(alpha: .35)
              : const Color(0xFFE3EADF),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        centerText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: showScore ? _green : _darkGreen,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    if (config.label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: config.color.withValues(alpha: .25)),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  static _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'finished':
        return _StatusConfig('', const Color(0xFF2F8F3B));
      case 'postponed':
        return _StatusConfig('Uitgesteld', Colors.blueGrey.shade700);
      case 'cancelled':
        return _StatusConfig('Afgelast', Colors.red.shade700);
      case 'abandoned':
        return _StatusConfig('Gestaakt', Colors.red.shade700);
      case 'scheduled':
      default:
        return _StatusConfig('', const Color(0xFF153B2A));
    }
  }
}

class _StatusConfig {
  const _StatusConfig(this.label, this.color);

  final String label;
  final Color color;
}

class _StateCard extends StatelessWidget {
  static const _border = Color(0xFFE3EADF);
  static const _textMuted = Color(0xFF667067);

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
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 34),
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
              style: const TextStyle(color: _textMuted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMatchDialog extends StatefulWidget {
  const _EditMatchDialog({required this.match});

  final _MatchDoc match;

  @override
  State<_EditMatchDialog> createState() => _EditMatchDialogState();
}

class _EditMatchDialogState extends State<_EditMatchDialog> {
  static const _statuses = [
    'scheduled',
    'finished',
    'postponed',
    'cancelled',
    'abandoned',
  ];

  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;

  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _dateController = TextEditingController(text: widget.match.date);
    _timeController = TextEditingController(text: widget.match.kickoffTime);
    _homeScoreController = TextEditingController(
      text: widget.match.homeScore?.toString() ?? '',
    );
    _awayScoreController = TextEditingController(
      text: widget.match.awayScore?.toString() ?? '',
    );

    _status = _statuses.contains(widget.match.status)
        ? widget.match.status
        : 'scheduled';
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return AlertDialog(
      title: const Text('Wedstrijd bewerken'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${match.homeTeam} tegen ${match.awayTeam}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Datum',
                  helperText: 'Formaat: 2026-08-15',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Tijd',
                  helperText: 'Formaat: 14:30',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  LengthLimitingTextInputFormatter(5),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: _statuses
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(_statusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _homeScoreController,
                      decoration: const InputDecoration(
                        labelText: 'Thuis',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _awayScoreController,
                      decoration: const InputDecoration(
                        labelText: 'Uit',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bij status Afgelopen wordt de uitslag zichtbaar in het programma.',
                  style: TextStyle(color: Color(0xFF667067), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuleren'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Opslaan' : 'Opslaan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();

    if (!_validDate(date)) {
      _showError('Vul een geldige datum in, bijvoorbeeld 2026-08-15.');
      return;
    }

    if (!_validTime(time)) {
      _showError('Vul een geldige tijd in, bijvoorbeeld 14:30.');
      return;
    }

    final homeScore = _parseScore(_homeScoreController.text);
    final awayScore = _parseScore(_awayScoreController.text);

    if (_status == 'finished' && (homeScore == null || awayScore == null)) {
      _showError('Vul bij status Afgelopen beide doelpunten in.');
      return;
    }

    final scheduledAt = _combineDateAndTime(date, time);

    if (scheduledAt == null) {
      _showError('Datum en tijd konden niet worden gecombineerd.');
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.match.ref.set({
        'date': date,
        'kickoffTime': time,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'kickoffTimeConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final processor = const ResultProcessingService();
      if (_status == 'finished') {
        await processor.saveFinishedResult(
          matchRef: widget.match.ref,
          homeScore: homeScore!,
          awayScore: awayScore!,
          division: widget.match.division,
          round: widget.match.round,
          homeTeam: widget.match.homeTeam,
          awayTeam: widget.match.awayTeam,
          homeTeamSlug: widget.match.homeTeamSlug,
          awayTeamSlug: widget.match.awayTeamSlug,
        );
      } else if (_status == 'postponed' ||
          _status == 'cancelled' ||
          _status == 'abandoned') {
        await processor.saveWithoutScore(
          matchRef: widget.match.ref,
          status: _status,
        );
      } else {
        await widget.match.ref.set({
          'status': 'scheduled',
          'homeScore': FieldValue.delete(),
          'awayScore': FieldValue.delete(),
          'resultConfirmed': false,
          'processed': false,
          'verwerkt': false,
        }, SetOptions(merge: true));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Opslaan mislukt: $e');
      }
    }
  }

  int? _parseScore(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  bool _validDate(String value) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
    if (!match) return false;

    final parsed = DateTime.tryParse(value);
    return parsed != null;
  }

  bool _validTime(String value) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return false;

    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;

    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  DateTime? _combineDateAndTime(String date, String time) {
    final dateParts = date.split('-');
    final timeParts = time.split(':');

    if (dateParts.length != 3 || timeParts.length != 2) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if ([year, month, day, hour, minute].any((part) => part == null)) {
      return null;
    }

    return DateTime(year!, month!, day!, hour!, minute!);
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'finished':
        return 'Afgelopen';
      case 'postponed':
        return 'In te halen';
      case 'cancelled':
        return 'Afgelast';
      case 'abandoned':
        return 'Gestaakt';
      case 'scheduled':
      default:
        return 'Gepland';
    }
  }
}

class _MatchDoc {
  const _MatchDoc({
    required this.ref,
    required this.id,
    required this.division,
    required this.round,
    required this.roundMatchIndex,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamSlug,
    required this.awayTeamSlug,
    required this.homeTeamLogo,
    required this.awayTeamLogo,
    required this.homeTeamLogoAsset,
    required this.awayTeamLogoAsset,
    required this.homeLogo,
    required this.awayLogo,
    required this.homeLogoAsset,
    required this.awayLogoAsset,
    required this.date,
    required this.kickoffTime,
    required this.weekdayNL,
    required this.status,
    required this.homeScore,
    required this.awayScore,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String id;
  final String division;
  final int round;
  final int roundMatchIndex;
  final String homeTeam;
  final String awayTeam;
  final String homeTeamSlug;
  final String awayTeamSlug;
  final String homeTeamLogo;
  final String awayTeamLogo;
  final String homeTeamLogoAsset;
  final String awayTeamLogoAsset;
  final String homeLogo;
  final String awayLogo;
  final String homeLogoAsset;
  final String awayLogoAsset;
  final String date;
  final String kickoffTime;
  final String weekdayNL;
  final String status;
  final int? homeScore;
  final int? awayScore;

  factory _MatchDoc.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _MatchDoc(
      ref: doc.reference,
      id: _string(data['id'], doc.id),
      division: _string(data['division'], ''),
      round: _int(data['round'], 0),
      roundMatchIndex: _int(data['roundMatchIndex'], 0),
      homeTeam: _string(
        data['homeTeam'] ?? data['homeTeamName'] ?? data['home'],
        '',
      ),
      awayTeam: _string(
        data['awayTeam'] ?? data['awayTeamName'] ?? data['away'],
        '',
      ),
      homeTeamSlug: _string(data['homeTeamSlug'] ?? data['homeSlug'], ''),
      awayTeamSlug: _string(data['awayTeamSlug'] ?? data['awaySlug'], ''),
      homeTeamLogo: _string(data['homeTeamLogo'], ''),
      awayTeamLogo: _string(data['awayTeamLogo'], ''),
      homeTeamLogoAsset: _string(data['homeTeamLogoAsset'], ''),
      awayTeamLogoAsset: _string(data['awayTeamLogoAsset'], ''),
      homeLogo: _string(data['homeLogo'], ''),
      awayLogo: _string(data['awayLogo'], ''),
      homeLogoAsset: _string(data['homeLogoAsset'], ''),
      awayLogoAsset: _string(data['awayLogoAsset'], ''),
      date: _string(data['date'], ''),
      kickoffTime: _string(
        data['kickoffTime'] ?? data['time'] ?? data['kickoff'],
        '',
      ),
      weekdayNL: _string(data['weekdayNL'], ''),
      status: _string(data['status'], 'scheduled'),
      homeScore: _nullableInt(data['homeScore']),
      awayScore: _nullableInt(data['awayScore']),
    );
  }

  static int compareForPublicDisplay(_MatchDoc a, _MatchDoc b) {
    final roundResult = a.round.compareTo(b.round);
    if (roundResult != 0) return roundResult;
    final aDate = DateTime.tryParse(a.date);
    final bDate = DateTime.tryParse(b.date);
    if (aDate != null && bDate != null) {
      final dateResult = aDate.compareTo(bDate);
      if (dateResult != 0) return dateResult;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }
    final timeResult = a.kickoffTime.compareTo(b.kickoffTime);
    if (timeResult != 0) return timeResult;
    final indexResult = a.roundMatchIndex.compareTo(b.roundMatchIndex);
    if (indexResult != 0) return indexResult;
    return a.homeTeam.compareTo(b.homeTeam);
  }

  static String _string(dynamic value, String fallback) {
    if (value == null) return fallback;
    return value.toString();
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
