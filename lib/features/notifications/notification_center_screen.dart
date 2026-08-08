import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/data/services/prediction_reminder_service.dart';
import 'package:derde_divisie/features/notifications/prediction_reminder_preferences_panel.dart';
import 'package:derde_divisie/data/services/notification_preferences_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    required this.onOpenPrediction,
  });

  final void Function(String division, int round) onOpenPrediction;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _service = PredictionReminderService();

  @override
  void initState() {
    super.initState();
    NotificationPreferencesService().cleanupIfDisabled();
  }

  Future<void> _showSettings() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tune_rounded),
            SizedBox(width: 8),
            Text('Meldingsinstellingen'),
          ],
        ),
        content: const SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: PredictionReminderPreferencesPanel(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        if (authSnapshot.data == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: SizedBox.shrink(),
          );
        }
        return _buildAuthenticatedCenter();
      },
    );
  }

  Widget _buildAuthenticatedCenter() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meldingen'),
        actions: [
          IconButton(
            tooltip: 'Meldingsinstellingen',
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.notificationsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Je hebt geen meldingen.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final read = data['read'] == true;
              return AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    read
                        ? Icons.notifications_none_outlined
                        : Icons.notifications_active_outlined,
                    color: read ? AppColors.textMuted : AppColors.primary,
                  ),
                  title: Text(
                    (data['title'] ?? 'Melding').toString(),
                    style: TextStyle(
                      fontWeight: read ? FontWeight.w600 : FontWeight.w900,
                    ),
                  ),
                  subtitle: Text((data['body'] ?? '').toString()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await _service.markRead(doc.id);
                    await ActivityLogService().log(
                      eventType: ActivityEventType.notificationOpened,
                      metadata: {
                        'type': data['type']?.toString() ?? 'unknown',
                        'division': data['division']?.toString() ?? '',
                        'round': data['round']?.toString() ?? '',
                      },
                    );
                    if (!context.mounted) return;
                    final target = await _service.resolveNavigationTarget(
                      notificationDivision: data['division']?.toString(),
                      notificationRound:
                          int.tryParse(data['round']?.toString() ?? ''),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    widget.onOpenPrediction(target.division, target.round);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
