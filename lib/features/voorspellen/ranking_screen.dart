import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:derde_divisie/features/profiel/bekijk_profiel_screen.dart';
import 'package:derde_divisie/features/voorspellen/bekijk_voorspellingen_screen.dart';
import 'package:derde_divisie/core/widgets/ranking_app_bar.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  void _toonActiesVoorGebruiker(
      BuildContext context, DocumentSnapshot user, String contextType) {
    final userId = user.id;
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Bekijk profiel'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BekijkProfielScreen(userId: userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Bekijk voorspellingen'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BekijkVoorspellingenScreen(
                    userId: userId,
                    contextType: contextType,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🔧 Bepaalt automatisch het juiste type image (asset vs network)
  ImageProvider? _avatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('assets/')) return AssetImage(url);
    return null; // onbekend formaat → toon icon
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      appBar: RankingAppBar(
        context: context,
        title: 'Ranglijsten',
        fallbackRoute: predictionsRankingsRoute,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .orderBy('totalen', descending: true)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;
          final indexEigen = users.indexWhere((u) => u.id == uid);
          final eigenUser = indexEigen >= 0 ? users[indexEigen] : null;

          final top3 = users.take(3).toList();
          final scrollbareTop = users.length > 3
              ? users.sublist(3, users.length < 10 ? users.length : 10)
              : [];

          Widget buildUserTile(DocumentSnapshot user, int index,
              {bool highlight = false, required String contextType}) {
            final data = user.data() as Map<String, dynamic>;
            final username = data['username'] ?? 'Onbekend';
            final punten = contextType == 'A'
                ? (data['punten_A'] ?? 0)
                : contextType == 'B'
                    ? (data['punten_B'] ?? 0)
                    : (data['totalen'] ?? 0);
            final profielfotoUrl = (data['avatarUrl'] ?? '').toString();
            final provider = _avatarProvider(profielfotoUrl);

            Icon? medaille;
            if (index == 0) {
              medaille = const Icon(Icons.emoji_events, color: Colors.amber);
            } else if (index == 1) {
              medaille = const Icon(Icons.emoji_events, color: Colors.grey);
            } else if (index == 2) {
              medaille = const Icon(Icons.emoji_events, color: Colors.brown);
            }

            return ListTile(
              tileColor: highlight ? Colors.green[50] : null,
              leading: GestureDetector(
                onTap: () =>
                    _toonActiesVoorGebruiker(context, user, contextType),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: provider,
                      child: provider == null ? const Icon(Icons.person) : null,
                    ),
                    if (medaille != null)
                      Positioned(
                        bottom: -2,
                        right: -4,
                        child: medaille,
                      ),
                  ],
                ),
              ),
              title: Text(username),
              subtitle: Text('Punten: $punten'),
              trailing: Text('#${index + 1}'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                '🏆 Globale ranglijst (beste score uit A of B)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...top3.asMap().entries.map(
                    (e) => buildUserTile(
                      e.value,
                      e.key,
                      highlight: e.value.id == uid,
                      contextType: 'algemeen',
                    ),
                  ),
              if (scrollbareTop.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: scrollbareTop.length,
                    itemBuilder: (context, i) {
                      final echteIndex = i + 3;
                      return buildUserTile(
                        scrollbareTop[i],
                        echteIndex,
                        highlight: scrollbareTop[i].id == uid,
                        contextType: 'algemeen',
                      );
                    },
                  ),
                ),
              if (eigenUser != null && indexEigen >= 10)
                Column(
                  children: [
                    const Divider(),
                    const Text('📍 Jouw positie'),
                    buildUserTile(
                      eigenUser,
                      indexEigen,
                      highlight: true,
                      contextType: 'algemeen',
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '⚽ Divisie A (alleen A-voorspellingen)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('punten_A', descending: true)
                    .get(),
                builder: (context, aSnap) {
                  if (!aSnap.hasData) return const CircularProgressIndicator();
                  final aUsers = aSnap.data!.docs;
                  final indexA = aUsers.indexWhere((u) => u.id == uid);
                  final eigenA = indexA >= 0 ? aUsers[indexA] : null;

                  return Column(
                    children: [
                      ...aUsers.take(5).toList().asMap().entries.map(
                            (e) => buildUserTile(
                              e.value,
                              e.key,
                              highlight: e.value.id == uid,
                              contextType: 'A',
                            ),
                          ),
                      if (indexA >= 5 && eigenA != null)
                        Column(
                          children: [
                            const Divider(),
                            const Text('📍 Jouw positie'),
                            buildUserTile(
                              eigenA,
                              indexA,
                              highlight: true,
                              contextType: 'A',
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '⚽ Divisie B (alleen B-voorspellingen)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('punten_B', descending: true)
                    .get(),
                builder: (context, bSnap) {
                  if (!bSnap.hasData) return const CircularProgressIndicator();
                  final bUsers = bSnap.data!.docs;
                  final indexB = bUsers.indexWhere((u) => u.id == uid);
                  final eigenB = indexB >= 0 ? bUsers[indexB] : null;

                  return Column(
                    children: [
                      ...bUsers.take(5).toList().asMap().entries.map(
                            (e) => buildUserTile(
                              e.value,
                              e.key,
                              highlight: e.value.id == uid,
                              contextType: 'B',
                            ),
                          ),
                      if (indexB >= 5 && eigenB != null)
                        Column(
                          children: [
                            const Divider(),
                            const Text('📍 Jouw positie'),
                            buildUserTile(
                              eigenB,
                              indexB,
                              highlight: true,
                              contextType: 'B',
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
