import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class JoinGeslotenPouleScreen extends StatefulWidget {
  const JoinGeslotenPouleScreen({super.key});

  @override
  State<JoinGeslotenPouleScreen> createState() => _JoinGeslotenPouleScreenState();
}

class _JoinGeslotenPouleScreenState extends State<JoinGeslotenPouleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pouleNaamController = TextEditingController();
  final TextEditingController _wachtwoordController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = false;
  String _error = '';
  bool _voorspellingenZichtbaar = true;

  @override
  void dispose() {
    _pouleNaamController.dispose();
    _wachtwoordController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Je bent niet ingelogd.';
        _loading = false;
      });
      return;
    }
    final userId = user.uid;
    final naam = _pouleNaamController.text.trim();
    final wachtwoord = _wachtwoordController.text.trim();

    try {
      // 1) Zoek gesloten poule op naam
      final query = await _firestore
          .collection('poules')
          .where('name', isEqualTo: naam)
          .where('isPublic', isEqualTo: false)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _error = 'Poule niet gevonden of is niet gesloten.';
          _loading = false;
        });
        return;
      }

      final pouleDoc = query.docs.first;
      final pouleId = pouleDoc.id;
      final data = pouleDoc.data();

      // 2) Wachtwoord check
      if ((data['password'] ?? '') != wachtwoord) {
        setState(() {
          _error = 'Wachtwoord is onjuist.';
          _loading = false;
        });
        return;
      }

      // 3) Ben je al lid? (check in subcollectie 'deelnemers')
      final deelnemerSnap = await _firestore
          .collection('poules')
          .doc(pouleId)
          .collection('deelnemers')
          .doc(userId)
          .get();
      if (deelnemerSnap.exists) {
        setState(() {
          _error = 'Je zit al in deze poule.';
          _loading = false;
        });
        return;
      }

      // 4) Max 10 poules check
      final userRef = _firestore.collection('users').doc(userId);
      final userSnap = await userRef.get();
      final currentJoinCount = (userSnap.data()?['gejoinedePoules'] ?? 0) as int;
      if (currentJoinCount >= 10) {
        setState(() {
          _error = 'Je kunt maximaal 10 poules joinen.';
          _loading = false;
        });
        return;
      }

      // 5) Alles in één batch:
      //    - deelnemers doc (incl. syncEnabled + syncStartAt indien enabled)
      //    - users/{uid}/poules/{pouleId} index
      //    - gejoinedePoules teller +1
      final batch = _firestore.batch();

      // deelnemers (met sync velden direct in deelnemers/)
      final deelnemersRef = _firestore
          .collection('poules')
          .doc(pouleId)
          .collection('deelnemers')
          .doc(userId);

      // sync staat standaard AAN bij joinen; wil je uit bij joinen, zet syncEnabled hier op false
      const bool syncEnabled = true;

      batch.set(deelnemersRef, {
        'rol': 'deelnemer',
        'joinedAt': FieldValue.serverTimestamp(),
        'punten': 0,
        'voorspellingenZichtbaarVoorDeadline': _voorspellingenZichtbaar,
        'syncEnabled': syncEnabled,
        if (syncEnabled) 'syncStartAt': FieldValue.serverTimestamp(), // "alleen vooruit" vanaf nu
      }, SetOptions(merge: true));

      // users/{uid}/poules/{pouleId} index
      final indexRef = _firestore.doc('users/$userId/poules/$pouleId');
      batch.set(indexRef, {
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // teller ophogen
      batch.update(userRef, {
        'gejoinedePoules': FieldValue.increment(1),
      });

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je bent toegevoegd aan de poule')),
      );
    } catch (e) {
      setState(() {
        _error = 'Er ging iets mis. Probeer opnieuw.';
        _loading = false;
      });
      return;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gesloten poule joinen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pouleNaamController,
                decoration: const InputDecoration(labelText: 'Poule naam'),
                validator: (val) => val == null || val.isEmpty ? 'Verplicht' : null,
              ),
              TextFormField(
                controller: _wachtwoordController,
                decoration: const InputDecoration(labelText: 'Wachtwoord'),
                obscureText: true,
                validator: (val) => val == null || val.isEmpty ? 'Verplicht' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Switch(
                    value: _voorspellingenZichtbaar,
                    onChanged: (val) {
                      setState(() {
                        _voorspellingenZichtbaar = val;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Mijn voorspellingen in deze poule mogen zichtbaar zijn voor anderen.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _join,
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Join poule'),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
