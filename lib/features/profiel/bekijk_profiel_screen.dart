import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BekijkProfielScreen extends StatefulWidget {
  final String userId;
  final Future<Map<String, dynamic>?> Function()? profileLoader;

  const BekijkProfielScreen(
      {super.key, required this.userId, this.profileLoader});

  @override
  State<BekijkProfielScreen> createState() => _BekijkProfielScreenState();
}

class _BekijkProfielScreenState extends State<BekijkProfielScreen> {
  String? avatarUrl;
  String? username;
  String? profielbeschrijving;
  String? woonplaats;
  String? favorieteCompetitie;
  String? favorieteClub;
  bool isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _laadProfiel();
  }

  Future<void> _laadProfiel() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await (widget.profileLoader?.call() ??
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .get()
                  .then((doc) => doc.data()))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (data == null) {
        _error = 'Dit profiel bestaat niet.';
      } else {
        avatarUrl = data['avatarUrl'];
        username = data['username'] ?? 'Gebruiker';
        profielbeschrijving = data['profileDescription'];
        woonplaats = data['woonplaats'];
        favorieteCompetitie = data['favorieteCompetitie'];
        favorieteClub = data['favorieteClub'];
      }
    } catch (_) {
      _error = 'Profiel kon niet worden geladen.';
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Profiel')),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!),
            TextButton(
                onPressed: _laadProfiel, child: const Text('Opnieuw proberen'))
          ])));
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(username ?? 'Profiel'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarUrl != null
                    ? (avatarUrl!.startsWith('assets/')
                        ? AssetImage(avatarUrl!) as ImageProvider
                        : NetworkImage(avatarUrl!))
                    : const AssetImage('assets/default_avatar.webp'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                username ?? 'Gebruiker',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            if (profielbeschrijving != null &&
                profielbeschrijving!.isNotEmpty) ...[
              const Text('Over mij',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(profielbeschrijving!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
            ],
            if (woonplaats != null && woonplaats!.isNotEmpty) ...[
              const Text('Woonplaats',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(woonplaats!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
            ],
            if (favorieteCompetitie != null &&
                favorieteCompetitie!.isNotEmpty) ...[
              const Text('Favoriete competitie',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(favorieteCompetitie!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
            ],
            if (favorieteClub != null && favorieteClub!.isNotEmpty) ...[
              const Text('Favoriete club',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(favorieteClub!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
