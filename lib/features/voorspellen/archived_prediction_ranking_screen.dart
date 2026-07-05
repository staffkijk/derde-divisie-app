import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ArchivedPredictionRankingScreen extends StatefulWidget {
  const ArchivedPredictionRankingScreen({
    super.key,
    this.initialSeason = '2025-2026',
  });

  final String initialSeason;

  @override
  State<ArchivedPredictionRankingScreen> createState() =>
      _ArchivedPredictionRankingScreenState();
}

class _ArchivedPredictionRankingScreenState
    extends State<ArchivedPredictionRankingScreen> {
  static const Color _darkGreen = Color(0xFF153B2A);
  static const Color _cream = Color(0xFFF3F6F1);

  static const List<String> _seasons = [
    '2025-2026',
  ];

  late String _season;

  @override
  void initState() {
    super.initState();
    _season = _seasons.contains(widget.initialSeason)
        ? widget.initialSeason
        : _seasons.first;
  }

  CollectionReference<Map<String, dynamic>> get _rankingRef =>
      FirebaseFirestore.instance
          .collection('season_archives')
          .doc(_season)
          .collection('rankings')
          .doc('global')
          .collection('users');

  String _seasonLabel(String value) => value.replaceAll('-', '/');

  String _nameFrom(Map<String, dynamic> data) {
    final raw = data['username'] ??
        data['gebruikersnaam'] ??
        data['displayName'] ??
        data['name'] ??
        data['email'];

    final name = raw?.toString().trim();

    if (name == null || name.isEmpty) {
      return 'Onbekende speler';
    }

    return name;
  }

  int _pointsFrom(Map<String, dynamic> data) {
    final raw = data['totaalPunten'] ??
        data['totaalpunten'] ??
        data['totalPoints'] ??
        data['totalen'] ??
        data['punten'] ??
        data['points'];

    if (raw is num) return raw.toInt();

    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _rankFrom(Map<String, dynamic> data, int index) {
    final raw = data['rank'] ?? data['positie'] ?? data['position'];

    if (raw is num) return raw.toInt();

    return int.tryParse(raw?.toString() ?? '') ?? index + 1;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];

    sorted.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final rankA = aData['rank'];
      final rankB = bData['rank'];

      if (rankA is num && rankB is num) {
        return rankA.compareTo(rankB);
      }

      return _pointsFrom(bData).compareTo(_pointsFrom(aData));
    });

    return sorted;
  }

  int _highestScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return 0;

    var highest = 0;
    for (final doc in docs) {
      final points = _pointsFrom(doc.data());
      if (points > highest) highest = points;
    }

    return highest;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text('Voorspelranking archief'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 14,
              vertical: isDesktop ? 24 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _rankingRef.snapshots(),
                  builder: (context, snapshot) {
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting;

                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeaderCard(
                            season: _season,
                            seasonLabel: _seasonLabel(_season),
                            seasons: _seasons,
                            onSeasonChanged: (value) {
                              if (value != null) {
                                setState(() => _season = value);
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                          const _ArchiveEmptyState(
                            text:
                                'De gearchiveerde voorspellersranglijst kan nu niet worden geladen.',
                          ),
                        ],
                      );
                    }

                    final rawDocs = snapshot.data?.docs ?? [];
                    final docs = _sortDocs(rawDocs);
                    final topThree = docs.take(3).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderCard(
                          season: _season,
                          seasonLabel: _seasonLabel(_season),
                          seasons: _seasons,
                          onSeasonChanged: (value) {
                            if (value != null) {
                              setState(() => _season = value);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        if (isLoading)
                          const SizedBox(
                            height: 260,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (docs.isEmpty)
                          const _ArchiveEmptyState(
                            text:
                                'De gearchiveerde voorspellersranglijst van dit seizoen is nog niet beschikbaar.',
                          )
                        else ...[
                          _SummaryGrid(
                            playerCount: docs.length,
                            highestScore: _highestScore(docs),
                            seasonLabel: _seasonLabel(_season),
                          ),
                          const SizedBox(height: 18),
                          _PodiumSection(
                            docs: topThree,
                            nameFrom: _nameFrom,
                            pointsFrom: _pointsFrom,
                            rankFrom: _rankFrom,
                          ),
                          const SizedBox(height: 18),
                          _RankingCard(
                            seasonLabel: _seasonLabel(_season),
                            docs: docs,
                            nameFrom: _nameFrom,
                            pointsFrom: _pointsFrom,
                            rankFrom: _rankFrom,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.season,
    required this.seasonLabel,
    required this.seasons,
    required this.onSeasonChanged,
  });

  static const Color _darkGreen = Color(0xFF153B2A);
  static const Color _green = Color(0xFF2F8F3B);
  static const Color _softGreen = Color(0xFFE8F5E9);
  static const Color _border = Color(0xFFE3EADF);

  final String season;
  final String seasonLabel;
  final List<String> seasons;
  final ValueChanged<String?> onSeasonChanged;

  String _label(String value) => value.replaceAll('-', '/');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          final titleBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eindranglijst voorspellers',
                      style: TextStyle(
                        color: _darkGreen,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'De definitieve voorspelranking van afgelopen seizoen.',
                      style: TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final seasonPicker = SizedBox(
            width: isWide ? 230 : double.infinity,
            child: DropdownButtonFormField<String>(
              value: season,
              decoration: InputDecoration(
                labelText: 'Seizoen',
                filled: true,
                fillColor: const Color(0xFFF7FAF6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
              items: seasons
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_label(item)),
                    ),
                  )
                  .toList(),
              onChanged: onSeasonChanged,
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 18),
                seasonPicker,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: 18),
              seasonPicker,
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.playerCount,
    required this.highestScore,
    required this.seasonLabel,
  });

  final int playerCount;
  final int highestScore;
  final String seasonLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final itemWidth =
            isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _SummaryTile(
                icon: Icons.groups_2_rounded,
                label: 'Deelnemers',
                value: '$playerCount',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SummaryTile(
                icon: Icons.stars_rounded,
                label: 'Hoogste score',
                value: '$highestScore pt',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SummaryTile(
                icon: Icons.calendar_month_rounded,
                label: 'Seizoen',
                value: seasonLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  static const Color _darkGreen = Color(0xFF153B2A);
  static const Color _green = Color(0xFF2F8F3B);
  static const Color _softGreen = Color(0xFFE8F5E9);
  static const Color _border = Color(0xFFE3EADF);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _green),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({
    required this.docs,
    required this.nameFrom,
    required this.pointsFrom,
    required this.rankFrom,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String Function(Map<String, dynamic> data) nameFrom;
  final int Function(Map<String, dynamic> data) pointsFrom;
  final int Function(Map<String, dynamic> data, int index) rankFrom;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF153B2A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.white),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Podium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final width = isWide
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(docs.length, (index) {
                  final data = docs[index].data();

                  return SizedBox(
                    width: width,
                    child: _PodiumCard(
                      rank: rankFrom(data, index),
                      name: nameFrom(data),
                      points: pointsFrom(data),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.name,
    required this.points,
  });

  final int rank;
  final String name;
  final int points;

  IconData _iconForRank(int rank) {
    if (rank == 1) return Icons.emoji_events_rounded;
    return Icons.military_tech_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF153B2A),
            child: Icon(_iconForRank(rank), size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$points punten',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.seasonLabel,
    required this.docs,
    required this.nameFrom,
    required this.pointsFrom,
    required this.rankFrom,
  });

  static const Color _darkGreen = Color(0xFF153B2A);
  static const Color _green = Color(0xFF2F8F3B);
  static const Color _softGreen = Color(0xFFE8F5E9);
  static const Color _border = Color(0xFFE3EADF);

  final String seasonLabel;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String Function(Map<String, dynamic> data) nameFrom;
  final int Function(Map<String, dynamic> data) pointsFrom;
  final int Function(Map<String, dynamic> data, int index) rankFrom;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.leaderboard_rounded,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Volledige ranglijst $seasonLabel',
                    style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: const Color(0xFFF7FAF6),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: const Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Voorspeller',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    'Punten',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              return _RankingRow(
                rank: rankFrom(data, index),
                name: nameFrom(data),
                points: pointsFrom(data),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.name,
    required this.points,
  });

  static const Color _darkGreen = Color(0xFF153B2A);
  static const Color _softGreen = Color(0xFFE8F5E9);

  final int rank;
  final String name;
  final int points;

  IconData? _medalIcon() {
    if (rank == 1) return Icons.emoji_events_rounded;
    if (rank == 2 || rank == 3) return Icons.military_tech_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final medalIcon = _medalIcon();

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _softGreen,
                  foregroundColor: _darkGreen,
                  child: medalIcon == null
                      ? Text(
                          '$rank',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : Icon(medalIcon, size: 20),
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text(
                '$points pt',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState({required this.text});

  static const Color _border = Color(0xFFE3EADF);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2F8F3B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
