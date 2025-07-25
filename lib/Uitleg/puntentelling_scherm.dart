import 'package:flutter/material.dart';

class PuntentellingScherm extends StatelessWidget {
  const PuntentellingScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puntentelling')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Uitslag correct 10 punten'
          'Gelijkspel correct 7 punten'
          'Winnaar correct 5 punten'
          'Aantal doelpunten thuisteam correct 2 punten'
          'Aantal doelpunten uitteam correct 2 punten'
      
        ),
      ),
    );
  }
}
