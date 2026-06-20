import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../utils/gemeenten.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Logger _logger = Logger('ProfileScreen');
  final user = FirebaseAuth.instance.currentUser!;
  late DocumentReference userDocRef;

  // User fields
  String? avatarUrl;
  String? username;
  String? profileDescription;
  String? woonplaats;
  String? favorieteCompetitie;
  String? favorieteClub;
  bool voorspellingenZichtbaar = true;
  bool _usernameChanged = false;

  bool isLoading = true;

  // Controllers / form
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _woonplaatsController = TextEditingController();
  String? _selectedCompetitie;
  String? _selectedClub;

  // Avatars/clubs
  final List<String> _avatarPaths = [
    'assets/images/default_logo.png',
    'assets/images/logo_ADO20.png',
    'assets/images/logo_ASWH.png',
    'assets/images/logo_BlauwGeel38JUMBO.png',
    'assets/images/logo_DOVO.png',
    'assets/images/logo_DVS33Ermelo.png',
    'assets/images/logo_Eemdijk.png',
    'assets/images/logo_Excelsior31.png',
    'assets/images/logo_FCLisse.png',
    'assets/images/logo_Gemert.png',
    'assets/images/logo_Goes.png',
    'assets/images/logo_GroeneSter.png',
    'assets/images/logo_HarkemaseBoys.png',
    'assets/images/logo_Hercules.png',
    'assets/images/logo_Hoogeveen.png',
    'assets/images/logo_HSC21.png',
    'assets/images/logo_Huizen.png',
    'assets/images/logo_Kloetinge.png',
    'assets/images/logo_Noordwijk.png',
    'assets/images/logo_RBC.png',
    'assets/images/logo_Rijnvogels.png',
    'assets/images/logo_RohdaRaalte.png',
    'assets/images/logo_SCGenemuiden.png',
    'assets/images/logo_Scherpenzeel.png',
    'assets/images/logo_Scheveningen.png',
    'assets/images/logo_SpartaNijkerk.png',
    'assets/images/logo_Sportlust46.png',
    'assets/images/logo_Staphorst.png',
    'assets/images/logo_SteDoCo.png',
    'assets/images/logo_svMeerssen.png',
    'assets/images/logo_TEC.png',
    'assets/images/logo_TOGB.png',
    'assets/images/logo_UDI19.png',
    'assets/images/logo_UNA.png',
    'assets/images/logo_Urk.png',
    'assets/images/logo_VVSB.png',
    'assets/images/logo_Zwaluwen.png',
    'assets/images/profiel_bal.png',
  ];

  final List<String> _clubs = [
    'Geen voorkeur',
    'ADO\'20', 'ASWH', 'Blauw Geel\'38', 'DOVO', 'DVS\'33 Ermelo', 'Eemdijk', 'Excelsior\'31',
    'FC Lisse', 'Gemert', 'Goes', 'Groene Ster', 'Harkemase Boys', 'Hercules', 'Hoogeveen',
    'HSC\'21', 'Huizen', 'Kloetinge', 'Noordwijk', 'RBC', 'Rijnvogels', 'Rohda Raalte',
    'SC Genemuiden', 'Scherpenzeel', 'Scheveningen', 'Sparta Nijkerk', 'Sportlust\'46',
    'Staphorst', 'SteDoCo', 'sv Meerssen', 'TEC', 'TOGB', 'UDI\'19', 'UNA', 'Urk', 'VVSB', 'Zwaluwen'
  ];

  String? _selectedAssetAvatar;

  // Precompute lowercase set for fast case-insensitive checks
  late final Set<String> _gemeentenLower =
      nederlandseGemeenten.map((g) => g.toLowerCase()).toSet();

  @override
  void initState() {
    super.initState();
    userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
    });
    _loadUserData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _woonplaatsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await userDocRef.get();
      final data = doc.data() as Map<String, dynamic>?;

      setState(() {
        avatarUrl = data?['avatarUrl'];
        username = data?['username'] ?? 'Gebruiker';
        profileDescription = data?['profileDescription'];
        woonplaats = data?['woonplaats'];
        favorieteCompetitie = data?['favorieteCompetitie'];
        favorieteClub = data?['favorieteClub'];
        voorspellingenZichtbaar = data?['voorspellingenZichtbaar'] ?? true;
        _usernameChanged = data?['usernameChanged'] ?? false;

        _descController.text = profileDescription ?? '';
        _woonplaatsController.text = woonplaats ?? '';
        _selectedCompetitie = favorieteCompetitie;
        _selectedClub = favorieteClub;

        if (avatarUrl != null && avatarUrl!.startsWith('assets/images/')) {
          _selectedAssetAvatar = avatarUrl;
        } else {
          _selectedAssetAvatar = null;
        }

        isLoading = false;
      });
    } catch (e, stack) {
      _logger.severe('Fout bij laden user data', e, stack);
    }
  }

  /// Vind de canonieke schrijfwijze van een gemeente (case-insensitive).
  /// Retourneert null als er geen match is.
  String? _canoniekeGemeente(String? input) {
    if (input == null) return null;
    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return null;
    // Snel checken of het in de set zit
    if (!_gemeentenLower.contains(lower)) return null;
    // Vind de eerste originele vorm die gelijk is (case-insensitive)
    return nederlandseGemeenten.firstWhere((g) => g.toLowerCase() == lower);
  }

  Future<void> _saveProfileData() async {
    if (!_formKey.currentState!.validate()) return;

    // Normaliseer woonplaats naar canonieke schrijfwijze
    final canoniek = _canoniekeGemeente(_woonplaatsController.text.trim());
    final woonplaatsToSave = (canoniek ?? _woonplaatsController.text.trim()).isEmpty
        ? null
        : (canoniek ?? _woonplaatsController.text.trim());

    await userDocRef.set({
      'avatarUrl': avatarUrl,
      'profileDescription': _descController.text.trim(),
      'woonplaats': woonplaatsToSave,
      'favorieteCompetitie': _selectedCompetitie,
      'favorieteClub': _selectedClub,
      'voorspellingenZichtbaar': voorspellingenZichtbaar,
      if (!_usernameChanged) 'username': username?.trim(),
      if (!_usernameChanged) 'usernameChanged': true,
    }, SetOptions(merge: true));

    if (!_usernameChanged) {
      setState(() {
        _usernameChanged = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profielgegevens opgeslagen')),
    );
  }

  void _showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _avatarPaths.length,
          itemBuilder: (context, index) {
            final path = _avatarPaths[index];
            final isSelected = path == _selectedAssetAvatar;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAssetAvatar = path;
                  avatarUrl = path;
                });
                Navigator.of(ctx).pop();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  border: isSelected ? Border.all(color: Colors.green, width: 3) : null,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundImage: AssetImage(path),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPasswordChangeDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wachtwoord wijzigen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Huidig wachtwoord'),
            ),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nieuw wachtwoord'),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Bevestig nieuw wachtwoord'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
          TextButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wachtwoorden komen niet overeen')),
                );
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentController.text,
                );
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wachtwoord gewijzigd')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fout bij wijzigen wachtwoord')),
                );
              }
            },
            child: const Text('Wijzigen'),
          )
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                GestureDetector(
                  onTap: _showAvatarSelection,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: avatarUrl != null && avatarUrl!.startsWith('assets/')
                            ? AssetImage(avatarUrl!)
                            : const AssetImage('assets/default_avatar.webp'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, size: 16),
                          SizedBox(width: 4),
                          Text('Tik om profielfoto te wijzigen'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Username (one-time editable)
                _usernameChanged
                    ? Text(
                        username ?? 'Gebruiker',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : TextFormField(
                        initialValue: username,
                        decoration: const InputDecoration(
                          labelText: 'Gebruikersnaam (éénmalig wijzigbaar)',
                          helperText: 'Je kunt deze gebruikersnaam later niet meer aanpassen.',
                        ),
                        onChanged: (val) => username = val,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Voer een gebruikersnaam in';
                          if (val.trim().length < 3) return 'Minimaal 3 tekens';
                          return null;
                        },
                      ),

                const SizedBox(height: 24),

                // Profielbeschrijving
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Profielbeschrijving'),
                ),

                const SizedBox(height: 16),

                // Woonplaats met Autocomplete + case-insensitive validatie
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final input = textEditingValue.text.trim().toLowerCase();
                    if (input.isEmpty) return const Iterable<String>.empty();
                    return nederlandseGemeenten.where(
                      (g) => g.toLowerCase().contains(input),
                    );
                  },
                  onSelected: (String selection) {
                    // Zet controller op canonieke waarde
                    _woonplaatsController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    // Sync met bestaande waarde
                    controller.text = _woonplaatsController.text;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      decoration: const InputDecoration(labelText: 'Woonplaats (gemeente)'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null; // Woonplaats is optioneel
                        final lower = value.trim().toLowerCase();
                        if (!_gemeentenLower.contains(lower)) {
                          return 'Voer een geldige Nederlandse gemeente in';
                        }
                        return null;
                      },
                      onChanged: (val) {
                        // Houd lokale controller in sync zodat _saveProfileData het juiste veld leest
                        _woonplaatsController.text = val;
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 600),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final opt = options.elementAt(index);
                              return ListTile(
                                title: Text(opt),
                                onTap: () => onSelected(opt),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Favoriete competitie
                DropdownButtonFormField<String>(
                  value: _selectedCompetitie,
                  decoration: const InputDecoration(labelText: 'Favoriete competitie'),
                  items: const [
                    DropdownMenuItem(value: 'Derde Divisie A', child: Text('Derde Divisie A')),
                    DropdownMenuItem(value: 'Derde Divisie B', child: Text('Derde Divisie B')),
                    DropdownMenuItem(value: 'Allebei', child: Text('Allebei')),
                    DropdownMenuItem(value: 'Geen voorkeur', child: Text('Geen voorkeur')),
                  ],
                  onChanged: (val) => setState(() => _selectedCompetitie = val),
                ),

                const SizedBox(height: 16),

                // Favoriete club
                DropdownButtonFormField<String>(
                  value: _selectedClub,
                  decoration: const InputDecoration(labelText: 'Favoriete club'),
                  items: _clubs.map((club) => DropdownMenuItem(value: club, child: Text(club))).toList(),
                  onChanged: (val) => setState(() => _selectedClub = val),
                ),

                const SizedBox(height: 24),

                // Zichtbaarheid
                SwitchListTile(
                  title: const Text('Voorspellingen zichtbaar voor anderen'),
                  value: voorspellingenZichtbaar,
                  onChanged: (val) => setState(() => voorspellingenZichtbaar = val),
                  activeColor: Colors.green,
                ),

                const SizedBox(height: 16),

                // Actieknoppen
                ElevatedButton(
                  onPressed: _saveProfileData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Opslaan'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _showPasswordChangeDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Wachtwoord wijzigen'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Afmelden'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
