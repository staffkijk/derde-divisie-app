import 'package:flutter/material.dart';
import 'prediction_screen.dart';
import 'package:derde_divisie/features/voorspellen/eindstand_voorspelling_screen.dart';

class VoorspellenScreen extends StatelessWidget {
  const VoorspellenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Divisie A',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.sports_soccer),
              label: const Text('Wedstrijden – Divisie A'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PredictionScreen(divisie: 'A'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.leaderboard),
              label: const Text('Eindstand – Divisie A'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const EindstandVoorspellingScreen(divisie: 'A'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Divisie B',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.sports_soccer),
              label: const Text('Wedstrijden – Divisie B'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PredictionScreen(divisie: 'B'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.leaderboard),
              label: const Text('Eindstand – Divisie B'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const EindstandVoorspellingScreen(divisie: 'B'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
