import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BekijkProfielScreen extends StatefulWidget {
  final String userId;

  const BekijkProfielScreen({super.key, required this.userId});

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

  @override
  void initState() {
    super.initState();
    _laadProfiel();
  }

  Future<void> _laadProfiel() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = doc.data();

      if (data != null) {
        setState(() {
          avatarUrl = data['avatarUrl'];
          username = data['username'] ?? 'Gebruiker';
          profielbeschrijving = data['profileDescription'];
          woonplaats = data['woonplaats'];
          favorieteCompetitie = data['favorieteCompetitie'];
          favorieteClub = data['favorieteClub'];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fout bij laden profiel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
