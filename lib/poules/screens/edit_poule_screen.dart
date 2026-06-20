import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditPouleScreen extends StatefulWidget {
  final String pouleId;
  const EditPouleScreen({super.key, required this.pouleId});

  @override
  State<EditPouleScreen> createState() => _EditPouleScreenState();
}

class _EditPouleScreenState extends State<EditPouleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _ownerId;
  String _name = '';
  String _competition = 'dda';
  String? _selectedTeam;

  bool _isPublic = true; // default; wordt overschreven bij load
  bool _initialIsPublic = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('poules')
          .doc(widget.pouleId)
          .get();

      if (!snap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Poule niet gevonden')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = snap.data()!;
      _ownerId = data['ownerId'] as String?;
      _name = (data['name'] ?? '') as String;
      _competition = (data['competition'] ?? 'dda') as String;
      _selectedTeam = data['selectedTeam'] as String?;
      _isPublic = (data['isPublic'] ?? true) as bool;
      _initialIsPublic = _isPublic;

      _descriptionController.text = (data['description'] ?? '') as String;
      // wachtwoord nooit vooraf invullen (veiligheid)

      // Alleen eigenaar mag bewerken
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || currentUserId != _ownerId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alleen de eigenaar kan deze poule wijzigen.')),
          );
          Navigator.of(context).pop();
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij laden: $e')),
        );
        Navigator.of(context).pop();
      }
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'description': _descriptionController.text.trim(),
        'isPublic': _isPublic,
        'updatedAt': DateTime.now(),
      };

      // Wachtwoordregels:
      // - als privé -> openbaar: wachtwoord wissen
      // - als openbaar -> privé: wachtwoord verplicht (validator)
      // - als privé blijft privé en gebruiker vult een nieuw wachtwoord in → update
      if (_isPublic) {
        updates['password'] = null;
      } else {
        final newPw = _passwordController.text.trim();
        if (newPw.isNotEmpty) {
          updates['password'] = newPw;
        } else if (_initialIsPublic && !_isPublic) {
          // net van public -> private gegaan zonder pw: validator zou dit al moeten tegenhouden
          // fallback safeguard
          throw 'Vul een wachtwoord in voor een privé-poule.';
        }
      }

      await FirebaseFirestore.instance
          .collection('poules')
          .doc(widget.pouleId)
          .update(updates);

      if (mounted) {
        Navigator.of(context).pop(true); // true => wijzigingen doorgevoerd
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
  appBar: AppBar(title: const Text('Poule bewerken')),
  body: const Center(child: CircularProgressIndicator()),
);

    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poule bewerken'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Opslaan'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Niet wijzigbaar: naam en competitie
                Text('Poule', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  _competition == 'team'
                      ? 'Eén team: ${_selectedTeam ?? '-'}'
                      : (_competition == 'dda' ? 'Derde Divisie A' : 'Derde Divisie B'),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),

                const Text('Beschrijving'),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Bijv. vrienden uit de straat',
                  ),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Poule is openbaar'),
                  subtitle: const Text('Uit = alleen met wachtwoord te joinen'),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),

                if (!_isPublic) ...[
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Wachtwoord (nieuw of laat leeg om huidig te behouden)'),
                    obscureText: true,
                    validator: (value) {
                      // Als we van public -> private gaan én er was nog geen wachtwoord, dan verplichten
                      if (_initialIsPublic && !_isPublic) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Wachtwoord is verplicht voor een privé-poule';
                        }
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),
                if (_saving) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
