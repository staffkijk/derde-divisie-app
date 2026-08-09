import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/data/services/analytics_service.dart';
import 'join_gesloten_poule_screen.dart';

class ZoekPouleScreen extends StatefulWidget {
  const ZoekPouleScreen({super.key});

  @override
  State<ZoekPouleScreen> createState() => _ZoekPouleScreenState();
}

class _ZoekPouleScreenState extends State<ZoekPouleScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late String _userId;
  int _aantalGejoinedePoules = 0;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      setState(() {
        _aantalGejoinedePoules =
            (userDoc.data()?['gejoinedePoules'] ?? 0) as int;
      });
    } catch (_) {
      // negeren; laat 0 staan
    }
  }

  /// Helper: rond joinen altijd op dezelfde manier af.
  /// Schrijft:
  /// - poules/{pouleId}/deelnemers/{uid} (incl. syncEnabled + syncStartAt indien enabled)
  /// - users/{uid}/poules/{pouleId} (index)
  /// - users.{gejoinedePoules} += 1
  Future<void> finalizeJoinPoule({
    required String pouleId,
    String rol = 'deelnemer',
    bool voorspellingenZichtbaarVoorDeadline = false,
    bool syncEnabled = true, // ⬅️ standaard AAN, kan je ook false meegeven
  }) async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userRef = db.collection('users').doc(uid);
    final pouleRef = db.collection('poules').doc(pouleId);
    final deelnemerRef = pouleRef.collection('deelnemers').doc(uid);
    final indexRef = db.doc('users/$uid/poules/$pouleId');

    final batch = db.batch();

    // Basispayload voor deelnemers-doc
    final deelnemerPayload = <String, dynamic>{
      'joinedAt': FieldValue.serverTimestamp(),
      'punten': 0,
      'rol': rol,
      'voorspellingenZichtbaarVoorDeadline':
          voorspellingenZichtbaarVoorDeadline,
      'syncEnabled': syncEnabled,
      // syncStartAt alleen zetten als syncEnabled true is (alleen vooruit vanaf nú)
      if (syncEnabled) 'syncStartAt': FieldValue.serverTimestamp(),
    };

    batch.set(deelnemerRef, deelnemerPayload, SetOptions(merge: true));

    // Index bij de user
    batch.set(
      indexRef,
      {'joinedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    // Teller bij user
    batch.update(userRef, {'gejoinedePoules': FieldValue.increment(1)});

    await batch.commit();
  }

  Future<void> _joinPoule(DocumentSnapshot pouleDoc) async {
    if (_aantalGejoinedePoules >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je kunt maximaal 10 poules joinen.')),
      );
      return;
    }

    final pouleId = pouleDoc.id;

    try {
      // niet dubbel joinen
      final deelnemerSnap = await _firestore
          .collection('poules')
          .doc(pouleId)
          .collection('deelnemers')
          .doc(_userId)
          .get();

      if (deelnemerSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Je zit al in deze poule.')),
        );
        return;
      }

      // ✅ Join met syncEnabled = true (standaard). Wil je uitzetten bij join? zet syncEnabled: false.
      await finalizeJoinPoule(
        pouleId: pouleId,
        rol: 'deelnemer',
        voorspellingenZichtbaarVoorDeadline: false,
        syncEnabled: true, // ← pas desnoods aan naar false
      );

      await AnalyticsService.instance.trackPouleJoined(
        source: 'poule_search',
        public: true,
      );

      if (!mounted) return;
      setState(() {
        _aantalGejoinedePoules += 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je bent toegevoegd aan de poule.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joinen mislukt: $e')),
      );
    }
  }

  Future<List<DocumentSnapshot>> _getOpenbareNietGejoindePoules() async {
    final snapshot = await _firestore
        .collection('poules')
        .where('isPublic', isEqualTo: true)
        .get();

    final List<DocumentSnapshot> results = [];

    for (final doc in snapshot.docs) {
      final deelnemerDoc =
          await doc.reference.collection('deelnemers').doc(_userId).get();
      if (!deelnemerDoc.exists) {
        results.add(doc);
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zoek openbare poules')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _getOpenbareNietGejoindePoules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final poules = snapshot.data ?? [];

                if (poules.isEmpty) {
                  return const Center(
                    child: Text('Geen openbare poules beschikbaar'),
                  );
                }

                return ListView.builder(
                  itemCount: poules.length,
                  itemBuilder: (context, index) {
                    final poule = poules[index];
                    final data = poule.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['name'] ?? 'Naamloos'),
                      subtitle: Text(data['description'] ?? ''),
                      trailing: ElevatedButton(
                        onPressed: () => _joinPoule(poule),
                        child: const Text('Join'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const JoinGeslotenPouleScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Gesloten poule joinen'),
            ),
          ),
        ],
      ),
    );
  }
}
