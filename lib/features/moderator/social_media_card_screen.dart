import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';

enum SocialCardMode { program, results }

class SocialMediaCardScreen extends StatefulWidget {
  const SocialMediaCardScreen({super.key});

  @override
  State<SocialMediaCardScreen> createState() => _SocialMediaCardScreenState();
}

class _SocialMediaCardScreenState extends State<SocialMediaCardScreen> {
  final _cardKey = GlobalKey();
  String _division = SeasonConfig.divisionA;
  int _round = 1;
  SocialCardMode _mode = SocialCardMode.program;
  bool _exporting = false;

  String get _divisionName => SeasonConfig.divisionName(_division);

  String get _tweetText {
    final type = _mode == SocialCardMode.program ? 'Programma' : 'De uitslagen';
    return '$type van speelronde $_round in de $_divisionName.\n\n#DerdeDivisie #DerdeDiv';
  }

  Stream<List<SocialCardMatch>> _matchesStream() {
    return SeasonPaths.currentSeasonMatches.snapshots().map((snapshot) {
      final matches = snapshot.docs
          .where((doc) => doc.id != '_meta')
          .map((doc) => SocialCardMatch.fromDoc(doc))
          .where(
              (match) => match.division == _division && match.round == _round)
          .toList()
        ..sort(SocialCardMatch.compare);
      return matches;
    });
  }

