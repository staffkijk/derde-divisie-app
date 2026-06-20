// lib/screens/prediction_overview_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../prediction_screen.dart';
import '../screens/eindstand_voorspelling_screen.dart';
// Acties vanuit ranglijsten:
import '../screens/bekijk_profiel_screen.dart';
import '../screens/bekijk_voorspellingen_screen.dart';
// ignore_for_file: deprecated_member_use


class PredictionOverviewScreen extends StatelessWidget {
  const PredictionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16), // iets compacter
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Voorspellen'), // headers laten zoals gevraagd
            const SizedBox(height: 8),
            const _PredictionGrid(),
            const SizedBox(height: 18),
            const Divider(height: 24),
            const SizedBox(height: 14),
            const _SectionHeader(title: '🏆 Globale top 3'),
            const SizedBox(height: 8),
            const _GlobalPodium(),
            const SizedBox(height: 8),
            const _OwnPositionChip(),
            const SizedBox(height: 14),
            const _SectionHeader(title: 'Volledige ranglijsten'),
            const SizedBox(height: 8),
            const _FullRankingLinks(),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

// ====== HEADERS ======

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.tune, color: Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ====== PREDICTION GRID ======

class _PredictionGrid extends StatelessWidget {
  const _PredictionGrid();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // < 600px => mobiel (VERTICAAL)
    if (w < 600) {
      return Column(
        children: const [
          _ActionTile(
            icon: Icons.sports_soccer,
            title: 'Wedstrijden – Divisie A',
            subtitle: 'Voorspel de uitslagen',
            route: _ActionRoute.matchesA,
          ),
          SizedBox(height: 6),
          _ActionTile(
            icon: Icons.flag,
            title: 'Eindstand – Divisie A',
            subtitle: 'Voorspel de eindranglijst',
            route: _ActionRoute.tableA,
          ),
          SizedBox(height: 6),
          _ActionTile(
            icon: Icons.sports_soccer,
            title: 'Wedstrijden – Divisie B',
            subtitle: 'Voorspel de uitslagen',
            route: _ActionRoute.matchesB,
          ),
          SizedBox(height: 6),
          _ActionTile(
            icon: Icons.flag,
            title: 'Eindstand – Divisie B',
            subtitle: 'Voorspel de eindranglijst',
            route: _ActionRoute.tableB,
          ),
        ],
      );
    }

    // Tablet/desktop: 2 kolommen, slanker
    final childAspect = w >= 1000 ? 6.2 : 5.0; // iets compacter dan vorige
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: childAspect,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: const [
        _ActionTile(
          icon: Icons.sports_soccer,
          title: 'Wedstrijden – Divisie A',
          subtitle: 'Voorspel de uitslagen',
          route: _ActionRoute.matchesA,
        ),
        _ActionTile(
          icon: Icons.sports_soccer,
          title: 'Wedstrijden – Divisie B',
          subtitle: 'Voorspel de uitslagen',
          route: _ActionRoute.matchesB,
        ),
        _ActionTile(
          icon: Icons.flag,
          title: 'Eindstand – Divisie A',
          subtitle: 'Voorspel de eindranglijst',
          route: _ActionRoute.tableA,
        ),
        _ActionTile(
          icon: Icons.flag,
          title: 'Eindstand – Divisie B',
          subtitle: 'Voorspel de eindranglijst',
          route: _ActionRoute.tableB,
        ),
      ],
    );
  }
}

enum _ActionRoute { matchesA, matchesB, tableA, tableB }

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final _ActionRoute route;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.route,
  });

  void _go(BuildContext context) {
    switch (route) {
      case _ActionRoute.matchesA:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PredictionScreen(divisie: 'A')),
        );
        break;
      case _ActionRoute.matchesB:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PredictionScreen(divisie: 'B')),
        );
        break;
      case _ActionRoute.tableA:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const EindstandVoorspellingScreen(divisie: 'A')),
        );
        break;
      case _ActionRoute.tableB:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const EindstandVoorspellingScreen(divisie: 'B')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _go(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // compacter
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ====== PODIUM ======

class _GlobalPodium extends StatelessWidget {
  const _GlobalPodium();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalen', descending: true)
          .limit(3)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 220, child: Center(child: CircularProgressIndicator()));
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox(
            height: 150,
            child: Center(child: Text('Nog geen spelers in de ranglijst.')),
          );
        }

        Widget tile(DocumentSnapshot doc, int rank, double barHeight) {
          final data = doc.data() as Map<String, dynamic>;
          final username = (data['username'] ?? '—').toString();
          final points = (data['totalen'] ?? 0).toString();
          final avatarUrl = data['avatarUrl']?.toString();

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Avatar(username: username, avatarUrl: avatarUrl, rank: rank),
              const SizedBox(height: 6),
              Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: rank == 1 ? FontWeight.w700 : FontWeight.w500),
              ),
              Text("$points pt",
                  style: TextStyle(
                      fontSize: 12, color: Colors.black.withOpacity(0.65))),
              const SizedBox(height: 6),
              Container(
                width: rank == 1 ? 62 : 52,
                height: barHeight,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.emoji_events,
                      size: 18,
                      color:
                          rank == 1 ? Colors.amber[900] : Colors.brown[400]),
                ),
              ),
              // Rangnummer weggelaten; podiumhoogte zegt genoeg (A gekozen)
            ],
          );
        }

        return SizedBox(
          height: 230,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (docs.length > 1)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: tile(docs[1], 2, 68),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: tile(docs[0], 1, 96),
                ),
              ),
              if (docs.length > 2)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: tile(docs[2], 3, 60),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final int rank;
  const _Avatar({required this.username, required this.avatarUrl, required this.rank});

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      provider = avatarUrl!.startsWith('http')
          ? NetworkImage(avatarUrl!)
          : AssetImage(avatarUrl!) as ImageProvider;
    }
    final r = rank == 1 ? 28.0 : 24.0;
    if (provider != null) {
      return CircleAvatar(radius: r, backgroundImage: provider);
    }
    return CircleAvatar(
      radius: r,
      backgroundColor: const Color(0xFFE0E0E0),
      child: const Icon(Icons.person_outline, color: Colors.white),
    );
  }
}

