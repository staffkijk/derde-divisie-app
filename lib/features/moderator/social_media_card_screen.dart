import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/data/services/analytics_service.dart';
import 'package:derde_divisie/features/moderator/social_media_models.dart';
import 'package:derde_divisie/features/moderator/social_png_delivery.dart';
import 'package:derde_divisie/features/moderator/social_png_save_dialog.dart';

export 'package:derde_divisie/features/moderator/social_media_models.dart';

const socialExportSize = Size(1600, 900);

class SocialMediaCardScreen extends StatefulWidget {
  const SocialMediaCardScreen({super.key});
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
  final pngDelivery = SocialPngDeliveryService();

  Future<SocialCardData> load() async {
    if (mode == SocialCardMode.program) {
      final current = await SeasonPaths.systemCurrentSeasonDoc.get();
      final seasonId = current.data()?['seasonId']?.toString().trim();
      if (seasonId == null || seasonId.isEmpty || seasonId.contains('/')) {
        throw StateError('system/current_season bevat geen geldig seasonId.');
      }
      final snapshot = await SeasonPaths.matches(seasonId).get();
      final matches = snapshot.docs
          .where((doc) => doc.id != '_meta')
          .map(SocialCardMatch.fromDoc)
          .where((match) =>
              match.round == round &&
              (match.division == 'A' || match.division == 'B'))
          .toList()
        ..sort(SocialCardMatch.compare);
      return SocialCardData(
        matches: matches,
        standings: const [],
        predictionSummary: const PredictionSummary(),
      );
    }
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
        .where((entry) => entry.division == division)
        .toList()
      ..sort(SocialStanding.compare);
    final users =
        all[2].docs.map((doc) => RankingUser(doc.id, doc.data())).toList();
    final predictions = all[3].docs.map((doc) => doc.data()).toList();
    return SocialCardData(
      matches: filterSocialMatches(matches, division: division, round: round),
      standings: standings,
      predictionSummary: buildPredictionSummary(
        users: users,
        predictions: predictions,
        roundMatchIds: matches
            .where((match) => match.round == round)
            .map((match) => match.id)
            .toSet(),
      ),
    );
  }

