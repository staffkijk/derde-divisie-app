import 'package:flutter/material.dart';

class PuntentellingScherm extends StatelessWidget {
  const PuntentellingScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puntentelling')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔢 Punten per voorspelling:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('• Uitslag exact goed: 10 punten'),
            Text('• Gelijkspel goed (niet exact): 7 punten'),
            Text('• Winnaar goed: 5 punten'),
            Text('• Doelpunten thuisteam goed: 2 punten'),
            Text('• Doelpunten uitteam goed: 2 punten'),
            SizedBox(height: 20),
            Text(
              '🏆 Bonuspunten aan het einde van het seizoen:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('• Kampioen correct voorspeld: 30 punten'),
            Text('• Juiste eindpositie (anders dan kampioen): 10 punten'),
            Text('• Eén plek ernaast: 6 punten'),
            Text('• Twee plekken ernaast: 2 punten'),
            SizedBox(height: 20),
            Text(
              '📊 Totale ranking:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '• Je kunt voorspellen voor Divisie A en/of B.\n'
              '• Voor de algemene ranglijst telt alleen je hoogste score mee.\n'
              '  (wedstrijdpunten + bonuspunten) uit A of B.',
            ),
          ],
        ),
      ),
    );
  }
}
