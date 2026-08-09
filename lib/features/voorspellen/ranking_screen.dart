import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/core/widgets/ranking_app_bar.dart';
import 'package:derde_divisie/features/profiel/bekijk_profiel_screen.dart';
import 'package:derde_divisie/features/voorspellen/bekijk_voorspellingen_screen.dart';
import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';
import 'package:derde_divisie/features/voorspellen/user_display_name.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key, required this.type});

  final RankingType type;

  void _showUserActions(BuildContext context, DocumentSnapshot user) {
    final contextType = rankingContextType(type);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Bekijk profiel'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BekijkProfielScreen(userId: user.id),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Bekijk voorspellingen'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BekijkVoorspellingenScreen(
                  userId: user.id,
                  contextType: contextType,
                ),
              ));
            },
          ),
        ],
      ),
    );
  }

  ImageProvider? _avatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('assets/')) return AssetImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      appBar: RankingAppBar(
        context: context,
        title: rankingTitle(type),
        fallbackRoute: predictionsRankingsRoute,
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Ranglijst kon niet worden geladen.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users =
              sortRanking<QueryDocumentSnapshot<Map<String, dynamic>>>(
            snapshot.data!.docs,
            type: type,
            dataOf: (user) => user.data(),
            idOf: (user) => user.id,
          );
          final ownIndex = users.indexWhere((user) => user.id == uid);
          final visible = users.take(10).toList();

          Widget userTile(
            QueryDocumentSnapshot<Map<String, dynamic>> user,
            int index,
          ) {
            final data = user.data();
            final avatar =
                _avatarProvider((data['avatarUrl'] ?? '').toString());
            Color? medalColor;
            if (index == 0) {
              medalColor = Colors.amber;
            } else if (index == 1) {
              medalColor = Colors.grey;
            } else if (index == 2) {
              medalColor = Colors.brown;
            }
            return ListTile(
              tileColor: user.id == uid ? Colors.green[50] : null,
              leading: GestureDetector(
                onTap: () => _showUserActions(context, user),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: avatar,
                      child: avatar == null ? const Icon(Icons.person) : null,
                    ),
                    if (medalColor != null)
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Icon(Icons.emoji_events, color: medalColor),
                      ),
                  ],
                ),
              ),
              title: Text(resolveUserDisplayName(data)),
              subtitle: Text('Punten: ${rankingScore(data, type)}'),
              trailing: Text('#${index + 1}'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...visible.asMap().entries.map(
                    (entry) => userTile(entry.value, entry.key),
                  ),
              if (ownIndex >= visible.length) ...[
                const Divider(),
                const Text(
                  'Jouw positie',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                userTile(users[ownIndex], ownIndex),
              ],
            ],
          );
        },
      ),
    );
  }
}
