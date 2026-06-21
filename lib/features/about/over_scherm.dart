import 'package:flutter/material.dart';

class OverScherm extends StatelessWidget {
  const OverScherm({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Over de app'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel + korte intro
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voor en door fans van de Derde Divisie',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Met deze app brengen we de Derde Divisie dichterbij dan ooit. '
                    'Voorspel wedstrijden, maak je eigen poule met vrienden en houd live de standen bij.\n\n'
                    'Deze app is een initiatief van het X-account @Derde_Div.',
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Onderhoud en verbeteringen
            _infoCard(
              icon: Icons.build_rounded,
              title: 'Onderhoud en verbeteringen',
              text:
                  'We werken voortdurend aan onderhoud, verbeteringen en nieuwe functies. '
                  'Heb je een idee of mis je iets? Laat het ons weten via onze kanalen!',
            ),

            const SizedBox(height: 20),

            // Contact
            _infoCard(
              icon: Icons.email_rounded,
              title: 'Contact',
              text:
                  'Heb je een fout ontdekt in de app of een vraag? '
                  'Neem contact met ons op via X (@Derde_Div) of mail naar '
                  'derdediv@gmail.com.',
            ),

            const SizedBox(height: 28),

            // Footer
            Center(
              child: Text(
                'Versie 1.0.0 — © Derde Divisie 2025',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper-widget voor sectiekaarten
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
