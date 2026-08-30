import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/data/services/analytics_service.dart';
import 'package:derde_divisie/features/moderator/social_media_models.dart';
import 'package:derde_divisie/features/moderator/social_png_delivery.dart';

export 'package:derde_divisie/features/moderator/social_media_models.dart';

const socialExportSize = Size(1080, 1350);
const programSocialExportSize = Size(1600, 900);

Size socialExportSizeFor(SocialCardMode mode) =>
    mode == SocialCardMode.predictions
        ? socialExportSize
        : programSocialExportSize;

class SocialMediaCardScreen extends StatefulWidget {
  const SocialMediaCardScreen({super.key, this.pngDelivery});

  final SocialPngDeliveryService? pngDelivery;
  @override
  State<SocialMediaCardScreen> createState() => _SocialMediaCardScreenState();
}

class _SocialMediaCardScreenState extends State<SocialMediaCardScreen> {
  final exportKey = GlobalKey();
  String division = SeasonConfig.divisionA;
  int round = 1;
  SocialCardMode mode = SocialCardMode.program;
  bool exporting = false;
  int refresh = 0;

  Future<SocialCardData> load() async {
    final all = await Future.wait([
      SeasonPaths.currentSeasonMatches.get(),
      SeasonPaths.currentSeasonStandings.get(),
      FirebaseFirestore.instance.collection('users').get(),
      SeasonPaths.currentSeasonPredictions.get(),
    ]);
    final matches = all[0]
        .docs
        .where((doc) => doc.id != '_meta')
        .map(SocialCardMatch.fromDoc)
        .toList();
    final standings = all[1]
        .docs
        .map(SocialStanding.fromDoc)
        .where((entry) =>
            mode == SocialCardMode.program || entry.division == division)
        .toList()
      ..sort(SocialStanding.compare);
    final users =
        all[2].docs.map((doc) => RankingUser(doc.id, doc.data())).toList();
    final predictions = all[3].docs.map((doc) => doc.data()).toList();
    final period = PredictionSocialPeriod.forRound(round);
    final periodMatches = matches.where((match) =>
        match.round >= period.startRound && match.round <= period.endRound);
    final throughMatches =
        matches.where((match) => match.round <= period.endRound);
    return SocialCardData(
      matches: mode == SocialCardMode.program
          ? (matches.where((match) => match.round == round).toList()
            ..sort(SocialCardMatch.compare))
          : filterSocialMatches(matches, division: division, round: round),
      standings: standings,
      predictionSummary: buildPredictionSummary(
        users: users,
        predictions: predictions,
        periodMatchDivisions: {
          for (final match in periodMatches) match.id: match.division,
        },
        throughMatchDivisions: {
          for (final match in throughMatches) match.id: match.division,
        },
      ),
      formByTeam: buildSocialForm(
        standings: standings,
        matches: matches.where((match) => match.round <= round),
      ),
      predictionPeriodComplete: predictionPeriodIsComplete(matches, period),
    );
  }

  String xText(SocialCardData data) {
    String fit(String full, String short) =>
        full.runes.length <= 280 ? full : short;
    if (mode == SocialCardMode.predictions) {
      return fit(
        predictionSocialText(data.predictionSummary, round),
        predictionSocialText(data.predictionSummary, round, compact: true),
      );
    }
    final title = mode == SocialCardMode.program ? 'Programma' : 'Uitslagen';
    final lines = data.matches.map((match) {
      final center = mode == SocialCardMode.results &&
              match.homeScore != null &&
              match.awayScore != null
          ? '${match.homeScore}-${match.awayScore}'
          : match.kickoffTime;
      return '${match.homeTeam} $center ${match.awayTeam}';
    }).join('\n');
    final name = SeasonConfig.divisionName(division);
    final ending = mode == SocialCardMode.program
        ? 'Bekijk het volledige programma en de stand'
        : 'Bekijk de stand';
    return fit(
      '$title speelronde $round | $name\n\n$lines\n\n'
          '$ending op derdediv.nl',
      '$title speelronde $round | $name\n\n$ending op derdediv.nl',
    );
  }

