import 'package:flutter/material.dart';
import 'package:derde_divisie/features/derde_divisie/wedstrijden_scherm_derde_divisie_a.dart';
import 'package:derde_divisie/features/derde_divisie/wedstrijden_scherm_derde_divisie_b.dart';

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
      default:
        child = const Center(child: Text('Onbekende divisie'));
    }

    return Scaffold(
  appBar: AppBar(
    title: Text('Wedstrijden voorspellen – Divisie $divisie'),
  ),
  body: child,
);

  }
}
