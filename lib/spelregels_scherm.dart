import 'package:flutter/material.dart';

class SpelregelsScherm extends StatelessWidget {
  const SpelregelsScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spelregels')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'In dit spel voorspel je de uitslagen van wedstrijden in de Derde Divisie. '
          'Je voorspelt vóór de deadline de stand (bijv. 2-1). Na afloop wordt gekeken of je het goed had.',
        ),
      ),
    );
  }
}
