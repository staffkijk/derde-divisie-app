import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/core/utils/gemeenten.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Logger _logger = Logger('ProfileScreen');
  final _formKey = GlobalKey<FormState>();

  final User user = FirebaseAuth.instance.currentUser!;
  late final DocumentReference<Map<String, dynamic>> userDocRef;

  final _descController = TextEditingController();
  final _woonplaatsController = TextEditingController();

  String? avatarUrl;
  String? username;
  String? profileDescription;
  String? woonplaats;
  String? favorieteCompetitie;
  String? favorieteClub;

  String? _selectedCompetitie;
  String? _selectedClub;
  String? _selectedAssetAvatar;

  bool voorspellingenZichtbaar = true;
  bool allowEmailSharingWithPouleOwner = false;
  bool _usernameChanged = false;
  bool isLoading = true;
  bool isSaving = false;

  static const Color _darkGreen = Color(0xFF0F3D2A);
  static const Color _green = Color(0xFF49B653);
  static const Color _softGreen = Color(0xFFF4F8F2);
  static const Color _borderGreen = Color(0xFFD8E6D4);
  static const Color _textDark = Color(0xFF183326);
  static const Color _textMuted = Color(0xFF6B756D);

  List<String> get _clubs => [
        'Geen voorkeur',
        ...SeasonConfig.teams.map((team) => team.label),
      ];

  List<String> get _avatarPaths => [
        'assets/images/default_logo.png',
        'assets/images/profiel_bal.png',
        ...SeasonConfig.teams.map((team) => team.logoPath),
      ];

  late final Set<String> _gemeentenLower =
      nederlandseGemeenten.map((g) => g.toLowerCase()).toSet();

  @override
  void initState() {
    super.initState();

    userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
      );
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
      final data = doc.data();

      if (!mounted) return;

      final loadedClub = data?['favorieteClub'] as String?;
      final normalizedClub = _validClubValue(loadedClub);

      setState(() {
        avatarUrl = data?['avatarUrl'] as String?;
        username = data?['username'] as String? ?? 'Gebruiker';
        profileDescription = data?['profileDescription'] as String?;
        woonplaats = data?['woonplaats'] as String?;
        favorieteCompetitie = data?['favorieteCompetitie'] as String?;
        favorieteClub = normalizedClub;
        voorspellingenZichtbaar =
            data?['voorspellingenZichtbaar'] as bool? ?? true;
        allowEmailSharingWithPouleOwner =
            data?['allowEmailSharingWithPouleOwner'] as bool? ?? false;
        _usernameChanged = data?['usernameChanged'] as bool? ?? false;

        _descController.text = profileDescription ?? '';
        _woonplaatsController.text = woonplaats ?? '';

        _selectedCompetitie = _validCompetitieValue(favorieteCompetitie);
        _selectedClub = normalizedClub;

        if (avatarUrl != null && avatarUrl!.startsWith('assets/')) {
          _selectedAssetAvatar = avatarUrl;
        } else {
          _selectedAssetAvatar = null;
        }

        isLoading = false;
      });
    } catch (e, stack) {
      _logger.severe('Fout bij laden user data', e, stack);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profielgegevens konden niet worden geladen'),
        ),
      );
    }
  }

  String? _validCompetitieValue(String? value) {
    const values = [
      SeasonConfig.divisionAName,
      SeasonConfig.divisionBName,
      'Allebei',
      'Geen voorkeur',
    ];

    if (value == null || !values.contains(value)) return null;
    return value;
  }

  String? _validClubValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    if (value == 'Geen voorkeur') {
      return value;
    }

    final team = SeasonConfig.teamByName(value);
    return team?.label;
  }

  String? _canoniekeGemeente(String? input) {
    if (input == null) return null;

    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return null;
    if (!_gemeentenLower.contains(lower)) return null;

    return nederlandseGemeenten.firstWhere(
      (g) => g.toLowerCase() == lower,
    );
  }

  ImageProvider _avatarImageProvider() {
    final path = avatarUrl;

    if (path != null && path.startsWith('assets/')) {
      return AssetImage(path);
    }

    if (_selectedClub != null && _selectedClub != 'Geen voorkeur') {
      return AssetImage(SeasonConfig.logoPathForTeam(_selectedClub!));
    }

    return const AssetImage('assets/images/default_logo.png');
  }

  Future<void> _saveProfileData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final favoriteChanged = favorieteClub != _selectedClub;
      final canoniek = _canoniekeGemeente(_woonplaatsController.text.trim());
      final rawWoonplaats = _woonplaatsController.text.trim();

      final woonplaatsToSave =
          rawWoonplaats.isEmpty ? null : canoniek ?? rawWoonplaats;
      final selectedTeam =
          _selectedClub == null || _selectedClub == 'Geen voorkeur'
              ? null
              : SeasonConfig.teamByName(_selectedClub!);

      await userDocRef.set({
        'avatarUrl': avatarUrl,
        'profileDescription': _descController.text.trim(),
        'woonplaats': woonplaatsToSave,
        'favorieteCompetitie': _selectedCompetitie,
        'favorieteClub': _selectedClub,
        'favoriteTeamSlug': selectedTeam?.id ?? FieldValue.delete(),
        'favoriteTeamName': selectedTeam?.label ?? FieldValue.delete(),
        'favoriteDivision': selectedTeam?.division ?? FieldValue.delete(),
        'voorspellingenZichtbaar': voorspellingenZichtbaar,
        'allowEmailSharingWithPouleOwner': allowEmailSharingWithPouleOwner,
        'emailSharingConsentAt': allowEmailSharingWithPouleOwner
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
        if (!_usernameChanged) 'username': username?.trim(),
        if (!_usernameChanged) 'usernameChanged': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (favoriteChanged) {
        await ActivityLogService().log(
          eventType: ActivityEventType.favoriteTeamChanged,
          entityType: 'team',
          entityId: selectedTeam?.id,
        );
      }

      if (!mounted) return;

      setState(() {
        if (!_usernameChanged) {
          _usernameChanged = true;
        }

        woonplaats = woonplaatsToSave;
        favorieteCompetitie = _selectedCompetitie;
        favorieteClub = _selectedClub;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profielgegevens opgeslagen')),
      );
    } catch (e, stack) {
      _logger.severe('Fout bij opslaan profiel', e, stack);

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profielgegevens konden niet worden opgeslagen'),
        ),
      );
    }
  }

  void _showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kies profielfoto',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatarPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final path = _avatarPaths[index];
                      final isSelected = path == _selectedAssetAvatar;

                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() {
                            _selectedAssetAvatar = path;
                            avatarUrl = path;
                          });

                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          width: 94,
                          height: 94,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? _green : _borderGreen,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: _softGreen,
                            backgroundImage: AssetImage(path),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPasswordChangeDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Wachtwoord wijzigen'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: true,
                      decoration: _inputDecoration('Huidig wachtwoord'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      decoration: _inputDecoration('Nieuw wachtwoord'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: _inputDecoration('Bevestig nieuw wachtwoord'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (newController.text.trim().length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gebruik minimaal 6 tekens'),
                              ),
                            );
                            return;
                          }

                          if (newController.text != confirmController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Wachtwoorden komen niet overeen'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            final email = user.email;

                            if (email == null) {
                              throw FirebaseAuthException(
                                code: 'missing-email',
                                message: 'Geen e-mailadres gevonden',
                              );
                            }

                            final cred = EmailAuthProvider.credential(
                              email: email,
                              password: currentController.text,
                            );

                            await user.reauthenticateWithCredential(cred);
                            await user.updatePassword(newController.text);

                            if (!context.mounted) return;

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wachtwoord gewijzigd'),
                              ),
                            );
                          } catch (e, stack) {
                            _logger.warning(
                              'Fout bij wijzigen wachtwoord',
                              e,
                              stack,
                            );

                            if (!context.mounted) return;

                            setDialogState(() {
                              isSubmitting = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fout bij wijzigen wachtwoord'),
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Wijzigen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Afmelden'),
          content: const Text('Weet je zeker dat je wilt afmelden?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Afmelden'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _signOut();
    }
  }

  static InputDecoration _inputDecoration(
    String label, {
    String? helperText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderGreen),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderGreen),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _green, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: _softGreen,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: isWide ? 28 : 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isWide),
                        const SizedBox(height: 24),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildProfileSummaryCard(),
                                    const SizedBox(height: 18),
                                    _buildProfileFormCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                flex: 4,
                                child: _buildSettingsCard(),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildProfileSummaryCard(),
                              const SizedBox(height: 16),
                              _buildSettingsCard(),
                              const SizedBox(height: 16),
                              _buildProfileFormCard(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profiel',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Beheer je profiel, voorkeuren en accountinstellingen.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: isWide ? 15 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isWide)
          OutlinedButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Uitloggen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _darkGreen,
              side: const BorderSide(color: _borderGreen),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileSummaryCard() {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _showAvatarSelection,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _borderGreen),
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: _softGreen,
                        backgroundImage: _avatarImageProvider(),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username?.trim().isNotEmpty == true
                          ? username!.trim()
                          : 'Gebruiker',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.email ?? 'Geen e-mailadres bekend',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: woonplaats?.isNotEmpty == true
                    ? woonplaats!
                    : 'Geen woonplaats',
              ),
              _InfoChip(
                icon: Icons.emoji_events_outlined,
                label: _selectedCompetitie ?? 'Geen competitie',
              ),
              _InfoChip(
                icon: Icons.shield_outlined,
                label: _selectedClub ?? 'Geen club',
              ),
            ],
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _showAvatarSelection,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Profielfoto wijzigen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _darkGreen,
              side: const BorderSide(color: _borderGreen),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFormCard() {
    return _ProfileCard(
      title: 'Profielgegevens',
      subtitle: 'Pas je openbare profiel en voorkeuren aan.',
      child: Column(
        children: [
          if (_usernameChanged)
            _LockedUsername(username: username ?? 'Gebruiker')
          else
            TextFormField(
              initialValue: username,
              decoration: _inputDecoration(
                'Gebruikersnaam',
                helperText:
                    'Je kunt deze gebruikersnaam later niet meer aanpassen.',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              onChanged: (val) => username = val,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Voer een gebruikersnaam in';
                }

                if (val.trim().length < 3) {
                  return 'Minimaal 3 tekens';
                }

                return null;
              },
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration(
              'Profielbeschrijving',
              hintText: 'Vertel kort iets over jezelf',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          _buildWoonplaatsAutocomplete(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCompetitie,
            isExpanded: true,
            decoration: _inputDecoration(
              'Favoriete competitie',
              prefixIcon: const Icon(Icons.leaderboard_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: SeasonConfig.divisionAName,
                child: Text(SeasonConfig.divisionAName),
              ),
              DropdownMenuItem(
                value: SeasonConfig.divisionBName,
                child: Text(SeasonConfig.divisionBName),
              ),
              DropdownMenuItem(
                value: 'Allebei',
                child: Text('Allebei'),
              ),
              DropdownMenuItem(
                value: 'Geen voorkeur',
                child: Text('Geen voorkeur'),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _selectedCompetitie = val;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedClub,
            isExpanded: true,
            decoration: _inputDecoration(
              'Favoriete club',
              prefixIcon: const Icon(Icons.shield_outlined),
            ),
            items: _clubs.map((club) {
              return DropdownMenuItem(
                value: club,
                child: Text(club),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedClub = val;
              });
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving ? null : _saveProfileData,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(isSaving ? 'Opslaan...' : 'Opslaan'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoonplaatsAutocomplete() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _woonplaatsController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final input = textEditingValue.text.trim().toLowerCase();

        if (input.isEmpty) {
          return const Iterable<String>.empty();
        }

        return nederlandseGemeenten.where(
          (g) => g.toLowerCase().contains(input),
        );
      },
      onSelected: (String selection) {
        _woonplaatsController.text = selection;
      },
      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onEditingComplete,
      ) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: _inputDecoration(
            'Woonplaats',
            helperText: 'Gebruik de officiële gemeentenaam.',
            prefixIcon: const Icon(Icons.location_city_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;

            final lower = value.trim().toLowerCase();

            if (!_gemeentenLower.contains(lower)) {
              return 'Voer een geldige Nederlandse gemeente in';
            }

            return null;
          },
          onChanged: (val) {
            _woonplaatsController.text = val;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 260,
                maxWidth: 520,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final opt = options.elementAt(index);

                  return ListTile(
                    dense: true,
                    title: Text(opt),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsCard() {
    return _ProfileCard(
      title: 'Accountinstellingen',
      subtitle: 'Beheer privacy, wachtwoord en sessie.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderGreen),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderGreen),
                  ),
                  child: const Icon(
                    Icons.visibility_outlined,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voorspellingen zichtbaar',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Anderen mogen jouw voorspellingen bekijken.',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: voorspellingenZichtbaar,
                  activeColor: _green,
                  onChanged: (val) {
                    setState(() {
                      voorspellingenZichtbaar = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderGreen),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: _darkGreen,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-mailadres delen met poulebeheerder',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Alleen beheerders van jouw poules mogen je e-mailadres exporteren. Standaard uit.',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: allowEmailSharingWithPouleOwner,
                  activeColor: _green,
                  onChanged: (value) {
                    setState(() {
                      allowEmailSharingWithPouleOwner = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showPasswordChangeDialog,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Wachtwoord wijzigen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkGreen,
                side: const BorderSide(color: _borderGreen),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Afmelden'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tip',
              style: TextStyle(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Je profiel wordt gebruikt in ranglijsten en poules. Houd je gebruikersnaam herkenbaar.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.child,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null;

    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: _ProfileScreenState._borderGreen),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasHeader) ...[
              if (title != null)
                Text(
                  title!,
                  style: const TextStyle(
                    color: _ProfileScreenState._textDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _ProfileScreenState._textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _ProfileScreenState._softGreen,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ProfileScreenState._borderGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _ProfileScreenState._darkGreen,
            size: 17,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _ProfileScreenState._textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedUsername extends StatelessWidget {
  const _LockedUsername({
    required this.username,
  });

  final String username;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ProfileScreenState._softGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ProfileScreenState._borderGreen),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: _ProfileScreenState._darkGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gebruikersnaam',
                  style: TextStyle(
                    color: _ProfileScreenState._textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  username,
                  style: const TextStyle(
                    color: _ProfileScreenState._textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Vastgezet',
            style: TextStyle(
              color: _ProfileScreenState._textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
