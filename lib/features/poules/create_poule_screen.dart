import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/models/poule_prediction_scope.dart';
import 'poule_detail_screen.dart';

class CreatePouleScreen extends StatefulWidget {
  const CreatePouleScreen({super.key});

  @override
  State<CreatePouleScreen> createState() => _CreatePouleScreenState();
}

class _CreatePouleScreenState extends State<CreatePouleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPublic = true;
  bool _loading = false;
  String _type = 'competition';
  SeasonTeam? _team;
  PoulePredictionScope _predictionScope = PoulePredictionScope.matches;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final name = _nameController.text.trim();
      final existing =
          await db.collection('poules').where('name', isEqualTo: name).get();
      if (existing.docs.isNotEmpty) {
        throw 'Deze poulenaam is al in gebruik.';
      }

      final id = const Uuid().v4();
      final pouleRef = db.collection('poules').doc(id);
      final batch = db.batch();
      batch.set(pouleRef, {
        'id': id,
        'name': name,
        'description': _descriptionController.text.trim(),
        'ownerId': user.uid,
        'isPublic': _isPublic,
        'password': _isPublic ? null : _passwordController.text.trim(),
        'type': _type,
        'competition': _type,
        'teamId': _type == 'team' ? _team?.id : null,
        'teamName': _type == 'team' ? _team?.listLabel : null,
        'division': _type == 'team' ? _team?.division : null,
        'seasonId': SeasonConfig.activeSeasonId,
        'predictionScope': _predictionScope.firestoreValue,
        'includeMatchPredictions':
            _predictionScope != PoulePredictionScope.finalRanking,
        'includeFinalStandingPredictions':
            _predictionScope != PoulePredictionScope.matches,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        pouleRef.collection('deelnemers').doc(user.uid),
        {
          'joinedAt': FieldValue.serverTimestamp(),
          'punten': 0,
          'rol': 'eigenaar',
          'voorspellingenZichtbaarVoorDeadline': false,
          'syncEnabled': true,
        },
      );
      batch.set(
        db.doc('users/${user.uid}/poules/$id'),
        {'joinedAt': FieldValue.serverTimestamp()},
      );
      batch.set(
        db.collection('users').doc(user.uid),
        {'gejoinedePoules': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      await batch.commit();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PouleDetailScreen(pouleId: id)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Poule aanmaken')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(constraints.maxWidth < 600 ? 14 : 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: AppCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Nieuwe poule',
                                style: AppTextStyles.pageTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const Text(
                                'Je centrale voorspellingen tellen automatisch mee. Er wordt geen aparte voorspelling voor deze poule opgeslagen.',
                                style: AppTextStyles.bodyMuted,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                    labelText: 'Poulenaam'),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Vul een poulenaam in.'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _descriptionController,
                                maxLength: 300,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Beschrijving (optioneel)',
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _type,
                                decoration: const InputDecoration(
                                    labelText: 'Pouletype'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'competition',
                                    child: Text('Hele competitie'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'team',
                                    child: Text('Eén team'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _type = value;
                                    if (value != 'team') _team = null;
                                  });
                                },
                              ),
                              if (_type == 'team') ...[
                                const SizedBox(height: 14),
                                DropdownButtonFormField<SeasonTeam>(
                                  value: _team,
                                  isExpanded: true,
                                  decoration:
                                      const InputDecoration(labelText: 'Team'),
                                  items: SeasonConfig.teamsInListOrder
                                      .map(
                                        (team) => DropdownMenuItem(
                                          value: team,
                                          child: Text(team.listLabel),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _team = value),
                                  validator: (value) =>
                                      _type == 'team' && value == null
                                          ? 'Kies een team.'
                                          : null,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              const Text(
                                'Wat telt mee?',
                                style: AppTextStyles.sectionTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              SegmentedButton<PoulePredictionScope>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: PoulePredictionScope.matches,
                                    icon: Icon(Icons.scoreboard_outlined),
                                    label: Text('Wedstrijden'),
                                  ),
                                  ButtonSegment(
                                    value: PoulePredictionScope.finalRanking,
                                    icon: Icon(Icons.format_list_numbered),
                                    label: Text('Eindstand'),
                                  ),
                                  ButtonSegment(
                                    value: PoulePredictionScope.both,
                                    icon: Icon(Icons.done_all),
                                    label: Text('Beide'),
                                  ),
                                ],
                                selected: {_predictionScope},
                                onSelectionChanged: (selection) {
                                  setState(
                                    () => _predictionScope = selection.first,
                                  );
                                },
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _predictionScope.explanation,
                                style: AppTextStyles.bodyMuted,
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Openbare poule'),
                                subtitle: const Text(
                                  'Iedereen kan deze poule vinden en deelnemen.',
                                ),
                                value: _isPublic,
                                onChanged: (value) =>
                                    setState(() => _isPublic = value),
                              ),
                              if (!_isPublic) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Wachtwoord'),
                                  validator: (value) => !_isPublic &&
                                          (value == null || value.isEmpty)
                                      ? 'Vul een wachtwoord in.'
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _save,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Poule aanmaken'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
