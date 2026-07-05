import 'package:flutter/material.dart';

import 'package:derde_divisie/features/moderator/moderator_menu_screen.dart';
import 'package:derde_divisie/features/moderator/moderator_tools_screen.dart';
import 'package:derde_divisie/helpers/herbereken_standen_tool.dart';
import 'package:derde_divisie/loggboek/update_log_screen.dart';
import 'package:derde_divisie/loggboek/update_service.dart';
import 'package:derde_divisie/features/moderator/activity_log_screen.dart';

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
                child: Wrap(
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
              ),
            ),
          );
        },
      ),
    );
  }
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
