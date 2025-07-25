import 'package:flutter/material.dart';

import 'screens/wedstrijden_scherm_derde_divisie_a.dart';
import 'screens/wedstrijden_scherm_derde_divisie_ab.dart';
import 'screens/wedstrijden_scherm_derde_divisie_b.dart';

class PredictionScreen extends StatelessWidget {
  final String divisie;

  const PredictionScreen({super.key, required this.divisie});

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (divisie) {
      case 'A':
        child = const WedstrijdenSchermDerdeDivisieA(divisie: 'A');
        break;
      case 'B':
        child = const WedstrijdenSchermDerdeDivisieB(divisie: 'B');
        break;
      case 'AB':
        child = const WedstrijdenSchermDerdeDivisieAB();
        break;
      default:
        child = const Center(child: Text('Onbekende divisie'));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Voorspellen – Divisie $divisie')),
      body: child,
    );
  }
}
