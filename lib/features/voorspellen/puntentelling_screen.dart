import 'package:flutter/material.dart';

class PuntentellingScreen extends StatelessWidget {
  const PuntentellingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puntentelling'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'In de voorspelpoule kun je punten verdienen op basis van je voorspellingen per wedstrijd én op basis van de eindstand. '
                'Hieronder zie je hoe de puntentelling precies werkt.',
                style: textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),

            const SizedBox(height: 24),

            // Basispunten sectie
            _buildSectionHeader(
              icon: '📊',
              title: 'Basispunten per wedstrijd',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildCard([
              _puntregel('Uitslag exact goed', '10 punten'),
              _puntregel('Gelijkspel voorspeld', '7 punten'),
              _puntregel('Goed team als winnaar', '5 punten'),
              _puntregel('Goed aantal doelpunten (thuis of uit)', '2 punten'),
            ]),

            const SizedBox(height: 32),

            // Extra voorspellingen sectie
            _buildSectionHeader(
              icon: '⭐',
              title: 'Extra voorspellingen (eindstand)',
              color: Colors.amber[700]!,
            ),
            const SizedBox(height: 12),
            _buildCard([
              _puntregel('Kampioen correct voorspeld', '30 punten'),
              _puntregel('Exacte eindpositie correct (anders dan kampioen)',
                  '10 punten'),
              _puntregel('1 plek ernaast', '6 punten'),
              _puntregel('2 plekken ernaast', '2 punten'),
            ]),

            const SizedBox(height: 32),

            // Footer info
            Center(
              child: Text(
                'Laatste update: oktober 2025',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- helpers ----------

  Widget _buildSectionHeader({
    required String icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _puntregel(String tekst, String punten) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, height: 1.4)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.black87, fontSize: 16, height: 1.4),
                children: [
                  TextSpan(
                    text: '$tekst: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: punten),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
