import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/services/csv_export_service.dart';

class ModeratorExportScreen extends StatefulWidget {
  const ModeratorExportScreen({super.key});

  @override
  State<ModeratorExportScreen> createState() => _ModeratorExportScreenState();
}

class _ModeratorExportScreenState extends State<ModeratorExportScreen> {
  bool _exporting = false;
  final _service = const CsvExportService();

  Future<void> _export(bool resultsOnly) async {
    setState(() => _exporting = true);
    try {
      final count = await _service.exportMatches(resultsOnly: resultsOnly);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count regels geëxporteerd.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export mislukt: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('CSV-exports')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const AppCard(
                child: Text(
                  'Exports lezen uitsluitend bestaande season-data en wijzigen niets in Firestore.',
                  style: AppTextStyles.bodyMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ExportCard(
                title: 'Programma',
                description:
                    'Alle wedstrijden van het actieve seizoen, inclusief datum, tijd en status.',
                icon: Icons.calendar_month_outlined,
                enabled: kIsWeb && !_exporting,
                onPressed: () => _export(false),
              ),
              const SizedBox(height: AppSpacing.md),
              _ExportCard(
                title: 'Uitslagen',
                description:
                    'Alleen wedstrijden met status Afgelopen, inclusief scores en processingstatus.',
                icon: Icons.fact_check_outlined,
                enabled: kIsWeb && !_exporting,
                onPressed: () => _export(true),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ranking- en voorspellingsexport',
                      style: AppTextStyles.sectionTitle,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Voorbereid als vervolgstap. De app gebruikt nog zowel season predictions als de backward-compatible rootcollectie; export wordt pas geactiveerd nadat totalen tussen beide bronnen gecontroleerd zijn.',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'CSV-download is momenteel alleen beschikbaar in de webapp.',
                  style: TextStyle(color: AppColors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('CSV'),
          ),
        ],
      ),
    );
  }
}
