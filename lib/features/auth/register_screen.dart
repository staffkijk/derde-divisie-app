import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:derde_divisie/core/utils/gemeenten.dart';
import 'package:derde_divisie/features/about/juridisch_scherm.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/services/activity_log_service.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final woonplaatsController = TextEditingController();

  // Keuzes
  String? geselecteerdeCompetitie;
  String? geselecteerdeClub;
  String? geselecteerdeAvatar;

  // UI state
  String errorMessage = '';
  bool isLoading = false;
  bool akkoordMetVoorwaarden = false; // ✅ nieuw veld voor checkbox

  // Gemeentenlijst (voor autocomplete)
  late final Set<String> _gemeentenLower =
      nederlandseGemeenten.map((g) => g.toLowerCase()).toSet();

  // Competities
  final List<String> competities = [
    'Derde Divisie A',
    'Derde Divisie B',
    'Allebei',
    'Geen voorkeur'
  ];

  // Clubs
  late final List<String> clubs = [
    'Geen voorkeur',
    ...SeasonConfig.teamsInListOrder.map((team) => team.label),
  ];

  // Avatars (clublogo's + bal)
  final List<String> avatars = [
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    woonplaatsController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!akkoordMetVoorwaarden) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Je moet akkoord gaan met de voorwaarden om verder te gaan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      errorMessage = '';
      isLoading = true;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final canoniekGemeente = _canoniekeGemeente(woonplaatsController.text);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'ismoderator': false,
        'heeftGebruikersnaamGewijzigd': false,
        'avatarUrl': geselecteerdeAvatar ?? 'assets/images/profiel_bal.png',
        'woonplaats': canoniekGemeente,
        'favorieteCompetitie': geselecteerdeCompetitie,
        'favorieteClub': geselecteerdeClub,
        if (geselecteerdeClub != null &&
            geselecteerdeClub != 'Geen voorkeur') ...{
          'favoriteTeamSlug': SeasonConfig.teamByName(geselecteerdeClub!)?.id,
          'favoriteTeamName': geselecteerdeClub,
          'favoriteDivision':
              SeasonConfig.teamByName(geselecteerdeClub!)?.division,
        },
        'allowEmailSharingWithPouleOwner': false,
        'punten_A': 0,
        'punten_B': 0,
        'totalen': 0,
        'eigenPoules': 0,
        'gejoinedePoules': 0,
        'voorspellingenZichtbaar': true,
        'aangemaaktOp': FieldValue.serverTimestamp(),
      });
      await ActivityLogService().log(eventType: ActivityEventType.register);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registratie gelukt!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? 'Onbekende fout');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String? _canoniekeGemeente(String? input) {
    if (input == null) return null;
    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return null;
    if (!_gemeentenLower.contains(lower)) return null;
    return nederlandseGemeenten.firstWhere((g) => g.toLowerCase() == lower);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      appBar: AppBar(
        title: const Text('Account aanmaken'),
        backgroundColor: const Color(0xFF153B2A),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: const DerdeDivLogo.full(height: 90),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registreer om mee te doen aan de Derde Divisie Voorspelpoule!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),

              // Gebruikersnaam
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Gebruikersnaam *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Verplicht veld'
                    : null,
              ),
              const SizedBox(height: 16),

              // E-mail
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mailadres *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Verplicht veld';
                  }
                  if (!value.contains('@')) {
                    return 'Ongeldig e-mailadres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Wachtwoord
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Wachtwoord *',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Minimaal 6 tekens'
                    : null,
              ),
              const SizedBox(height: 16),

              // Gemeente (optioneel)
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue value) {
                  final input = value.text.trim().toLowerCase();
                  if (input.isEmpty) return const Iterable<String>.empty();
                  return nederlandseGemeenten
                      .where((g) => g.toLowerCase().contains(input));
                },
                onSelected: (selection) =>
                    woonplaatsController.text = selection,
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  controller.text = woonplaatsController.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    decoration: const InputDecoration(
                      labelText: 'Gemeente (optioneel)',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Favoriete competitie
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Favoriete competitie *',
                  prefixIcon: Icon(Icons.sports_soccer),
                  border: OutlineInputBorder(),
                ),
                value: geselecteerdeCompetitie,
                items: competities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => geselecteerdeCompetitie = v),
                validator: (value) =>
                    value == null ? 'Selecteer een competitie' : null,
              ),
              const SizedBox(height: 16),

              // Favoriete club
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Favoriete club *',
                  prefixIcon: Icon(Icons.shield),
                  border: OutlineInputBorder(),
                ),
                value: geselecteerdeClub,
                items: clubs
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => geselecteerdeClub = v),
                validator: (value) =>
                    value == null ? 'Selecteer een club' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'Kies je profielfoto:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // ✅ Horizontale avatarselectie
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: avatars.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 92,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final path = avatars[index];
                  final isSelected = path == geselecteerdeAvatar;
                  return GestureDetector(
                    onTap: () => setState(() => geselecteerdeAvatar = path),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isSelected ? Colors.green : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: AssetImage(path),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ✅ Checkbox voor akkoord
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: akkoordMetVoorwaarden,
                    onChanged: (v) =>
                        setState(() => akkoordMetVoorwaarden = v ?? false),
                    activeColor: Colors.green.shade700,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const JuridischScherm(scrollTo: 'privacy'),
                          ),
                        );
                      },
                      child: const Text.rich(
                        TextSpan(
                          text: 'Ik ga akkoord met de ',
                          children: [
                            TextSpan(
                              text: 'Privacyverklaring en Gebruiksvoorwaarden',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: isLoading ? null : _register,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  isLoading ? 'Bezig met registreren...' : 'Account aanmaken',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
