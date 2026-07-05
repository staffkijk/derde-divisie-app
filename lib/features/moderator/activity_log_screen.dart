import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:derde_divisie/core/design/app_design.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _eventType = 'all';

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('activityLogs');
    if (_eventType != 'all') {
      query = query.where('eventType', isEqualTo: _eventType);
    }
    return query.orderBy('createdAt', descending: true).limit(200);
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
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Functionele events',
                              style: AppTextStyles.sectionTitle,
                            ),
                            SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Maximaal 200 recente events; zonder gevoelige inhoud.',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      DropdownButton<String>(
                        value: _eventType,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Alle events'),
                          ),
                          DropdownMenuItem(
                            value: 'login',
                            child: Text('Login'),
                          ),
                          DropdownMenuItem(
                            value: 'register',
                            child: Text('Registratie'),
                          ),
                          DropdownMenuItem(
                            value: 'prediction_saved',
                            child: Text('Voorspelling'),
                          ),
                          DropdownMenuItem(
                            value: 'favorite_team_changed',
                            child: Text('Favoriete club'),
                          ),
                          DropdownMenuItem(
                            value: 'result_saved_by_moderator',
                            child: Text('Uitslag opgeslagen'),
                          ),
                          DropdownMenuItem(
                            value: 'result_processed',
                            child: Text('Uitslag verwerkt'),
                          ),
                          DropdownMenuItem(
                            value: 'update_read',
                            child: Text('Update gelezen'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _eventType = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _query().snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _State(
                          icon: Icons.error_outline,
                          text:
                              'Activiteit kon niet worden geladen. Controleer moderatorrechten en indexen.',
                          color: AppColors.danger,
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const _State(
                          icon: Icons.history_toggle_off,
                          text: 'Nog geen events voor dit filter.',
                          color: AppColors.textMuted,
                        );
                      }
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final createdAt = data['createdAt'] as Timestamp?;
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.bolt_outlined,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                (data['eventType'] ?? 'onbekend').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if ((data['displayName'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    data['displayName'].toString()
                                  else
                                    (data['uid'] ?? '').toString(),
                                  if ((data['entityId'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    data['entityId'].toString(),
                                ].join(' · '),
                              ),
                              trailing: Text(
                                createdAt == null
                                    ? 'wordt verwerkt'
                                    : DateFormat(
                                        'd MMM, HH:mm',
                                        'nl_NL',
                                      ).format(createdAt.toDate()),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
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
