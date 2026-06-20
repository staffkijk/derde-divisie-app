import 'package:flutter/material.dart';
import '../moderator/standen_service.dart';

class HerberekenStandenTool extends StatefulWidget {
  const HerberekenStandenTool({super.key});

  @override
  State<HerberekenStandenTool> createState() => _HerberekenStandenToolState();
}

class _HerberekenStandenToolState extends State<HerberekenStandenTool> {
  bool _loading = false;
  String _status = "";

  Future<void> _recalcAll() async {
    setState(() {
      _loading = true;
      _status = "Bezig met herberekenen van standen...";
    });

    try {
      final service = StandenService();
      await service.herberekenStandVoorDivisie("A");
      await service.herberekenStandVoorDivisie("B");

      setState(() {
        _status = "✅ Standen Divisie A en B opnieuw berekend!";
      });
    } catch (e) {
      setState(() {
        _status = "❌ Fout bij berekenen: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Herbereken standen")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.refresh),
              label: const Text("Herbereken Divisie A + B"),
              onPressed: _loading ? null : _recalcAll,
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
