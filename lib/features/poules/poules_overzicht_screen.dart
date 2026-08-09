import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/models/poule_prediction_scope.dart';
import 'create_poule_screen.dart';
import 'zoek_poule_screen.dart';
import 'poule_detail_screen.dart';

class PoulesOverzichtScreen extends StatefulWidget {
  const PoulesOverzichtScreen({super.key});

  @override
  State<PoulesOverzichtScreen> createState() => _PoulesOverzichtScreenState();
}

class _PoulesOverzichtScreenState extends State<PoulesOverzichtScreen> {
  late Future<List<_PouleItem>> _poulesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _poulesFuture = _loadPoules();
  }

  Future<List<_PouleItem>> _loadPoules() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const [];
    final snapshot =
        await FirebaseFirestore.instance.collection('poules').get();
    final items = <_PouleItem>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final participants = await doc.reference.collection('deelnemers').get();
      final joined = participants.docs.any((member) => member.id == userId);
      final ownerId = (data['ownerId'] ?? data['eigenaarId'] ?? '').toString();
      String ownerName = '';
      if (ownerId.isNotEmpty) {
        final owner = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        ownerName = (owner.data()?['username'] ?? '').toString();
      }
      items.add(
        _PouleItem(
          id: doc.id,
          data: data,
          joined: joined,
          participantCount: participants.docs.length,
          ownerName: ownerName,
          isOwner: ownerId == userId,
        ),
      );
    }
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
          child: FutureBuilder<List<_PouleItem>>(
            future: _poulesFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _PouleState(
                  icon: Icons.error_outline,
                  title: 'Poules konden niet worden geladen',
                  text: 'Probeer het later opnieuw.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final mine = all.where((item) => item.joined).toList();
              final public =
                  all.where((item) => item.isPublic && !item.joined).toList();
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final actions = Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _open(const ZoekPouleScreen()),
                              icon: const Icon(Icons.search),
                              label: const Text('Poule zoeken'),
                            ),
                            FilledButton.icon(
                              onPressed: () => _open(const CreatePouleScreen()),
                              icon: const Icon(Icons.add),
                              label: const Text('Nieuwe poule'),
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 650) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(),
                              const SizedBox(height: AppSpacing.md),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _header()),
                            const SizedBox(width: AppSpacing.md),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PouleSection(
                    title: 'Mijn poules',
                    subtitle: 'Poules waarin je deelnemer of beheerder bent.',
                    items: mine,
                    emptyText:
                        'Je zit nog niet in een poule. Maak er één of zoek een openbare poule.',
                    onOpen: (item) =>
                        _open(PouleDetailScreen(pouleId: item.id)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PouleSection(
                    title: 'Openbare poules',
                    subtitle:
                        'Vindbare poules waar je veilig aan kunt deelnemen.',
                    items: public.take(12).toList(),
                    emptyText: 'Er zijn geen andere openbare poules gevonden.',
                    onOpen: (item) =>
                        _open(PouleDetailScreen(pouleId: item.id)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Poules', style: AppTextStyles.pageTitle),
        SizedBox(height: AppSpacing.xxs),
        Text(
          'Vergelijk je centrale voorspellingen met vrienden en andere deelnemers.',
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );
  }
}

class _PouleSection extends StatelessWidget {
  const _PouleSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyText,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final List<_PouleItem> items;
  final String emptyText;
  final ValueChanged<_PouleItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.xxs),
        Text(subtitle, style: AppTextStyles.bodyMuted),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          AppCard(
            child: Text(emptyText, style: AppTextStyles.bodyMuted),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 950
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: count == 1 ? 2.5 : 1.55,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _PouleCard(
                    item: item,
                    onTap: () => onOpen(item),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _PouleCard extends StatelessWidget {
  const _PouleCard({required this.item, required this.onTap});

  final _PouleItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.type == 'team'
                      ? Icons.shield_outlined
                      : Icons.emoji_events_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                Icon(
                  item.isPublic ? Icons.public : Icons.lock_outline,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.typeLabel,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              item.predictionScope.label,
              style: AppTextStyles.bodyMuted,
            ),
            if (item.ownerName.isNotEmpty)
              Text(
                'Beheerder: ${item.ownerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMuted,
              ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 17,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text('${item.participantCount} deelnemers'),
                const Spacer(),
                if (item.isOwner)
                  const Text(
                    'Beheerder',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PouleState extends StatelessWidget {
  const _PouleState({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 36),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(text, style: AppTextStyles.bodyMuted),
          ],
        ),
      ),
    );
  }
}

class _PouleItem {
  const _PouleItem({
    required this.id,
    required this.data,
    required this.joined,
    required this.participantCount,
    required this.ownerName,
    required this.isOwner,
  });

  final String id;
  final Map<String, dynamic> data;
  final bool joined;
  final int participantCount;
  final String ownerName;
  final bool isOwner;

  String get name => (data['name'] ?? 'Naam onbekend').toString();
  bool get isPublic => data['isPublic'] != false;
  String get type {
    final value = (data['type'] ?? data['competition'] ?? '').toString();
    return value == 'team' || value == 'one_team' ? 'team' : 'competition';
  }

  String get typeLabel {
    if (type != 'team') return 'Hele competitie';
    final team = (data['teamName'] ?? data['selectedTeam'] ?? '').toString();
    return team.isEmpty ? 'Teampoule' : 'Teampoule · $team';
  }

  PoulePredictionScope get predictionScope =>
      parsePoulePredictionScope(data['predictionScope']);
}
