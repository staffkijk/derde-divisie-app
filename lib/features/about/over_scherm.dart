import 'package:flutter/material.dart';

class OverScherm extends StatelessWidget {
  const OverScherm({super.key});

  static const Color _primary = Color(0xFF0F3F2A);
  static const Color _primarySoft = Color(0xFFE8F5EE);
  static const Color _surface = Color(0xFFF4F7F5);
  static const Color _cardBorder = Color(0xFFE0E7E2);
  static const Color _text = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900 ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Over de app'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AboutHero(),
                  SizedBox(height: 22),
                  _InfoGrid(),
                  SizedBox(height: 22),
                  _ContactCard(),
                  SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Versie 1.1.0  ·  © Derde Divisie 2026',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  static const Color _primary = OverScherm._primary;
  static const Color _primarySoft = OverScherm._primarySoft;
  static const Color _cardBorder = OverScherm._cardBorder;
  static const Color _text = OverScherm._text;
  static const Color _muted = OverScherm._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              color: _primary,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Derde Divisie',
                  style: TextStyle(
                    color: _text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Een platform voor fans van de Derde Divisie. Volg standen, programma’s en uitslagen, voorspel wedstrijden en speel mee in poules met andere voetballiefhebbers.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(label: 'Voorspellen'),
                    _Badge(label: 'Poules'),
                    _Badge(label: 'Standen'),
                    _Badge(label: 'Uitslagen'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;

        const cards = [
          _InfoCard(
            icon: Icons.groups_rounded,
            title: 'Voor en door fans',
            text: 'De app is ontstaan vanuit de behoefte aan één duidelijke plek voor de Derde Divisie, met aandacht voor beide divisies en voor de community rond de competitie.',
          ),
          _InfoCard(
            icon: Icons.trending_up_rounded,
            title: 'Ranglijsten en competitie',
            text: 'Deelnemers kunnen punten verzamelen met voorspellingen. Algemene ranglijsten en poules maken het seizoen extra interessant.',
          ),
          _InfoCard(
            icon: Icons.build_rounded,
            title: 'Doorontwikkeling',
            text: 'Nieuwe functies, verbeteringen en correcties worden stap voor stap toegevoegd. Feedback van gebruikers helpt om de app beter te maken.',
          ),
          _InfoCard(
            icon: Icons.verified_rounded,
            title: 'Zorgvuldigheid',
            text: 'Uitslagen, standen en programma’s worden met zorg verwerkt. Bij fouten of correcties kan informatie later worden aangepast.',
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              cards[0],
              SizedBox(height: 14),
              cards[1],
              SizedBox(height: 14),
              cards[2],
              SizedBox(height: 14),
              cards[3],
            ],
          );
        }

        return Column(
          children: const [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _InfoCard(
                  icon: Icons.groups_rounded,
                  title: 'Voor en door fans',
                  text: 'De app is ontstaan vanuit de behoefte aan één duidelijke plek voor de Derde Divisie, met aandacht voor beide divisies en voor de community rond de competitie.',
                )),
                SizedBox(width: 16),
                Expanded(child: _InfoCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Ranglijsten en competitie',
                  text: 'Deelnemers kunnen punten verzamelen met voorspellingen. Algemene ranglijsten en poules maken het seizoen extra interessant.',
                )),
              ],
            ),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _InfoCard(
                  icon: Icons.build_rounded,
                  title: 'Doorontwikkeling',
                  text: 'Nieuwe functies, verbeteringen en correcties worden stap voor stap toegevoegd. Feedback van gebruikers helpt om de app beter te maken.',
                )),
                SizedBox(width: 16),
                Expanded(child: _InfoCard(
                  icon: Icons.verified_rounded,
                  title: 'Zorgvuldigheid',
                  text: 'Uitslagen, standen en programma’s worden met zorg verwerkt. Bij fouten of correcties kan informatie later worden aangepast.',
                )),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  static const Color _primary = OverScherm._primary;
  static const Color _primarySoft = OverScherm._primarySoft;
  static const Color _cardBorder = OverScherm._cardBorder;
  static const Color _text = OverScherm._text;
  static const Color _muted = OverScherm._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 178),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: _primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  static const Color _primary = OverScherm._primary;
  static const Color _primarySoft = OverScherm._primarySoft;
  static const Color _cardBorder = OverScherm._cardBorder;
  static const Color _text = OverScherm._text;
  static const Color _muted = OverScherm._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline_rounded, color: _primary, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Heb je een fout gezien, een vraag of een idee voor verbetering? Neem contact op via X: @Derde_Div of via e-mail: derdediv@gmail.com.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  static const Color _primary = OverScherm._primary;
  static const Color _primarySoft = OverScherm._primarySoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}