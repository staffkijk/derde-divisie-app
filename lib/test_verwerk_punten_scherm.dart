import 'package:flutter/material.dart';
import 'puntenverwerker.dart'; // ✅ correcte relatieve import

class TestVerwerkPuntenScherm extends StatelessWidget {
  const TestVerwerkPuntenScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test: Verwerk Punten')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await verwerkUitslagVoorWedstrijd('Testwedstrijd');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Punten verwerkt')),
            );
          },
          child: const Text('Verwerk punten voor Testwedstrijd'),
        ),
      ),
    );
  }
}
