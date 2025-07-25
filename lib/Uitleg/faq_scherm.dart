import 'package:flutter/material.dart';

class FaqScherm extends StatelessWidget {
  const FaqScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veelgestelde vragen')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '❓ Wanneer moet ik voorspellen?\n'
          'Voorspellingen moeten vóór de deadline worden ingevoerd (12:00 op de wedstrijddag).\n\n'
          '❓ Kan ik mijn voorspelling later aanpassen?\n'
          'Ja, zolang de deadline niet is verstreken.\n\n'
          '❓ Hoe werkt de ranglijst?\n'
          'Je scoort punten per wedstrijd. De totaalscore bepaalt je plek in het klassement.',
        ),
      ),
    );
  }
}
