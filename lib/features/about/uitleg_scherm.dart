import 'package:flutter/material.dart';

class UitlegScherm extends StatelessWidget {
  const UitlegScherm({super.key});

  static const Color _darkGreen = Color(0xFF0F3D2E);
  static const Color _green = Color(0xFF2FA85A);
  static const Color _lightGreen = Color(0xFFEAF5EE);
  static const Color _pageBackground = Color(0xFFF6FAF7);
  static const Color _textDark = Color(0xFF13251B);
  static const Color _textMuted = Color(0xFF647067);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text('Help & Info'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 850;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HeroCard(),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _InfoTile(
                            width: isWide ? 541 : double.infinity,
                            icon: Icons.emoji_events_outlined,
                            title: 'Puntentelling',
                            subtitle:
                                'Bekijk hoe punten worden berekend bij exacte uitslagen, juiste winnaars, gelijke spelen en doelpunten.',
                            buttonText: 'Bekijk puntentelling',
                            onTap: () {
                              Navigator.pushNamed(context, '/puntentelling');
                            },
                          ),
                          _InfoTile(
                            width: isWide ? 541 : double.infinity,
                            icon: Icons.question_answer_outlined,
                            title: 'Veelgestelde vragen',
                            subtitle:
                                'Antwoorden op vragen over inloggen, voorspellen, deadlines, poules en je account.',
                            buttonText: 'Open FAQ',
                            onTap: () {
                              Navigator.pushNamed(context, '/faq');
                            },
                          ),
                          _InfoTile(
                            width: isWide ? 541 : double.infinity,
                            icon: Icons.info_outline,
                            title: 'Over Derde Divisie',
                            subtitle:
                                'Lees waarvoor deze website is gemaakt en wat je hier tijdens het seizoen kunt volgen.',
                            buttonText: 'Lees meer',
                            onTap: () {
                              Navigator.pushNamed(context, '/over');
                            },
                          ),
                          _InfoTile(
                            width: isWide ? 541 : double.infinity,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy en voorwaarden',
                            subtitle:
                                'Informatie over gegevensgebruik, voorwaarden, disclaimer en verantwoordelijkheid van gebruikers.',
                            buttonText: 'Bekijk voorwaarden',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/privacy',
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _QuickFaqCard(),
                      const SizedBox(height: 22),
                      const _ContactCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  static const Color _darkGreen = UitlegScherm._darkGreen;
  static const Color _green = UitlegScherm._green;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _darkGreen,
            Color(0xFF15593F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 650;

          return Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: compact ? 0 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Text(
                        'Supportcentrum',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Alles over voorspellen, poules en de werking van de website.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vind snel uitleg over de puntentelling, veelgestelde vragen, privacy en algemene informatie over Derde Divisie.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 0 : 28, height: compact ? 22 : 0),
              Container(
                width: compact ? 92 : 130,
                height: compact ? 92 : 130,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: _green,
                  size: 62,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  static const Color _green = UitlegScherm._green;
  static const Color _lightGreen = UitlegScherm._lightGreen;
  static const Color _textDark = UitlegScherm._textDark;
  static const Color _textMuted = UitlegScherm._textMuted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
  constraints: const BoxConstraints(
    minHeight: 190,
  ),
  padding: const EdgeInsets.all(22),
  decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE2EAE4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _lightGreen,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        icon,
                        color: _green,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward,
                      color: _green,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickFaqCard extends StatelessWidget {
  const _QuickFaqCard();

  static const Color _green = UitlegScherm._green;
  static const Color _textDark = UitlegScherm._textDark;
  static const Color _textMuted = UitlegScherm._textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE2EAE4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Snel uitgelegd',
            style: TextStyle(
              color: _textDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14),
          _FaqLine(
            question: 'Wanneer moet ik mijn voorspelling invullen?',
            answer:
                'Voor de ingestelde deadline. Daarna wordt voorspellen voor die wedstrijd geblokkeerd.',
          ),
          _FaqLine(
            question: 'Kan ik meerdere poules hebben?',
            answer:
                'Ja, afhankelijk van de ingestelde mogelijkheden kun je deelnemen aan meerdere poules.',
          ),
          _FaqLine(
            question: 'Waar zie ik mijn punten?',
            answer:
                'Je punten staan in de algemene ranking en binnen de poules waaraan je deelneemt.',
          ),
        ],
      ),
    );
  }
}

class _FaqLine extends StatelessWidget {
  const _FaqLine({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  static const Color _green = UitlegScherm._green;
  static const Color _textDark = UitlegScherm._textDark;
  static const Color _textMuted = UitlegScherm._textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: _green,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 14.5,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: '$question\n',
                    style: const TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: answer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  static const Color _darkGreen = UitlegScherm._darkGreen;
  static const Color _green = UitlegScherm._green;
  static const Color _textMuted = UitlegScherm._textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD4E7DA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: _green,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vraag, foutje of idee?',
                  style: TextStyle(
                    color: _darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Mist er iets of klopt er iets niet? Geef het door via X: @Derde_Div.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.45,
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