  String xText(SocialCardData data) {
    String fit(String full, String short) =>
        full.runes.length <= 280 ? full : short;
    if (mode == SocialCardMode.predictions) {
      final winner = data.predictionSummary.weekWinners.isEmpty
          ? 'Nog geen weekwinnaar'
          : data.predictionSummary.weekWinners
              .map((e) => '${e.name} - ${e.score} punten')
              .join('\n');
      final top = data.predictionSummary.globalTop
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value.name} - ${e.value.score}')
          .join('\n');
      return fit(
        'Weekwinnaar speelronde $round \u{1F3C6}\n$winner\n\n'
            'Top 5 algemeen:\n$top\n\nderdediv.nl',
        'Weekwinnaar speelronde $round \u{1F3C6}\n$winner\n\n'
            'Volledige ranglijst: derdediv.nl',
      );
    }
    final title = mode == SocialCardMode.program ? 'Programma' : 'Uitslagen';
    final lines = data.matches.map((match) {
      final center = socialMatchCenterLabel(match, mode);
      return '${match.homeTeam} $center ${match.awayTeam}';
    }).join('\n');
    final name = mode == SocialCardMode.program
        ? 'Derde Divisie A + B'
        : SeasonConfig.divisionName(division);
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
      image.dispose();
      if (bytes == null) throw StateError('PNG kon niet worden gemaakt.');
      if (!mounted) return;
      final delivery = await downloadSocialPng(
        context,
        bytes.buffer.asUint8List(),
        socialFileName(
            mode, mode == SocialCardMode.program ? 'AB' : division, round),
        service: pngDelivery,
      );
      if (delivery == null || delivery == SocialPngDeliveryResult.cancelled) {
        return;
      }
      await ActivityLogService().log(
        eventType: ActivityEventType.socialCardGenerated,
        metadata: {'division': division, 'round': round, 'mode': mode.name},
      );
      await AnalyticsService.instance
          .trackShareClicked(source: 'social_card_png');
      if (mounted && delivery == SocialPngDeliveryResult.downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PNG-download gestart.'),
          ),
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
          key: ValueKey('$division-$round-$refresh'),
          future: load(),
          builder: (context, snapshot) {
            final data = snapshot.data;
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
                          pngButtonLabel: pngDelivery.isIOS
                              ? 'PNG opslaan'
                              : 'PNG downloaden',
                          onDivision: (v) => setState(() => division = v),
                          onRound: (v) => setState(() => round = v),
                          onMode: (v) => setState(() => mode = v),
                          onDownload:
                              data == null ? null : () => download(data),
                          onCopy: data == null ? null : () => copy(data),
                          onRefresh: () => setState(() => refresh++),
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
                              minWidth: socialExportSize.width,
                              maxWidth: socialExportSize.width,
                              minHeight: socialExportSize.height,
                              maxHeight: socialExportSize.height,
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
    this.pngButtonLabel = 'PNG downloaden',
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
  final String pngButtonLabel;

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
                if (mode != SocialCardMode.program)
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
                    for (var i = 1; i <= 34; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('Speelronde $i'),
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
                  label: Text(pngButtonLabel),
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
  const SocialMediaPreview({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxWidth / socialExportSize.aspectRatio,
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
        size: socialExportSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF06100B), Color(0xFF153B2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: mode == SocialCardMode.program
                ? const EdgeInsets.fromLTRB(40, 24, 40, 28)
                : const EdgeInsets.fromLTRB(48, 38, 48, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mode == SocialCardMode.program)
                  SocialExportHeader(
                      title: 'PROGRAMMA',
                      subtitle:
                          'Speelronde $round  \u{2022}  Derde Divisie A + B',
                      compact: true)
                else ...[
                  const Row(
                    children: [
                      DerdeDivLogo.full(
                        width: 205,
                        height: 53,
                        responsive: false,
                      ),
                      Spacer(),
                      Text(
                        'derdediv.nl',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    mode == SocialCardMode.program
                        ? 'PROGRAMMA'
                        : mode == SocialCardMode.results
                            ? 'UITSLAGEN'
                            : 'VOORSPELPOULE',
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    mode == SocialCardMode.predictions
                        ? 'Speelronde $round'
                        : 'Speelronde $round  \u{2022}  $divisionName',
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFFBDE8C8),
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                SizedBox(height: mode == SocialCardMode.program ? 12 : 18),
                Expanded(
                  child: mode == SocialCardMode.predictions
                      ? PredictionContent(
                          summary: data.predictionSummary,
                        )
                      : mode == SocialCardMode.program
                          ? ProgramContent(matches: data.matches)
                          : MatchStandContent(
                              matches: data.matches,
                              standings: data.standings,
                              mode: mode,
                            ),
                ),
              ],
            ),
          ),
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
  });
  final List<SocialCardMatch> matches;
  final List<SocialStanding> standings;
  final SocialCardMode mode;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              key: const ValueKey('social-matches-column'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                    height: 42,
                    child: Text('WEDSTRIJDEN',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900))),
                Expanded(
                  child: matches.isEmpty
                      ? const Center(
                          child: Text('Geen wedstrijden voor deze selectie',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 24)))
                      : Column(children: [
                          for (final match in matches)
                            Expanded(child: MatchRow(match: match, mode: mode)),
                        ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 9,
            child: Column(
              key: const ValueKey('social-standings-column'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                    height: 42,
                    child: Text('STAND',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900))),
                Expanded(child: StandTable(standings: standings)),
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
          TeamLogo(teamName: name, size: 31, padding: 1),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              key: ValueKey('team-$name'),
              textAlign: end ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Expanded(child: team(match.homeTeam, false)),
            SizedBox(
              width: 130,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  socialMatchCenterLabel(match, mode),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Expanded(child: team(match.awayTeam, true)),
          ],
        ),
      );
}

class StandTable extends StatelessWidget {
  const StandTable({super.key, required this.standings});
  final List<SocialStanding> standings;

  Widget cell(String text, double width, {TextAlign align = TextAlign.right}) =>
      SizedBox(
        width: width,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: const TextStyle(color: Colors.white, fontSize: 13),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(children: [
            cell('#', 27, align: TextAlign.left),
            const Expanded(
                child: Text('Club',
                    style: TextStyle(color: Colors.white, fontSize: 13))),
            cell('G', 37),
            cell('W', 37),
            cell('GL', 37),
            cell('V', 37),
            cell('DV-DT', 61),
            cell('DS', 38),
            cell('Ptn', 38),
          ]),
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
                          size: 21,
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
                  cell('${standings[i].played}', 37),
                  cell('${standings[i].wins}', 37),
                  cell('${standings[i].draws}', 37),
                  cell('${standings[i].losses}', 37),
                  cell(
                    '${standings[i].goalsFor}-${standings[i].goalsAgainst}',
                    61,
                  ),
                  cell('${standings[i].goalDifference}', 38),
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
  const PredictionContent({super.key, required this.summary});
  final PredictionSummary summary;
  @override
  Widget build(BuildContext context) {
    final winners = summary.weekWinners;
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
                'WEEKWINNAAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
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

/// PNG bytes are prepared before the iOS dialog button is tapped, preserving
/// the user activation required by navigator.share even after slow rendering.
Future<SocialPngDeliveryResult?> downloadSocialPng(
  BuildContext context,
  Uint8List data,
  String fileName, {
  SocialPngDeliveryService? service,
}) {
  final delivery = service ?? SocialPngDeliveryService();
  if (delivery.isIOS) {
    return showDialog<SocialPngDeliveryResult>(
      context: context,
      builder: (_) => SocialPngSaveDialog(
          bytes: data, fileName: fileName, service: delivery),
    );
  }
  return delivery.deliver(data, fileName);
}
