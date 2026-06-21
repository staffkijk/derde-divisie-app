import 'package:flutter/material.dart';

class UitlegScherm extends StatelessWidget {
  const UitlegScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.info_outline),
            label: const Text('Puntentelling'),
            onPressed: () {
              Navigator.pushNamed(context, '/puntentelling');
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('FAQ'),
            onPressed: () {
              Navigator.pushNamed(context, '/faq');
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.info),
            label: const Text('Over de app'),
            onPressed: () {
              Navigator.pushNamed(context, '/over');
            },
          ),
        ],
      ),
    );
  }
}
