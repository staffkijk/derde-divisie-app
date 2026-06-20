import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'update_service.dart';
import 'app_update.dart';

class UpdateLogScreen extends StatelessWidget {
  final UpdateService service;

  /// Geef hier door of de huidige gebruiker admin/moderator is.
  /// Standaard false, zodat er geen dead-code warning ontstaat.
  final bool isAdmin;

  const UpdateLogScreen({
    super.key,
    required this.service,
    this.isAdmin = false,
  });

  String _formatTs(DateTime dt) {
    // NL weergave, bv. "22 augustus 2025 – 13:47"
    final df = DateFormat("d MMMM y – HH:mm", "nl_NL");
    return df.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: StreamBuilder<List<AppUpdate>>(
        stream: service.streamUpdates(limit: 200),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final updates = snapshot.data ?? [];
          if (updates.isEmpty) {
            return const Center(child: Text('Nog geen updates.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: updates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final up = updates[i];
              final created = up.createdAt?.toDate() ?? DateTime.now();

              return Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titel zoals jij hem wilt tonen
                      Text(
                        up.title.isNotEmpty
                            ? up.title
                            : 'Update ${_formatTs(created)} - versie ${up.version}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Chip(
                            label: Text(up.type),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTs(created),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  // withOpacity is deprecated in nieuwere Flutter versies:
                                  // gebruik withValues(alpha: ...)
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        up.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton:
          isAdmin ? _AdminAddButton(service: service) : null,
    );
  }
}

class _AdminAddButton extends StatelessWidget {
  final UpdateService service;
  const _AdminAddButton({required this.service});

  Future<void> _openDialog(BuildContext context) async {
    final versionCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String type = 'notice';

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nieuwe update'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText:
                        'Titel (bv. "Update 22 augustus 2025 - versie 1.1")',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: versionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Versie (bv. 1.1)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'notice', child: Text('Notice')),
                    DropdownMenuItem(value: 'feature', child: Text('Feature')),
                    DropdownMenuItem(value: 'fix', child: Text('Fix')),
                  ],
                  onChanged: (v) => type = v ?? 'notice',
                  decoration: const InputDecoration(labelText: 'Soort'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Beschrijving',
                    hintText: 'Schrijf hier de update-tekst…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annuleren'),
              onPressed: () => Navigator.pop(ctx),
            ),
            FilledButton(
              child: const Text('Opslaan'),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    versionCtrl.text.trim().isEmpty) {
                  return;
                }
                await service.addUpdate(
                  version: versionCtrl.text.trim(),
                  title: titleCtrl.text.trim(),
                  body: bodyCtrl.text.trim(),
                  type: type,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('Update'),
    );
  }
}