  Future<void> _downloadPng() async {
    setState(() => _exporting = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final data = bytes?.buffer.asUint8List();
      if (data == null) return;
      _downloadBytes(data);
      await ActivityLogService().log(
        eventType: ActivityEventType.socialCardGenerated,
        metadata: {
          'division': _division,
          'round': _round,
          'mode': _mode.name,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PNG is gedownload. Voeg deze handmatig toe aan X.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _downloadBytes(Uint8List data) {
    final blob = html.Blob([data], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download =
          'derdedev-${_division.toLowerCase()}-ronde-$_round-${_mode.name}.png'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _tweetText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('X-tekst gekopieerd.')),
    );
  }

  Future<void> _openComposer() async {
    final url =
        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_tweetText)}';
    await launchUrlString(url, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sociale media')),
      body: StreamBuilder<List<SocialCardMatch>>(
        stream: _matchesStream(),
        builder: (context, snapshot) {
          final matches = snapshot.data ?? const <SocialCardMatch>[];
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              return ListView(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Controls(
                            division: _division,
                            round: _round,
                            mode: _mode,
                            exporting: _exporting,
                            onDivisionChanged: (value) =>
                                setState(() => _division = value),
                            onRoundChanged: (value) =>
                                setState(() => _round = value),
                            onModeChanged: (value) =>
                                setState(() => _mode = value),
                            onDownload: _downloadPng,
                            onCopy: _copyText,
                            onRefresh: () => setState(() {}),
                            onOpenComposer: _openComposer,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (snapshot.hasError)
                            const AppCard(
                              child: Text(
                                'De sociale mediakaart kon niet worden geladen.',
                              ),
                            )
                          else if (!snapshot.hasData)
                            const Center(child: CircularProgressIndicator())
                          else
                            _PreviewFrame(
                              child: RepaintBoundary(
                                key: _cardKey,
                                child: SocialMediaMatchCard(
                                  divisionName: _divisionName,
                                  round: _round,
                                  mode: _mode,
                                  matches: matches,
                                  tweetText: _tweetText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.division,
    required this.round,
    required this.mode,
    required this.exporting,
    required this.onDivisionChanged,
    required this.onRoundChanged,
    required this.onModeChanged,
    required this.onDownload,
    required this.onCopy,
    required this.onRefresh,
    required this.onOpenComposer,
  });

  final String division;
  final int round;
  final SocialCardMode mode;
  final bool exporting;
  final ValueChanged<String> onDivisionChanged;
  final ValueChanged<int> onRoundChanged;
  final ValueChanged<SocialCardMode> onModeChanged;
  final VoidCallback onDownload;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final VoidCallback onOpenComposer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: SeasonConfig.divisionA, label: Text('A')),
              ButtonSegment(value: SeasonConfig.divisionB, label: Text('B')),
            ],
            selected: {division},
            onSelectionChanged: (selection) =>
                onDivisionChanged(selection.first),
          ),
          DropdownButton<int>(
            value: round,
            items: [
              for (var i = 1; i <= 34; i++)
                DropdownMenuItem(value: i, child: Text('Speelronde $i')),
            ],
            onChanged: (value) {
              if (value != null) onRoundChanged(value);
            },
          ),
          SegmentedButton<SocialCardMode>(
            segments: const [
              ButtonSegment(
                value: SocialCardMode.program,
                label: Text('Programma'),
              ),
              ButtonSegment(
                value: SocialCardMode.results,
                label: Text('Uitslagen'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
          FilledButton.icon(
            onPressed: exporting ? null : onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('PNG downloaden'),
          ),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('X tekst'),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Voorbeeld vernieuwen',
            icon: const Icon(Icons.refresh_outlined),
          ),
          IconButton(
            onPressed: onOpenComposer,
            tooltip: 'X composer openen',
            icon: const Icon(Icons.open_in_new_outlined),
          ),
        ],
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: .25,
      maxScale: 2,
      child: Center(child: child),
    );
  }
}

class SocialMediaMatchCard extends StatelessWidget {
  const SocialMediaMatchCard({
    super.key,
    required this.divisionName,
    required this.round,
    required this.mode,
    required this.matches,
    required this.tweetText,
  });

  final String divisionName;
  final int round;
  final SocialCardMode mode;
  final List<SocialCardMatch> matches;
  final String tweetText;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateLabel(matches);
    return SizedBox(
      width: 1200,
      height: 675,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06100B), Color(0xFF153B2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 42, 56, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const DerdeDivLogo.full(width: 210, height: 54),
                  const Spacer(),
                  Text(
                    'derdediv.nl',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .82),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      mode == SocialCardMode.program
                          ? 'Programma'
                          : 'Uitslagen',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$divisionName - speelronde $round\n$dateLabel',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFBDE8C8),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: matches.length == 9
                    ? Column(
                        children: [
                          for (final match in matches)
                            Expanded(
                              child: _SocialMatchRow(match: match, mode: mode),
                            ),
                        ],
                      )
                    : Center(
                        child: Text(
                          matches.isEmpty
                              ? 'Geen wedstrijden voor deze selectie'
                              : '${matches.length} wedstrijden gevonden; verwacht 9.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(List<SocialCardMatch> matches) {
    final dates = matches.map((match) => match.dateTime).whereType<DateTime>();
    if (dates.isEmpty) return 'Datum volgt';
    final sorted = dates.toList()..sort();
    final first = sorted.first;
    final last = sorted.last;
    final format = DateFormat('d MMMM yyyy', 'nl_NL');
    if (DateUtils.isSameDay(first, last)) return format.format(first);
    return '${format.format(first)} - ${format.format(last)}';
  }
}

class _SocialMatchRow extends StatelessWidget {
  const _SocialMatchRow({required this.match, required this.mode});

  final SocialCardMatch match;
  final SocialCardMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Expanded(child: _team(match.homeTeam, false)),
          SizedBox(
            width: 168,
            child: Text(
              _centerLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(child: _team(match.awayTeam, true)),
        ],
      ),
    );
  }

  Widget _team(String name, bool end) {
    final children = [
      TeamLogo(teamName: name, size: 42, padding: 1),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          name,
          textAlign: end ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ];
    return Row(
      textDirection: end ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      children: children,
    );
  }

  String _centerLabel() {
    if (match.status == MatchStatus.postponed) return 'Uitgesteld';
    if (match.status == MatchStatus.cancelled) return 'Afgelast';
    if (match.status == MatchStatus.abandoned) return 'Gestaakt';
    if (mode == SocialCardMode.results &&
        match.homeScore != null &&
        match.awayScore != null) {
      return '${match.homeScore} - ${match.awayScore}';
    }
    return match.kickoffTime;
  }
}

class SocialCardMatch {
  const SocialCardMatch({
    required this.id,
    required this.division,
    required this.round,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffTime,
    required this.status,
    required this.data,
    this.dateTime,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final String division;
  final int round;
  final String homeTeam;
  final String awayTeam;
  final String kickoffTime;
  final MatchStatus status;
  final Map<String, dynamic> data;
  final DateTime? dateTime;
  final int? homeScore;
  final int? awayScore;

  factory SocialCardMatch.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SocialCardMatch(
      id: doc.id,
      division: SeasonConfig.normalizeDivisionCode(
        (data['division'] ?? data['competitie'] ?? '').toString(),
      ),
      round: _int(data['round'] ?? data['speelronde']),
      homeTeam:
          _text(data['homeTeamName'] ?? data['homeTeam'] ?? data['thuisteam']),
      awayTeam:
          _text(data['awayTeamName'] ?? data['awayTeam'] ?? data['uitteam']),
      kickoffTime: MatchDateTimeFormatter.publicTime(data),
      status: parseMatchStatus(data['status']),
      dateTime: MatchDateTimeFormatter.dateTimeFromData(data),
      homeScore: _nullableInt(data['homeScore'] ?? data['uitslagThuis']),
      awayScore: _nullableInt(data['awayScore'] ?? data['uitslagUit']),
      data: data,
    );
  }

  static int compare(SocialCardMatch a, SocialCardMatch b) {
    return MatchDateTimeFormatter.compare(a.data, b.data);
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}
