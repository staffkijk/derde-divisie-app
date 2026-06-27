import 'package:flutter/material.dart';

class PuntentellingScreen extends StatelessWidget {
  const PuntentellingScreen({super.key});

  static const Color _primary = Color(0xFF0F3F2A);
  static const Color _primarySoft = Color(0xFFE8F5EE);
  static const Color _accent = Color(0xFF2E7D32);
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
        title: const Text('Puntentelling'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 850;

                      final cards = [
                        const _RuleCard(
                          icon: Icons.sports_soccer_rounded,
                          title: 'Wedstrijdvoorspellingen',
                          subtitle: 'Punten per gespeelde wedstrijd',
                          rules: [
                            _ScoreRule('Exacte uitslag goed', '10 punten', 'Bijvoorbeeld 2-1 voorspeld en 2-1 gespeeld.'),
                            _ScoreRule('Gelijkspel goed voorspeld', '7 punten', 'Je voorspelt een gelijkspel en de wedstrijd eindigt gelijk.'),
                            _ScoreRule('Winnaar goed voorspeld', '5 punten', 'Je voorspelt de juiste winnaar, maar niet de exacte uitslag.'),
                            _ScoreRule('Doelpunten thuis of uit goed', '2 punten', 'Per juist voorspeld aantal doelpunten.'),
                          ],
                        ),
                        const _RuleCard(
                          icon: Icons.emoji_events_rounded,
                          title: 'Eindstandvoorspellingen',
                          subtitle: 'Extra punten aan het einde van het seizoen',
                          rules: [
                            _ScoreRule('Kampioen correct voorspeld', '30 punten', 'De kampioen van de divisie staat op plek 1 in jouw voorspelling.'),
                            _ScoreRule('Exacte eindpositie correct', '10 punten', 'Geldt voor clubs die niet als kampioen eindigen.'),
                            _ScoreRule('Één plek verschil', '6 punten', 'Bijvoorbeeld 4e voorspeld en 5e geworden.'),
                            _ScoreRule('Twee plekken verschil', '2 punten', 'Bijvoorbeeld 7e voorspeld en 9e geworden.'),
                          ],
                        ),
                      ];

                      if (!isWide) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 16),
                            cards[1],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 18),
                          Expanded(child: cards[1]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const _ExampleCard(),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Laatste update: juni 2026',
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  static const Color _primary = PuntentellingScreen._primary;
  static const Color _primarySoft = PuntentellingScreen._primarySoft;
  static const Color _accent = PuntentellingScreen._accent;
  static const Color _text = PuntentellingScreen._text;
  static const Color _muted = PuntentellingScreen._muted;
  static const Color _cardBorder = PuntentellingScreen._cardBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.rule_rounded,
              color: _primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zo werkt de puntentelling',
                  style: TextStyle(
                    color: _text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Je scoort punten met wedstrijdvoorspellingen en met je voorspelde eindstand. De exacte uitslag levert het meeste op, maar ook een juiste winnaar of een goed aantal doelpunten telt mee.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Seizoen 2026/2027',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_ScoreRule> rules;

  const _RuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rules,
  });

  static const Color _primary = PuntentellingScreen._primary;
  static const Color _primarySoft = PuntentellingScreen._primarySoft;
  static const Color _cardBorder = PuntentellingScreen._cardBorder;
  static const Color _text = PuntentellingScreen._text;
  static const Color _muted = PuntentellingScreen._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...rules.map((rule) => _RuleRow(rule: rule)),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final _ScoreRule rule;

  const _RuleRow({required this.rule});

 
  static const Color _cardBorder = PuntentellingScreen._cardBorder;
  static const Color _text = PuntentellingScreen._text;
  static const Color _muted = PuntentellingScreen._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScorePill(label: rule.points),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.4,
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

class _ScorePill extends StatelessWidget {
  final String label;

  const _ScorePill({required this.label});

  static const Color _primary = PuntentellingScreen._primary;
  static const Color _primarySoft = PuntentellingScreen._primarySoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard();

  static const Color _primary = PuntentellingScreen._primary;
  static const Color _primarySoft = PuntentellingScreen._primarySoft;
  static const Color _cardBorder = PuntentellingScreen._cardBorder;
  static const Color _text = PuntentellingScreen._text;
  static const Color _muted = PuntentellingScreen._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: _primary, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Voorbeeld: ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _text),
                  ),
                  TextSpan(
                    text: 'voorspel je 2-1 en wordt het 2-1, dan ontvang je 10 punten. Voorspel je 2-1 en wordt het 3-1, dan heb je de winnaar goed en krijg je punten voor het juiste uitdoelpunt.',
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 15, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRule {
  final String title;
  final String points;
  final String description;

  const _ScoreRule(this.title, this.points, this.description);
}