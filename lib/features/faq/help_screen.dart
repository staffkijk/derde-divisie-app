import 'package:flutter/material.dart';

import 'package:derde_divisie/features/about/uitleg_scherm.dart';
import 'package:derde_divisie/features/faq/faq_screen.dart';
import 'package:derde_divisie/features/about/over_scherm.dart';
import 'package:derde_divisie/features/about/juridisch_scherm.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const Color _primary = Color(0xFF0F3F2A);
  static const Color _primarySoft = Color(0xFFE8F5EE);
  static const Color _surface = Color(0xFFF4F7F5);
  static const Color _cardBorder = Color(0xFFE0E7E2);
  static const Color _text = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF6B7280);

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth >= 900 ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Help & Info'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HelpHero(),
                    const SizedBox(height: 22),
                    _HelpGrid(
                      cards: [
                        _HelpCardData(
                          icon: Icons.rule_rounded,
                          title: 'Puntentelling',
                          subtitle:
                              'Bekijk hoe punten worden toegekend voor uitslagen, winnaars, doelpunten en eindstandvoorspellingen.',
                          actionText: 'Bekijk puntentelling',
                          onTap: () => _openScreen(
                            const PuntentellingScreen(),
                          ),
                        ),
                        _HelpCardData(
                          icon: Icons.help_outline_rounded,
                          title: 'FAQ',
                          subtitle:
                              'Antwoorden op veelgestelde vragen over voorspellen, poules, profielen en ranglijsten.',
                          actionText: 'Open FAQ',
                          onTap: () => _openScreen(
                            const FaqScreen(),
                          ),
                        ),
                        _HelpCardData(
                          icon: Icons.info_outline_rounded,
                          title: 'Over de app',
                          subtitle:
                              'Lees meer over Derde Divisie, de community en de ontwikkeling van de app.',
                          actionText: 'Lees meer',
                          onTap: () => _openScreen(
                            const OverScherm(),
                          ),
                        ),
                        _HelpCardData(
                          icon: Icons.shield_outlined,
                          title: 'Privacy & Voorwaarden',
                          subtitle:
                              'Bekijk de privacyverklaring, gebruiksvoorwaarden en disclaimer van de webapp.',
                          actionText: 'Bekijk juridisch',
                          onTap: () => _openScreen(
                            const JuridischScherm(scrollTo: 'privacy'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SupportCard(),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'DerdeDiv · Helpcentrum',
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
          ],
        ),
      ),
    );
  }
}

class _HelpHero extends StatelessWidget {
  const _HelpHero();

  static const Color _text = _HelpScreenState._text;
  static const Color _muted = _HelpScreenState._muted;

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
            icon: Icons.support_agent_rounded,
            size: 58,
            iconSize: 34,
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Helpcentrum',
                  style: TextStyle(
                    color: _text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Alles rond de spelregels, veelgestelde vragen, informatie over de app en juridische documenten op één plek.',
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
                    _HelpBadge(label: 'Spelregels'),
                    _HelpBadge(label: 'FAQ'),
                    _HelpBadge(label: 'Contact'),
                    _HelpBadge(label: 'Privacy'),
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

class _HelpGrid extends StatelessWidget {
  final List<_HelpCardData> cards;

  const _HelpGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850 ? 2 : 1;
        final spacing = columns == 2 ? 16.0 : 14.0;
        final cardWidth = columns == 2
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: _HelpNavCard(data: card),
            );
          }).toList(),
        );
      },
    );
  }
}

class _HelpNavCard extends StatelessWidget {
  final _HelpCardData data;

  const _HelpNavCard({required this.data});

  static const Color _primary = _HelpScreenState._primary;
  static const Color _primarySoft = _HelpScreenState._primarySoft;
  static const Color _text = _HelpScreenState._text;
  static const Color _muted = _HelpScreenState._muted;

  @override
  Widget build(BuildContext context) {
    return _WhitePanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
            icon: data.icon,
            size: 48,
            iconSize: 27,
          ),
          const SizedBox(height: 16),
          Text(
            data.title,
            style: const TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.subtitle,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: data.onTap,
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                backgroundColor: _primarySoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                data.actionText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  static const Color _primary = _HelpScreenState._primary;
  static const Color _primarySoft = _HelpScreenState._primarySoft;
  static const Color _cardBorder = _HelpScreenState._cardBorder;
  static const Color _text = _HelpScreenState._text;
  static const Color _muted = _HelpScreenState._muted;

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
          Icon(
            Icons.mail_outline_rounded,
            color: _primary,
            size: 28,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vraag of fout gevonden?',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Meld fouten, ontbrekende informatie of verbetersuggesties via X: @Derde_Div of via e-mail: derdediv@gmail.com.',
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

class _WhitePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WhitePanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  static const Color _cardBorder = _HelpScreenState._cardBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const _IconBox({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  static const Color _primary = _HelpScreenState._primary;
  static const Color _primarySoft = _HelpScreenState._primarySoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        icon,
        color: _primary,
        size: iconSize,
      ),
    );
  }
}

class _HelpBadge extends StatelessWidget {
  final String label;

  const _HelpBadge({required this.label});

  static const Color _primary = _HelpScreenState._primary;
  static const Color _primarySoft = _HelpScreenState._primarySoft;

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

class _HelpCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onTap;

  const _HelpCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onTap,
  });
}