  Future<void> download(SocialCardData data) async {
    setState(() => exporting = true);
    try {
      final names = {
        ...data.matches.expand((e) => [e.homeTeam, e.awayTeam]),
        ...data.standings.map((e) => e.name),
      };
      final assets = <ImageProvider>[
        const AssetImage(DerdeDivLogo.fullAsset),
        for (final name in names)
          AssetImage(SeasonConfig.logoPathForTeam(name)),
      ];
      await Future.wait(assets.map((asset) async {
        try {
          await precacheImage(asset, context);
        } catch (_) {}
      }));
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final boundary = exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Exportcanvas ontbreekt.');
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG kon niet worden gemaakt.');
      final delivery =
          await (widget.pngDelivery ?? SocialPngDeliveryService()).deliver(
        bytes.buffer.asUint8List(),
        socialFileName(
          mode,
          mode == SocialCardMode.program ? 'AB' : division,
          round,
        ),
      );
      await ActivityLogService().log(
        eventType: ActivityEventType.socialCardGenerated,
        metadata: {'division': division, 'round': round, 'mode': mode.name},
      );
      await AnalyticsService.instance
          .trackShareClicked(source: 'social_card_png');
      if (mounted && delivery == SocialPngDeliveryResult.downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PNG gedownload.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PNG maken is mislukt: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> copy(SocialCardData data) async {
    await Clipboard.setData(ClipboardData(text: xText(data)));
    await AnalyticsService.instance
        .trackShareClicked(source: 'social_card_text');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('X-tekst gekopieerd.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Sociale media')),
        body: FutureBuilder<SocialCardData>(
          key: ValueKey('$division-$round-${mode.name}-$refresh'),
          future: load(),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final exportSize = socialExportSizeFor(mode);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SocialMediaControls(
                          division: division,
                          round: round,
                          mode: mode,
                          exporting: exporting,
                          onDivision: (v) => setState(() => division = v),
                          onRound: (v) => setState(() => round = v),
                          onMode: (v) => setState(() {
                            mode = v;
                            if (v == SocialCardMode.predictions) {
                              round = PredictionSocialPeriod.forRound(round)
                                  .endRound;
                            }
                          }),
                          onDownload: data == null ||
                                  (mode == SocialCardMode.predictions &&
                                      !data.predictionPeriodComplete)
                              ? null
                              : () => download(data),
                          onCopy: data == null ? null : () => copy(data),
                          onRefresh: () => setState(() => refresh++),
                        ),
                        if (data != null &&
                            mode == SocialCardMode.predictions &&
                            !data.predictionPeriodComplete)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Deze periode is nog niet volledig verwerkt.',
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (snapshot.hasError)
                          const AppCard(
                            child: Text('Afbeelding kon niet worden geladen.'),
                          )
                        else if (data == null)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          SocialMediaPreview(
                            mode: mode,
                            child: SocialMediaExportCanvas(
                              divisionName: SeasonConfig.divisionName(division),
                              round: round,
                              mode: mode,
                              data: data,
                            ),
                          ),
                          SizedBox(
                            width: 0,
                            height: 0,
                            child: OverflowBox(
                              minWidth: exportSize.width,
                              maxWidth: exportSize.width,
                              minHeight: exportSize.height,
                              maxHeight: exportSize.height,
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: const Offset(-2000, 0),
                                child: RepaintBoundary(
                                  key: exportKey,
                                  child: SocialMediaExportCanvas(
                                    divisionName:
                                        SeasonConfig.divisionName(division),
                                    round: round,
                                    mode: mode,
                                    data: data,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class SocialMediaControls extends StatelessWidget {
  const SocialMediaControls({
    super.key,
    required this.division,
    required this.round,
    required this.mode,
    required this.exporting,
    required this.onDivision,
    required this.onRound,
    required this.onMode,
    required this.onDownload,
    required this.onCopy,
    required this.onRefresh,
  });
  final String division;
  final int round;
  final SocialCardMode mode;
  final bool exporting;
  final ValueChanged<String> onDivision;
  final ValueChanged<int> onRound;
  final ValueChanged<SocialCardMode> onMode;
  final VoidCallback? onDownload;
  final VoidCallback? onCopy;
  final VoidCallback onRefresh;

  String label(SocialCardMode value) {
    if (value == SocialCardMode.program) return 'Programma';
    if (value == SocialCardMode.results) return 'Uitslagen';
    return 'Voorspelpoule';
  }

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: SeasonConfig.divisionA,
                      label: Text('A'),
                    ),
                    ButtonSegment(
                      value: SeasonConfig.divisionB,
                      label: Text('B'),
                    ),
                  ],
                  selected: {division},
                  onSelectionChanged: (v) => onDivision(v.first),
                ),
                DropdownButton<int>(
                  value: round,
                  items: [
                    for (final i in socialRoundChoices(mode))
                      DropdownMenuItem(
                        value: i,
                        child: Text(mode == SocialCardMode.predictions
                            ? 'Na speelronde $i'
                            : 'Speelronde $i'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onRound(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in SocialCardMode.values)
                  ChoiceChip(
                    label: Text(label(value)),
                    selected: mode == value,
                    onSelected: (_) => onMode(value),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
                  tooltip: 'Vernieuwen',
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
          ],
        ),
      );
}

class SocialMediaPreview extends StatelessWidget {
  const SocialMediaPreview(
      {super.key, required this.child, required this.mode});
  final Widget child;
  final SocialCardMode mode;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxWidth / socialExportSizeFor(mode).aspectRatio,
          child: ClipRect(
            child: FittedBox(fit: BoxFit.contain, child: child),
          ),
        ),
      );
}

class SocialMediaExportCanvas extends StatelessWidget {
  const SocialMediaExportCanvas({
    super.key,
    required this.divisionName,
    required this.round,
    required this.mode,
    required this.data,
  });
  final String divisionName;
  final int round;
  final SocialCardMode mode;
  final SocialCardData data;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        key: const ValueKey('social-export-canvas'),
        size: socialExportSizeFor(mode),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF06100B), Color(0xFF153B2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              40,
              mode == SocialCardMode.predictions ? 34 : 24,
              40,
              mode == SocialCardMode.predictions ? 34 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SocialExportHeader(
                  title: mode == SocialCardMode.program
                      ? 'PROGRAMMA'
                      : mode == SocialCardMode.results
                          ? divisionName
                          : 'VOORSPELPOULE',
                  subtitle: mode == SocialCardMode.program
                      ? 'Speelronde $round  \u{2022}  Derde Divisie A + B'
                      : mode == SocialCardMode.predictions
                          ? 'Na speelronde $round'
                          : 'Speelronde $round',
                  compact: mode != SocialCardMode.predictions,
                ),
                SizedBox(height: mode == SocialCardMode.predictions ? 18 : 12),
                Expanded(
                  child: mode == SocialCardMode.predictions
                      ? PredictionContent(
                          summary: data.predictionSummary,
                          period: PredictionSocialPeriod.forRound(round),
                        )
                      : mode == SocialCardMode.program
                          ? ProgramContent(matches: data.matches)
                          : MatchStandContent(
                              matches: data.matches,
                              standings: data.standings,
                              mode: mode,
                              formByTeam: data.formByTeam,
                            ),
                ),
              ],
            ),
          ),
        ),
      );
}

class SocialExportHeader extends StatelessWidget {
  const SocialExportHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.compact,
  });
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: compact ? 76 : 122,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: DerdeDivLogo.full(
                width: 180,
                height: 47,
                responsive: false,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  key: const ValueKey('social-header-title'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 39 : 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  key: const ValueKey('social-header-subtitle'),
                  style: TextStyle(
                    color: const Color(0xFFBDE8C8),
                    fontSize: compact ? 20 : 25,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'derdediv.nl',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class SocialMediaMatchCard extends StatelessWidget {
  const SocialMediaMatchCard({
    super.key,
    required this.divisionName,
    required this.round,
    required this.mode,
    required this.matches,
    required this.tweetText,
    this.standings = const [],
  });
  final String divisionName;
  final int round;
  final SocialCardMode mode;
  final List<SocialCardMatch> matches;
  final String tweetText;
  final List<SocialStanding> standings;
  @override
  Widget build(BuildContext context) => SocialMediaExportCanvas(
        divisionName: divisionName,
        round: round,
        mode: mode,
        data: SocialCardData(
          matches: matches,
          standings: standings,
          predictionSummary: const PredictionSummary(),
        ),
      );
}

class ProgramContent extends StatelessWidget {
  const ProgramContent({super.key, required this.matches});
  final List<SocialCardMatch> matches;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final division in const ['A', 'B']) ...[
            Expanded(
              child: ProgramDivisionColumn(
                division: division,
                matches: matches
                    .where((match) => match.division == division)
                    .toList(),
              ),
            ),
            if (division == 'A') const SizedBox(width: 28),
          ],
        ],
      );
}

