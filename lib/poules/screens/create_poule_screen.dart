import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/poule_model.dart';
import '../services/poule_service.dart';
import 'poule_detail_screen.dart';

// ⬇️ NIEUW: direct na aanmaken de backfill starten
import 'package:derde_divisie/helpers/sync_service.dart';

class CreatePouleScreen extends StatefulWidget {
  const CreatePouleScreen({super.key});

  @override
  State<CreatePouleScreen> createState() => _CreatePouleScreenState();
}

class _CreatePouleScreenState extends State<CreatePouleScreen> {
  final _formKey = GlobalKey<FormState>();
  final PouleService _pouleService = PouleService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPublic = true;
  String _selectedCompetition = 'dda'; // 'dda' | 'ddb' | 'team'
  String? _selectedTeam;
  bool _loading = false;

  final List<String> _teams = [
    'ADO20','ASWH','BlauwGeel38JUMBO','DOVO','DVS33Ermelo','Eemdijk','Excelsior31',
    'FCLisse','Gemert','Goes','GroeneSter','HarkemaseBoys','Hercules','Hoogeveen',
    'HSC21','Huizen','Kloetinge','Noordwijk','RBC','Rijnvogels','RohdaRaalte',
    'SCGenemuiden','Scherpenzeel','Scheveningen','SpartaNijkerk','Sportlust46',
    'Staphorst','SteDoCo','svMeerssen','TEC','TOGB','UDI19','UNA','Urk',
    'VVSB','Zwaluwen'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Normaliseert jouw dropdown-waarden naar velden die we later voor sync gebruiken.
  Map<String, String?> _competitionMapping(String sel) {
    switch (sel) {
      case 'dda':
        return {'type': 'DDA', 'competitionCode': '3A', 'teamCode': null};
      case 'ddb':
        return {'type': 'DDB', 'competitionCode': '3B', 'teamCode': null};
      case 'team':
      default:
        return {'type': 'ONE_TEAM', 'competitionCode': null, 'teamCode': _selectedTeam};
    }
  }

  Future<void> _savePoule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final isUnique = await _pouleService.checkUniqueName(name);
      if (!isUnique) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deze poule naam is al in gebruik')),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Je bent niet ingelogd')),
        );
        return;
      }
      final userId = user.uid;
      final id = const Uuid().v4();

      // Basispoule vanuit je model
      final poule = Poule(
        id: id,
        name: name,
        description: _descriptionController.text.trim(),
        ownerId: userId,
        isPublic: _isPublic,
        password: _isPublic ? null : _passwordController.text.trim(),
        competition: _selectedCompetition, // 'dda' | 'ddb' | 'team'
        imageUrl: null,
        createdAt: DateTime.now(),
      );
      final pouleData = poule.toMap();

      // Extra velden voor sync-mechaniek
      final norm = _competitionMapping(_selectedCompetition);
      pouleData['type'] = norm['type'];                       // 'DDA' | 'DDB' | 'ONE_TEAM'
      pouleData['competitionCode'] = norm['competitionCode']; // '3A' | '3B' | null
      if (norm['type'] == 'ONE_TEAM') {
        pouleData['teamCode'] = norm['teamCode'];             // bv. 'DOVO'
      }

      // Validatie team bij 'ONE_TEAM'
      if (pouleData['type'] == 'ONE_TEAM' &&
          (pouleData['teamCode'] == null || (pouleData['teamCode'] as String).isEmpty)) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecteer een team voor een “Eén team”-poule.')),
        );
        return;
      }

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1) Poule opslaan
      final pouleRef = db.collection('poules').doc(id);
      batch.set(pouleRef, {
        ...pouleData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) Deelnemer (owner) toevoegen met sync-velden in deelnemers/
      final deelnemersRef = pouleRef.collection('deelnemers').doc(userId);
      batch.set(deelnemersRef, {
        'joinedAt': FieldValue.serverTimestamp(),
        'punten': 0,
        'rol': 'eigenaar',
        'voorspellingenZichtbaarVoorDeadline': false,
        // ✨ sync direct aan
        'syncEnabled': true,
        'syncStartAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Index bij user (voor snelle lookup)
      final indexRef = db.doc('users/$userId/poules/$id');
      batch.set(indexRef, {
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4) Teller ophogen
      final userRef = db.collection('users').doc(userId);
      batch.update(userRef, {
        'gejoinedePoules': FieldValue.increment(1),
      });

      // Schrijf alles weg
      await batch.commit();

      // ⬇️⬇️ NIEUW: meteen backfillen zodat voorspellingen direct zichtbaar zijn
      try {
        await SyncService.instance.enableSyncForUserInPool(
          poolId: id,
          userId: userId,
        );
      } catch (e) {
        // Niet fataal — we navigeren alsnog; je kunt dit loggen of tonen.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Synchronisatie starten mislukt: $e')),
          );
        }
      }

      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PouleDetailScreen(pouleId: id)),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Er ging iets mis bij aanmaken: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poule aanmaken'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _savePoule,
            child: const Text('Opslaan'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Poule naam'),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'Bijv. De buurtjes'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Verplicht' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Beschrijving'),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 300,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Bijv. vrienden uit de straat'),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Poule is openbaar'),
                      subtitle: const Text('Uit = alleen deelnemers via wachtwoord'),
                      value: _isPublic,
                      onChanged: (val) => setState(() => _isPublic = val),
                    ),
                    if (!_isPublic)
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Wachtwoord'),
                        obscureText: true,
                        validator: (value) {
                          if (!_isPublic && (value == null || value.isEmpty)) {
                            return 'Wachtwoord is verplicht';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    const Text('Competitie'),
                    DropdownButtonFormField<String>(
                      value: _selectedCompetition,
                      items: const [
                        DropdownMenuItem(value: 'dda', child: Text('Derde Divisie A')),
                        DropdownMenuItem(value: 'ddb', child: Text('Derde Divisie B')),
                        DropdownMenuItem(value: 'team', child: Text('Eén team')),
                      ],
                      onChanged: (val) => setState(() => _selectedCompetition = val!),
                    ),
                    if (_selectedCompetition == 'team') ...[
                      const SizedBox(height: 16),
                      const Text('Selecteer team'),
                      DropdownButtonFormField<String>(
                        value: _selectedTeam,
                        items: _teams
                            .map((team) => DropdownMenuItem(value: team, child: Text(team)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedTeam = val!),
                        validator: (value) {
                          if (_selectedCompetition == 'team' && (value == null || value.isEmpty)) {
                            return 'Selecteer een team';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
