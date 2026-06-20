import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_poule_screen.dart';
import 'zoek_poule_screen.dart';
import 'poule_detail_screen.dart';

class PoulesOverzichtScreen extends StatefulWidget {
  const PoulesOverzichtScreen({super.key});

  @override
  State<PoulesOverzichtScreen> createState() => _PoulesOverzichtScreenState();
}

class _PoulesOverzichtScreenState extends State<PoulesOverzichtScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  List<DocumentSnapshot> joinedPoules = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchJoinedPoules();
  }

  Future<void> _fetchJoinedPoules() async {
    final snapshot = await FirebaseFirestore.instance.collection('poules').get();
    final allPoules = snapshot.docs;

    final List<DocumentSnapshot> results = [];

    for (final doc in allPoules) {
      final deelnemerSnap = await doc.reference.collection('deelnemers').doc(userId).get();
      if (deelnemerSnap.exists) {
        results.add(doc);
      }
    }

    setState(() {
      joinedPoules = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Poules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Zoek poule',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ZoekPouleScreen()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : joinedPoules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Je zit nog niet in een poule."),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreatePouleScreen(),
                            ),
                          );
                        },
                        child: const Text("Maak poule aan"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: joinedPoules.length,
                  itemBuilder: (context, index) {
                    final poule = joinedPoules[index];
                    final data = poule.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['name']),
                      subtitle: Text(data['description'] ?? ''),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PouleDetailScreen(pouleId: poule.id),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreatePouleScreen(),
            ),
          );
        },
        tooltip: 'Nieuwe poule aanmaken',
        child: const Icon(Icons.add),
      ),
    );
  }
}
