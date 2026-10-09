import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:derde_divisie/core/widgets/ranking_app_bar.dart';
import 'package:derde_divisie/features/profiel/bekijk_profiel_screen.dart';
import 'package:derde_divisie/features/voorspellen/bekijk_voorspellingen_screen.dart';
import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';
import 'package:derde_divisie/features/voorspellen/ranking_repository.dart';
import 'package:derde_divisie/features/voorspellen/user_display_name.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, required this.type, this.pageLoader});
  final RankingType type;
  final Future<RankingPage> Function()? pageLoader;
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _repository = RankingRepository();
  final List<RankingEntry> _entries = [];
  RankingPage? _page;
  OwnRankingPosition? _own;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    _loadOwn();
  }

  Future<void> _loadOwn() async {
    if (widget.pageLoader != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final own = await _repository
          .ownPosition(widget.type, uid)
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _own = own);
    } catch (_) {
      /* Ranking remains usable if the supplementary own rank fails. */
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await (widget.pageLoader?.call() ??
              _repository.load(widget.type, after: _page?.cursor))
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() {
          _entries.addAll(page.entries);
          _page = page;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ranglijst kon niet worden geladen.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _actions(RankingEntry user) {
    showModalBottomSheet<void>(
        context: context,
        builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Bekijk profiel'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                BekijkProfielScreen(userId: user.id)));
                  }),
              ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('Bekijk voorspellingen'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => BekijkVoorspellingenScreen(
                                userId: user.id,
                                contextType: rankingContextType(widget.type))));
                  }),
            ]));
  }

  Widget _tile(RankingEntry user, int position) {
    final avatar = (user.data['avatarUrl'] ?? '').toString();
    ImageProvider? image;
    if (avatar.startsWith('http')) {
      image = NetworkImage(avatar);
    } else if (avatar.startsWith('assets/')) {
      image = AssetImage(avatar);
    }
    return ListTile(
        onTap: () => _actions(user),
        leading: CircleAvatar(
            backgroundImage: image,
            child: avatar.isEmpty ? const Icon(Icons.person) : null),
        title: Text(resolveUserDisplayName(user.data)),
        subtitle: Text('Punten: ${rankingScore(user.data, widget.type)}'),
        trailing: Text('#$position'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF3F6F1),
        appBar: RankingAppBar(
            context: context,
            title: rankingTitle(widget.type),
            fallbackRoute: predictionsRankingsRoute),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          if (_own != null && !_entries.any((e) => e.id == _own!.entry.id)) ...[
            const Text('Jouw positie',
                style: TextStyle(fontWeight: FontWeight.bold)),
            _tile(_own!.entry, _own!.position),
            const Divider(),
          ],
          for (var i = 0; i < _entries.length; i++) _tile(_entries[i], i + 1),
          if (!_loading && _error == null && _entries.isEmpty)
            const Center(child: Text('Nog geen deelnemers.')),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Opnieuw proberen'))
          ],
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _error == null && _page?.hasMore == true)
            TextButton(
                onPressed: _load, child: const Text('Meer deelnemers laden')),
        ]),
      );
}
