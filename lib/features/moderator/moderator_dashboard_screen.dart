import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/firestore/season_paths.dart';
import 'package:derde_divisie/features/moderator/moderator_menu_screen.dart';
import 'package:derde_divisie/features/moderator/moderator_tools_screen.dart';
import 'package:derde_divisie/helpers/herbereken_standen_tool.dart';
import 'package:derde_divisie/loggboek/update_log_screen.dart';
import 'package:derde_divisie/loggboek/update_service.dart';
import 'package:derde_divisie/features/moderator/activity_log_screen.dart';
import 'package:derde_divisie/features/moderator/moderator_export_screen.dart';

class ModeratorDashboardScreen extends StatelessWidget {
  const ModeratorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ModeratorTool(
        icon: Icons.insights_outlined,
        title: 'Gebruikersactiviteit',
        description: 'Bekijk recente functionele events en moderatoracties.',
        screen: const ActivityLogScreen(),
      ),
      _ModeratorTool(
        icon: Icons.scoreboard_outlined,
        title: 'Uitslagen invoeren',
        description: 'Voer wedstrijduitslagen in en verwerk standen.',
        screen: const ModeratorMenuScreen(),
      ),
      _ModeratorTool(
        icon: Icons.event_note_outlined,
        title: 'Wedstrijden beheren',
        description: 'Bekijk en beheer het programma per divisie.',
        screen: const ModeratorMenuScreen(),
      ),
      _ModeratorTool(
        icon: Icons.leaderboard_outlined,
        title: 'Standen beheren',
        description: 'Controleer of herbereken standen.',
        screen: const HerberekenStandenTool(),
      ),
      _ModeratorTool(
        icon: Icons.campaign_outlined,
        title: 'Updates beheren',
        description: 'Plaats of beheer app updates en mededelingen.',
        screen: UpdateLogScreen(
          service: UpdateService(),
          isAdmin: true,
        ),
      ),
      _ModeratorTool(
        icon: Icons.download_outlined,
        title: 'CSV-exports',
        description: 'Exporteer programma en verwerkte uitslagen.',
        screen: const ModeratorExportScreen(),
      ),
      _ModeratorTool(
        icon: Icons.build_outlined,
        title: 'Technische controles',
        description: 'Open de bestaande audit- en hersteltools.',
        screen: const ModeratorToolsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Moderator dashboard')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth >= 820
              ? (constraints.maxWidth.clamp(0, 1100) - 44) / 2
              : constraints.maxWidth;
          return SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 14 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ModeratorSummary(),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: tools
                          .map(
                            (tool) => SizedBox(
                              width: cardWidth,
                              child: _ModeratorToolCard(tool: tool),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeratorSummary extends StatelessWidget {
  const _ModeratorSummary();

  Future<_SummaryData> _load() async {
    final results = await Future.wait([
      SeasonPaths.currentSeasonMatches.get(),
      FirebaseFirestore.instance
          .collection('activityLogs')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get(),
    ]);
    final matches = results[0];
    final activities = results[1];
    var processed = 0;
    var errors = 0;
    final statuses = <String, int>{};
    for (final doc in matches.docs.where((doc) => doc.id != '_meta')) {
      final data = doc.data();
      final status = (data['status'] ?? 'scheduled').toString();
      statuses[status] = (statuses[status] ?? 0) + 1;
      if (data['processed'] == true || data['verwerkt'] == true) processed++;
      if ((data['processingError'] ?? '').toString().trim().isNotEmpty) {
        errors++;
      }
    }
    return _SummaryData(
      matches: matches.docs.where((doc) => doc.id != '_meta').length,
      processed: processed,
      errors: errors,
      recentActivities: activities.docs.length,
      scheduled: statuses['scheduled'] ?? 0,
      postponed: statuses['postponed'] ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SummaryData>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AppCard(
            child: Text(
              'Dashboardstatistieken konden niet worden geladen.',
              style: AppTextStyles.bodyMuted,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seizoensoverzicht',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _Metric('Wedstrijden', data.matches, Icons.sports_soccer),
                  _Metric('Gepland', data.scheduled, Icons.event_outlined),
                  _Metric('Uitgesteld', data.postponed, Icons.schedule),
                  _Metric('Verwerkt', data.processed, Icons.check_circle),
                  _Metric('Fouten', data.errors, Icons.error_outline),
                  _Metric(
                    'Recente events',
                    data.recentActivities,
                    Icons.insights_outlined,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.matches,
    required this.processed,
    required this.errors,
    required this.recentActivities,
    required this.scheduled,
    required this.postponed,
  });

  final int matches;
  final int processed;
  final int errors;
  final int recentActivities;
  final int scheduled;
  final int postponed;
}

class _ModeratorTool {
  const _ModeratorTool({
    required this.icon,
    required this.title,
    required this.description,
    required this.screen,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget screen;
}

class _ModeratorToolCard extends StatelessWidget {
  const _ModeratorToolCard({required this.tool});

  final _ModeratorTool tool;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EADF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tool.icon, color: const Color(0xFF2F8F3B), size: 30),
          const SizedBox(height: 12),
          Text(
            tool.title,
            style: const TextStyle(
              color: Color(0xFF153B2A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            tool.description,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => tool.screen),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Openen'),
          ),
        ],
      ),
    );
  }
}
