import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import '../screens/juridisch_scherm.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String errorMessage = '';
  bool isLoading = false;
  bool wachtwoordZichtbaar = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      errorMessage = '';
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Succesvol ingelogd!')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = _vertaalFoutmelding(e.code);
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _wachtwoordVergeten() async {
    final herstelEmailController =
        TextEditingController(text: emailController.text);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Wachtwoord herstellen'),
          content: TextField(
            controller: herstelEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mailadres',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: herstelEmailController.text.trim(),
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'E-mail verzonden om je wachtwoord te herstellen'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Fout bij verzenden: ${e.toString()}'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              child: const Text('Verzenden'),
            ),
          ],
        );
      },
    );
  }

  String _vertaalFoutmelding(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Geen gebruiker gevonden met dit e-mailadres.';
      case 'wrong-password':
        return 'Verkeerd wachtwoord.';
      case 'invalid-email':
        return 'Ongeldig e-mailadres.';
      case 'too-many-requests':
        return 'Te veel pogingen. Probeer het later opnieuw.';
      case 'user-disabled':
        return 'Dit account is uitgeschakeld.';
      default:
        return 'Er is iets misgegaan. Probeer opnieuw.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / Header
              Column(
                children: [
                  Image.asset(
                    'assets/derde_divisie_logo_icon.png',
                    height: 100,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Derde Divisie App',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Voorspel, scoor en stijg in de ranglijst!',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // E-mailadres veld
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mailadres',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Wachtwoord veld
              TextField(
                controller: passwordController,
                obscureText: !wachtwoordZichtbaar,
                decoration: InputDecoration(
                  labelText: 'Wachtwoord',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      wachtwoordZichtbaar
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => wachtwoordZichtbaar = !wachtwoordZichtbaar),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _wachtwoordVergeten,
                  child: const Text(
                    'Wachtwoord vergeten?',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Foutmelding
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Inloggen knop
              ElevatedButton.icon(
                onPressed: isLoading ? null : login,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  isLoading ? 'Bezig met inloggen...' : 'Inloggen',
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

              const SizedBox(height: 30),

              // Registreren
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Nog geen account?'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Registreer hier',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ✅ Toegevoegd: juridische info zichtbaar vóór inloggen
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const JuridischScherm(scrollTo: 'privacy'),
                      ),
                    );
                  },
                  child: const Text(
                    'Privacyverklaring en gebruiksvoorwaarden',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.black54,
                    ),
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
