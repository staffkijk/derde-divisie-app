import 'package:flutter/material.dart';
import '../../poules/services/poule_service.dart';



class TestVerwerkPuntenScherm extends StatelessWidget {
  const TestVerwerkPuntenScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test punten verwerken')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final service = PouleService();

            try {
              await service.verwerkPuntenVoorPouleVoorspellingen(
                pouleId: 'dca0e57b-cfaa-4eb6-b4dd-0d0a0077e0ec', // je test-pouleId
                matchId: 'A1', // je test-wedstrijdId
                echteHome: 2, // echte uitslag
                echteAway: 1,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Punten succesvol verwerkt')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fout: $e')),
              );
            }
          },
          child: const Text('Verwerk punten voor A1'),
        ),
      ),
    );
  }
}
