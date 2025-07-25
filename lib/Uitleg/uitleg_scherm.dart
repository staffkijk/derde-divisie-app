import 'package:flutter/material.dart';

class UitlegScherm extends StatelessWidget {
  const UitlegScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speluitleg'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Spelregels'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/spelregels');
            },
          ),
          ListTile(
            title: const Text('Puntentelling'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/puntentelling');
            },
          ),
          ListTile(
            title: const Text('Veelgestelde vragen (FAQ)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/faq');
            },
          ),
        ],
      ),
    );
  }
}