// ====== OWN POSITION ======

class _OwnPositionChip extends StatelessWidget {
  const _OwnPositionChip();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalen', descending: true)
          .get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final users = snap.data!.docs;
        final idx = users.indexWhere((u) => u.id == uid);
        if (idx < 0) return const SizedBox.shrink();

        final data = users[idx].data() as Map<String, dynamic>;
        final pts = data['totalen'] ?? 0;
        return Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: const Color(0xFF2E7D32).withOpacity(0.25)),
            ),
            child: Text("📍 Jouw positie: #${idx + 1} — $pts pt"),
          ),
        );
      },
    );
  }
}

// ====== LINKS NAAR VOLLEDIGE RANKINGS ======

class _FullRankingLinks extends StatelessWidget {
  const _FullRankingLinks();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 760; // iets later naar 3-koloms

    final buttons = [
      _RankLink(
        icon: Icons.emoji_events,
        label: 'Volledige globale ranglijst',
        orderField: 'totalen',
        title: 'Globale ranglijst',
      ),
      _RankLink(
        icon: Icons.sports_soccer,
        label: 'Ranking Divisie A',
        orderField: 'punten_A',
        title: 'Ranglijst Divisie A',
      ),
      _RankLink(
        icon: Icons.sports_soccer,
        label: 'Ranking Divisie B',
        orderField: 'punten_B',
        title: 'Ranglijst Divisie B',
      ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            buttons[i],
            if (i != buttons.length - 1) const SizedBox(height: 8),
          ]
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: buttons[0]),
        const SizedBox(width: 8),
        Expanded(child: buttons[1]),
        const SizedBox(width: 8),
        Expanded(child: buttons[2]),
      ],
    );
  }
}

class _RankLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String orderField;
  final String title;

  const _RankLink({
    required this.icon,
    required this.label,
    required this.orderField,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        side: BorderSide(color: Colors.black.withOpacity(0.1)),
        foregroundColor: const Color(0xFF2E7D32),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _FullRankingScreen(title: title, orderField: orderField),
          ),
        );
      },
    );
  }
}

// ====== FULL RANKING SCREEN (met acties Profiel/Voorspellingen) ======

class _FullRankingScreen extends StatelessWidget {
  final String title;
  final String orderField; // 'totalen' | 'punten_A' | 'punten_B'
  const _FullRankingScreen({required this.title, required this.orderField});

  ImageProvider? _provider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('assets/')) return AssetImage(url);
    return null;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '??';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  void _showUserActions(BuildContext context, String userId, String contextType) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Bekijk profiel'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BekijkProfielScreen(userId: userId)),
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
      ),
    );
  }

  String _contextType() {
    if (orderField == 'punten_A') return 'A';
    if (orderField == 'punten_B') return 'B';
    return 'algemeen';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .orderBy(orderField, descending: true)
            .get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snap.data!.docs;
          final cType = _contextType();

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final doc = users[i];
              final data = doc.data() as Map<String, dynamic>;
              final username = data['username'] ?? 'Onbekend';
              final punten = data[orderField] ?? 0;
              final prov = _provider(data['avatarUrl']?.toString());

              return ListTile(
                onTap: () => _showUserActions(context, doc.id, cType),
                tileColor: doc.id == uid ? Colors.green[50] : null,
                leading: GestureDetector(
                  onTap: () => _showUserActions(context, doc.id, cType),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: prov,
                    child: prov == null
                        ? Text(
                            _initials(username),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
                title: Text(username),
                subtitle: Text('Punten: $punten'),
                trailing: Text('#${i + 1}'),
              );
            },
          );
        },
      ),
    );
  }
}
