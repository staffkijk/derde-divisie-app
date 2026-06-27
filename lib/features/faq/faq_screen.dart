import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

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
        title: const Text('FAQ'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FaqHero(),
                  SizedBox(height: 22),
                  _FaqSection(
                    icon: Icons.sports_soccer_rounded,
                    title: 'Voorspellen',
                    items: [
                      _FaqItem(
                        question: 'Tot wanneer kan ik voorspellen?',
                        answer:
                            'Je kunt voorspellen tot de ingestelde deadline van de speelronde. In de meeste gevallen is dat 12:00 uur op de wedstrijddag van de eerste wedstrijd in die speelronde.',
                      ),
                      _FaqItem(
                        question: 'Kan ik mijn voorspellingen aanpassen?',
                        answer:
                            'Ja. Zolang de deadline nog niet is verstreken kun je jouw voorspellingen wijzigen.',
                      ),
                      _FaqItem(
                        question: 'Kan ik voorspellingen van anderen bekijken?',
                        answer:
                            'Na de deadline worden voorspellingen zichtbaar. Voor die tijd hangt zichtbaarheid af van de profielinstellingen van de gebruiker.',
                      ),
                      _FaqItem(
                        question:
                            'Moet ik apart voorspellen voor algemene voorspellingen en poules?',
                        answer:
                            'Dat hoeft niet altijd. Per poule kan worden ingesteld of algemene voorspellingen worden gebruikt of dat je apart voor die poule voorspelt.',
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  _FaqSection(
                    icon: Icons.person_rounded,
                    title: 'Profiel',
                    items: [
                      _FaqItem(
                        question: 'Hoe wijzig ik mijn gebruikersnaam?',
                        answer:
                            'Je gebruikersnaam kun je via je profielpagina aanpassen. Als er een wijzigingslimiet actief is, wordt dit daar aangegeven.',
                      ),
                      _FaqItem(
                        question: 'Hoe wijzig ik mijn profielfoto?',
                        answer:
                            'Open je profielpagina en kies daar een andere profielfoto. De beschikbare opties kunnen per versie verschillen.',
                      ),
                      _FaqItem(
                        question: 'Waarom is mijn profiel zichtbaar in ranglijsten?',
                        answer:
                            'Ranglijsten tonen deelnemers zodat poules en algemene standen goed werken. Afhankelijk van je instellingen kan beperkte profielinformatie zichtbaar zijn.',
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  _FaqSection(
                    icon: Icons.groups_rounded,
                    title: 'Poules',
                    items: [
                      _FaqItem(
                        question: 'Hoe maak ik een poule aan?',
                        answer:
                            'Ga naar Poules, kies voor een nieuwe poule en volg de stappen. Daarna kun je anderen uitnodigen.',
                      ),
                      _FaqItem(
                        question:
                            'Wat is het verschil tussen een teampoule en een volledige poule?',
                        answer:
                            'Bij een teampoule voorspel je wedstrijden van één club. Bij een volledige poule voorspel je wedstrijden binnen de gekozen divisie of competitie.',
                      ),
                      _FaqItem(
                        question: 'Kan ik later nog mensen toevoegen aan mijn poule?',
                        answer:
                            'Ja, zolang de poule instellingen dit toestaan. De beheerder van de poule bepaalt meestal wie kan deelnemen.',
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  _FaqSection(
                    icon: Icons.rule_rounded,
                    title: 'Puntentelling',
                    items: [
                      _FaqItem(
                        question: 'Hoe werkt de puntentelling?',
                        answer:
                            'De puntentelling bestaat uit punten per wedstrijd en extra punten voor eindstandvoorspellingen. Open het scherm Puntentelling voor het volledige overzicht.',
                      ),
                      _FaqItem(
                        question: 'Wanneer worden punten verwerkt?',
                        answer:
                            'Punten worden verwerkt nadat uitslagen zijn ingevoerd en gecontroleerd. Bij correcties kan de ranglijst later nog wijzigen.',
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Center(
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

class _FaqHero extends StatelessWidget {
  const _FaqHero();

  static const Color _primary = FaqScreen._primary;
  static const Color _primarySoft = FaqScreen._primarySoft;
  static const Color _cardBorder = FaqScreen._cardBorder;
  static const Color _text = FaqScreen._text;
  static const Color _muted = FaqScreen._muted;

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
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
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
                  'Veelgestelde vragen',
                  style: TextStyle(
                    color: _text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Hier vind je uitleg over voorspellen, poules, profielen en punten. De vragen zijn gegroepeerd zodat je sneller vindt wat je zoekt.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 16,
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

class _FaqSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_FaqItem> items;

  const _FaqSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  static const Color _primary = FaqScreen._primary;
  static const Color _primarySoft = FaqScreen._primarySoft;
  static const Color _cardBorder = FaqScreen._cardBorder;
  static const Color _text = FaqScreen._text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
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
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _FaqTile(item: item)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;

  const _FaqTile({required this.item});

  static const Color _primary = FaqScreen._primary;
  static const Color _primarySoft = FaqScreen._primarySoft;
  static const Color _text = FaqScreen._text;
  static const Color _muted = FaqScreen._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _primarySoft,
          highlightColor: _primarySoft,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          iconColor: _primary,
          collapsedIconColor: _primary,
          title: Text(
            item.question,
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}