class ProgramDivisionColumn extends StatelessWidget {
  const ProgramDivisionColumn({
    super.key,
    required this.division,
    required this.matches,
  });
  final String division;
  final List<SocialCardMatch> matches;

  @override
  Widget build(BuildContext context) {
    final groups = groupSocialMatchesByDate(matches);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DERDE DIVISIE $division',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Geen wedstrijden',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  for (final entry in groups.entries) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 10,
                      ),
                      color: const Color(0xFF2E7D4F),
                      child: Text(
                        socialDateHeader(entry.key),
                        key: ValueKey(
                          'date-$division-${socialDateHeader(entry.key)}',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    for (final match in entry.value)
                      Expanded(
                        child: MatchRow(
                          match: match,
                          mode: SocialCardMode.program,
                        ),
                      ),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MatchStandContent extends StatelessWidget {
  const MatchStandContent({
    super.key,
    required this.matches,
    required this.standings,
    required this.mode,
    required this.formByTeam,
  });
  final List<SocialCardMatch> matches;
  final List<SocialStanding> standings;
  final SocialCardMode mode;
  final Map<String, List<SocialFormResult>> formByTeam;

  Widget sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sectionTitle('UITSLAGEN'),
                if (matches.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Geen wedstrijden voor deze selectie',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final match in matches)
                        SizedBox(
                          height: 58,
                          child: MatchRow(match: match, mode: mode),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sectionTitle('STAND'),
                Expanded(
                  child: StandTable(
                    standings: standings,
                    formByTeam: formByTeam,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class MatchRow extends StatelessWidget {
  const MatchRow({super.key, required this.match, required this.mode});
  final SocialCardMatch match;
  final SocialCardMode mode;

  Widget team(String name, bool end) => Row(
        textDirection: end ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        children: [
          TeamLogo(
            teamName: name,
            size: mode == SocialCardMode.results ? 25 : 31,
            padding: 1,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              key: ValueKey('team-$name'),
              textAlign: end ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: mode == SocialCardMode.results ? 15 : 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );

  String center() {
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

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('match-row-${match.id}'),
        margin: EdgeInsets.symmetric(
          vertical: mode == SocialCardMode.results ? 2 : 3,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: mode == SocialCardMode.results ? 9 : 12,
          vertical: mode == SocialCardMode.results ? 4 : 0,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Expanded(child: team(match.homeTeam, false)),
            SizedBox(
              width: mode == SocialCardMode.results ? 104 : 130,
              child: Text(
                center(),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: mode == SocialCardMode.results ? 22 : 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(child: team(match.awayTeam, true)),
          ],
        ),
      );
}

class StandTable extends StatelessWidget {
  const StandTable({
    super.key,
    required this.standings,
    this.formByTeam = const {},
  });
  final List<SocialStanding> standings;
  final Map<String, List<SocialFormResult>> formByTeam;

  Widget cell(
    String text,
    double width, {
    TextAlign align = TextAlign.right,
    bool bold = false,
  }) =>
      SizedBox(
        width: width,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Center(
        child: Text(
          'Stand nog niet beschikbaar',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
      );
    }
    return Column(
      children: [
        Container(
          key: const ValueKey('stand-header'),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(
            children: [
              cell('#', 27, align: TextAlign.left, bold: true),
              const Expanded(
                child: Text(
                  'Club',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              cell('G', 37, bold: true),
              cell('DS', 42, bold: true),
              cell('Ptn', 38, bold: true),
            ],
          ),
        ),
        for (var i = 0; i < standings.length; i++)
          Expanded(
            child: Container(
              color: i.isEven ? Colors.white.withValues(alpha: .055) : null,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                children: [
                  cell('${i + 1}', 27, align: TextAlign.left),
                  Expanded(
                    child: Row(
                      children: [
                        TeamLogo(
                          teamName: standings[i].name,
                          size: 19,
                          padding: 1,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            standings[i].name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final value in formByTeam[canonicalSocialTeamKey(
                            standings[i].name,
                            division: standings[i].division,
                            teamId: standings[i].teamId,
                          )] ??
                          const <SocialFormResult>[])
                        Container(
                          key: ValueKey(
                              'form-${standings[i].name}-${value.name}'),
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 2),
                          color: value == SocialFormResult.win
                              ? Colors.green
                              : value == SocialFormResult.draw
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                    ],
                  ),
                  cell('${standings[i].played}', 37),
                  cell('${standings[i].goalDifference}', 42),
                  cell('${standings[i].points}', 38),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class PredictionContent extends StatelessWidget {
  const PredictionContent({
    super.key,
    required this.summary,
    required this.period,
  });
  final PredictionSummary summary;
  final PredictionSocialPeriod period;
  @override
  Widget build(BuildContext context) {
    final winners = summary.periodWinners;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D4F),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD66B),
                size: 56,
              ),
              const Text(
                'PERIODEWINNAAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                period.rangeLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                winners.isEmpty
                    ? 'Nog geen verwerkte punten'
                    : winners
                        .take(4)
                        .map((winner) => winner.name)
                        .join('  \u{2022}  '),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (winners.isNotEmpty)
                Text(
                  '${winners.first.score} punten',
                  style: const TextStyle(
                    color: Color(0xFFDEFFE7),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'GLOBALE STAND  \u{2022}  TOP 5',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in summary.globalTop.take(5).toList().asMap().entries)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      '${entry.key + 1}.',
                      style: const TextStyle(
                        color: Color(0xFFBDE8C8),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value.score} punten',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
