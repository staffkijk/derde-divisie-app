import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/services/activity_analytics.dart';
import 'package:derde_divisie/data/services/activity_event_utils.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _eventType = ActivityEventKeys.all;

  Stream<QuerySnapshot<Map<String, dynamic>>> _activityStream() {
    return FirebaseFirestore.instance
        .collection('activityLogs')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gebruikersactiviteit')),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                        width: 420,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Functionele events',
                              style: AppTextStyles.sectionTitle,
                            ),
                            SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Maximaal 200 recente events; filtering gebeurt lokaal zonder extra indexen.',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: _eventType,
                        items: ActivityEventUtils.filterKeys
                            .map(
                              (key) => DropdownMenuItem(
                                value: key,
                                child: Text(ActivityEventUtils.labelFor(key)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _eventType = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _activityStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint(
                          'Activity logs laden mislukt: ${snapshot.error}',
                        );
                        return const _State(
                          icon: Icons.error_outline,
                          text:
                              'Activiteit kon nu niet worden geladen. Probeer het later opnieuw.',
                          color: AppColors.danger,
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final events = snapshot.data!.docs
                          .map(ActivityLogEntry.fromSnapshot)
                          .toList();
                      final filtered =
                          ActivityEventUtils.applyFilter(events, _eventType);
                      final analytics = ActivityAnalytics.summarize(events);

                      return ListView(
                        children: [
                          _AnalyticsOverview(summary: analytics),
                          const SizedBox(height: AppSpacing.md),
                          if (filtered.isEmpty)
                            const SizedBox(
                              height: 220,
                              child: _State(
                                icon: Icons.history_toggle_off,
                                text: 'Geen events gevonden voor dit filter.',
                                color: AppColors.textMuted,
                              ),
                            )
                          else
                            AppCard(
                              padding: EdgeInsets.zero,
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final event = filtered[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.bolt_outlined,
                                      color: AppColors.primary,
                                    ),
                                    title: Text(
                                      ActivityEventUtils.labelFor(
                                        event.canonicalEventType,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (event.displayName.trim().isNotEmpty)
                                          event.displayName
                                        else if (event.userId.trim().isNotEmpty)
                                          event.userId
                                        else
                                          'Onbekende gebruiker',
                                        if (event.entityId.trim().isNotEmpty)
                                          event.entityId,
                                      ].join(' - '),
                                    ),
                                    trailing: Text(
                                      event.createdAt == null
                                          ? 'wordt verwerkt'
                                          : DateFormat('d MMM, HH:mm', 'nl_NL')
                                              .format(event.createdAt!),
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
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
      ),
    );
  }
}

class _AnalyticsOverview extends StatelessWidget {
  const _AnalyticsOverview({required this.summary});

  final ActivityAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _StatCard('Vandaag', summary.eventsToday),
            _StatCard('7 dagen', summary.eventsSevenDays),
            _StatCard('Actieve gebruikers', summary.uniqueUsers),
            _StatCard('Voorspellingen', summary.predictionsSaved),
            _StatCard('Logins', summary.logins),
            _StatCard('Schermen', summary.screenViews),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final width = wide
                ? (constraints.maxWidth - AppSpacing.md) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: width,
                  child: _BarChartCard(
                    title: 'Activiteit per dag',
                    values: summary.activityPerDay,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _BarChartCard(
                    title: 'Verdeling per eventtype',
                    values: summary.eventDistribution,
                    labelBuilder: ActivityEventUtils.labelFor,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _BarChartCard(
                    title: 'Meest bekeken schermen',
                    values: summary.screenViewsByName,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _BarChartCard(
                    title: 'Navigatiebestemmingen',
                    values: summary.navigationByDestination,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _BarChartCard(
                    title: 'Voorspellingen per speelronde',
                    values: summary.predictionsByRound,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Cijfers zijn gebaseerd op maximaal 200 geladen events.',
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: AppTextStyles.bodyMuted),
          ],
        ),
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.title,
    required this.values,
    this.labelBuilder,
  });

  final String title;
  final Map<String, int> values;
  final String Function(String value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final entries =
        values.entries.where((entry) => entry.value > 0).take(7).toList();
    final max = entries.fold<int>(
        0, (value, entry) => entry.value > value ? entry.value : value);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            const Text('Nog geen gegevens.', style: AppTextStyles.bodyMuted)
          else
            for (final entry in entries) ...[
              Row(
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      labelBuilder?.call(entry.key) ?? entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: max == 0 ? 0 : entry.value / max,
                        color: AppColors.primary,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(width: 32, child: Text('${entry.value}')),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _State extends StatelessWidget {
  const _State({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
