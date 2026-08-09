import 'package:flutter/material.dart';

class JuridischScherm extends StatefulWidget {
  final String? scrollTo;

  const JuridischScherm({super.key, this.scrollTo});

  @override
  State<JuridischScherm> createState() => _JuridischSchermState();
}

class _JuridischSchermState extends State<JuridischScherm> {
  static const Color _primary = Color(0xFF0F3F2A);
  static const Color _primarySoft = Color(0xFFE8F5EE);
  static const Color _surface = Color(0xFFF4F7F5);
  static const Color _cardBorder = Color(0xFFE0E7E2);
  static const Color _text = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF6B7280);

  final _privacyKey = GlobalKey();
  final _voorwaardenKey = GlobalKey();
  final _disclaimerKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      BuildContext? target;
      switch (widget.scrollTo) {
        case 'privacy':
          target = _privacyKey.currentContext;
          break;
        case 'voorwaarden':
          target = _voorwaardenKey.currentContext;
          break;
        case 'disclaimer':
          target = _disclaimerKey.currentContext;
          break;
      }

      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.04,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900 ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Privacy & Voorwaarden'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LegalHero(),
                  const SizedBox(height: 22),
                  _QuickNav(
                    onPrivacy: () => _ensureVisible(_privacyKey),
                    onVoorwaarden: () => _ensureVisible(_voorwaardenKey),
                    onDisclaimer: () => _ensureVisible(_disclaimerKey),
                  ),
                  const SizedBox(height: 22),
                  _LegalSection(
                    sectionKey: _privacyKey,
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacyverklaring',
                    version: 'Versie 1.2.0',
                    date: 'Laatst bijgewerkt: juli 2026',
                    children: const [
                      _LegalParagraph(
                        'DerdeDiv verwerkt persoonsgegevens om de webapp te laten werken, accounts te beheren, voorspellingen te verwerken, ranglijsten te tonen en de veiligheid van de dienst te bewaken.',
                      ),
                      _LegalSubTitle('1. Wie is verantwoordelijk?'),
                      _LegalParagraph(
                        'De webapp wordt beheerd door DerdeDiv. Voor algemene vragen kun je contact opnemen via derdediv@gmail.com. Voor privacyverzoeken kun je contact opnemen via privacy.derdediv@gmail.com.',
                      ),
                      _LegalSubTitle('2. Welke gegevens verwerken wij?'),
                      _LegalBullets([
                        'Accountgegevens, zoals gebruikersnaam, e-mailadres en authenticatiegegevens.',
                        'Profielgegevens, zoals favoriete club, favoriete competitie, woonplaats als je die invult en profielfoto of avatar.',
                        'Voorspellingen, pouledeelname, scores, rankingposities en historische resultaten.',
                        'Technische gegevens, zoals apparaat, browser, foutmeldingen, beveiligingslogs en datum en tijd van gebruik.',
                        'Analyticsgegevens over schermen en functies, alleen wanneer analytics technisch is ingeschakeld volgens de gekozen toestemming.',
                        'Berichten, feedback of supportvragen die je zelf aan ons stuurt.',
                      ]),
                      _LegalSubTitle(
                          '3. Waarvoor gebruiken wij deze gegevens?'),
                      _LegalBullets([
                        'Om accounts aan te maken en gebruikers te laten inloggen.',
                        'Om voorspellingen, poules, punten, standen en ranglijsten te verwerken.',
                        'Om misbruik, technische fouten en beveiligingsproblemen te voorkomen of te onderzoeken.',
                        'Om de webapp te onderhouden en te verbeteren.',
                        'Om met Google Analytics 4 / Firebase Analytics te meten welke hoofdschermen en functies worden gebruikt, zonder e-mailadres, naam, gebruikersnaam of vrije tekst naar analytics te sturen.',
                        'Om te voldoen aan wettelijke verplichtingen als die van toepassing zijn.',
                      ]),
                      _LegalSubTitle('4. Grondslagen'),
                      _LegalParagraph(
                        'Wij verwerken gegevens alleen als daar een geldige reden voor is. In de praktijk gaat het vooral om uitvoering van de dienst, gerechtvaardigd belang bij beveiliging en beheer, toestemming wanneer die nodig is en wettelijke verplichtingen.',
                      ),
                      _LegalSubTitle('5. Zichtbaarheid in de app'),
                      _LegalParagraph(
                        'Gebruikersnamen, scores, rankingposities, pouleposities en voorspellingen kunnen zichtbaar zijn voor andere gebruikers, voor zover dat nodig is voor de werking van ranglijsten, poules en voorspellingen. Na deadlines kunnen voorspellingen zichtbaar worden binnen de app.',
                      ),
                      _LegalSubTitle('6. Delen met derden'),
                      _LegalParagraph(
                        'Wij verkopen geen persoonsgegevens. Voor hosting, database, authenticatie, beveiliging, automatische verwerking en analytics kunnen diensten van Firebase, Google Cloud en Google Analytics 4 worden gebruikt. Analytics wordt gebruikt als aanvullende meting naast de interne activiteitsregistratie.',
                      ),
                      _LegalSubTitle('7. Bewaartermijnen'),
                      _LegalBullets([
                        'Accountgegevens blijven bewaard zolang je account actief is.',
                        'Voorspellingen, scores en ranglijstgegevens kunnen worden bewaard voor seizoenhistorie en archieffuncties.',
                        'Supportberichten bewaren wij zolang dat nodig is voor afhandeling en administratie.',
                        'Back-ups en technische logs kunnen tijdelijk blijven bestaan, ook nadat gegevens uit de actieve omgeving zijn verwijderd.',
                      ]),
                      _LegalSubTitle('8. Beveiliging'),
                      _LegalParagraph(
                        'Wij gebruiken passende technische en organisatorische maatregelen, zoals beveiligde verbindingen, beperkte beheerstoegang en Firebase beveiligingsregels. Geen enkele digitale dienst kan volledige veiligheid garanderen.',
                      ),
                      _LegalSubTitle('9. Cookies en vergelijkbare technieken'),
                      _LegalParagraph(
                        'De webapp kan functionele cookies of vergelijkbare technieken gebruiken die nodig zijn voor inloggen, sessiebeheer, beveiliging en basisfunctionaliteit. Voor Google Analytics 4 / Firebase Analytics wordt op web een lokale toestemming opgeslagen. Nieuwe webbezoekers starten zonder analyticscollectie totdat zij een keuze maken. Bij toestemming wordt analyticscollectie ingeschakeld. Bij weigeren of intrekken wordt analyticscollectie uitgeschakeld. De keuze kan in het profiel worden aangepast.',
                      ),
                      _LegalSubTitle('10. Jouw rechten'),
                      _LegalBullets([
                        'Je kunt vragen welke persoonsgegevens wij van je verwerken.',
                        'Je kunt vragen om gegevens te corrigeren als ze onjuist zijn.',
                        'Je kunt vragen om verwijdering van gegevens, voor zover wij die niet meer hoeven te bewaren.',
                        'Je kunt bezwaar maken tegen bepaalde verwerkingen.',
                        'Je kunt vragen om beperking van verwerking of overdracht van gegevens wanneer dat wettelijk van toepassing is.',
                      ]),
                      _LegalParagraph(
                        'Stuur privacyverzoeken naar privacy.derdediv@gmail.com met als onderwerp Privacyverzoek. Wij kunnen vragen om informatie waarmee wij kunnen controleren dat het verzoek bij het juiste account hoort.',
                      ),
                      _LegalSubTitle('11. Wijzigingen'),
                      _LegalParagraph(
                        'Deze privacyverklaring kan worden aangepast als de app, de techniek of de wetgeving verandert. De meest recente versie staat in de app.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _LegalSection(
                    sectionKey: _voorwaardenKey,
                    icon: Icons.gavel_rounded,
                    title: 'Gebruiksvoorwaarden',
                    version: 'Versie 1.1.0',
                    date: 'Laatst bijgewerkt: juni 2026',
                    children: const [
                      _LegalParagraph(
                        'Door de webapp van DerdeDiv te gebruiken ga je akkoord met deze gebruiksvoorwaarden.',
                      ),
                      _LegalSubTitle('1. Doel van de app'),
                      _LegalParagraph(
                        'De app is bedoeld voor het volgen van de Derde Divisie, het voorspellen van wedstrijden, het deelnemen aan poules en het bekijken van standen, uitslagen, ranglijsten en statistieken.',
                      ),
                      _LegalSubTitle('2. Account en gebruik'),
                      _LegalBullets([
                        'Je bent verantwoordelijk voor de juistheid van je eigen accountgegevens en voorspellingen.',
                        'Je houdt je inloggegevens vertrouwelijk en gebruikt geen account van iemand anders.',
                        'Meerdere accounts gebruiken om ranglijsten of poules te beïnvloeden is niet toegestaan.',
                        'Misbruik, spam, ongepaste inhoud of verstoring van de app kan leiden tot beperking of blokkering van je account.',
                      ]),
                      _LegalSubTitle('3. Voorspellingen en deadlines'),
                      _LegalParagraph(
                        'Voorspellingen moeten worden ingevuld vóór de ingestelde deadline. Na de deadline kunnen voorspellingen niet meer worden gewijzigd, tenzij er sprake is van een technische correctie door beheer.',
                      ),
                      _LegalSubTitle('4. Ranglijsten en poules'),
                      _LegalParagraph(
                        'Punten, standen en ranglijsten worden berekend op basis van de ingestelde spelregels. Bij fouten in uitslagen, invoer of berekeningen mogen wij correcties doorvoeren.',
                      ),
                      _LegalSubTitle('5. Beschikbaarheid'),
                      _LegalParagraph(
                        'Wij proberen de app goed beschikbaar te houden, maar kunnen niet garanderen dat de app altijd zonder onderbreking of fout werkt. Onderhoud, storingen of externe diensten kunnen invloed hebben op de beschikbaarheid.',
                      ),
                      _LegalSubTitle('6. Inhoud en intellectueel eigendom'),
                      _LegalParagraph(
                        'De opzet, teksten, schermen, ranglijsten en overige appcontent mogen niet zonder toestemming worden gekopieerd, hergebruikt of commercieel geëxploiteerd. Clubnamen, logo’s en competitiereferenties blijven eigendom van de betreffende rechthebbenden.',
                      ),
                      _LegalSubTitle('7. Beheer en wijzigingen'),
                      _LegalParagraph(
                        'DerdeDiv mag functies wijzigen, tijdelijk uitschakelen of verwijderen als dat nodig is voor onderhoud, veiligheid, verbetering of naleving van regels.',
                      ),
                      _LegalSubTitle('8. Contact'),
                      _LegalParagraph(
                        'Voor vragen, foutmeldingen of verzoeken kun je contact opnemen via X: @Derde_Div of via e-mail: derdediv@gmail.com.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _LegalSection(
                    sectionKey: _disclaimerKey,
                    icon: Icons.info_outline_rounded,
                    title: 'Disclaimer',
                    version: 'Versie 1.1.0',
                    date: 'Laatst bijgewerkt: juni 2026',
                    children: const [
                      _LegalParagraph(
                        'De informatie in deze app wordt met zorg samengesteld. Toch kunnen uitslagen, standen, programma’s, punten, ranglijsten of andere gegevens onjuist, vertraagd of onvolledig zijn.',
                      ),
                      _LegalSubTitle('1. Geen officiële bron'),
                      _LegalParagraph(
                        'DerdeDiv is geen officiële publicatie van de KNVB of van de betrokken clubs. Officiële publicaties van bonden, clubs en bevoegde instanties zijn leidend.',
                      ),
                      _LegalSubTitle('2. Geen rechten'),
                      _LegalParagraph(
                        'Aan informatie in deze app kunnen geen rechten worden ontleend. Ook niet als gegevens later worden aangepast, gecorrigeerd of verwijderd.',
                      ),
                      _LegalSubTitle('3. Aansprakelijkheid'),
                      _LegalParagraph(
                        'DerdeDiv is niet aansprakelijk voor directe of indirecte schade door gebruik van de app, tijdelijke onbeschikbaarheid, foutieve gegevens, gemiste deadlines of wijzigingen in ranglijsten en punten.',
                      ),
                      _LegalSubTitle('4. Fouten melden'),
                      _LegalParagraph(
                        'Zie je een fout in uitslagen, standen, programma’s, ranglijsten of andere informatie? Meld dit via X: @Derde_Div of via e-mail: derdediv@gmail.com.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      '© DerdeDiv 2026',
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

  void _ensureVisible(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;

    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.04,
    );
  }
}

class _LegalHero extends StatelessWidget {
  const _LegalHero();

  static const Color _primary = _JuridischSchermState._primary;
  static const Color _primarySoft = _JuridischSchermState._primarySoft;
  static const Color _cardBorder = _JuridischSchermState._cardBorder;
  static const Color _text = _JuridischSchermState._text;
  static const Color _muted = _JuridischSchermState._muted;

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
              Icons.shield_outlined,
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
                  'Privacy, voorwaarden en disclaimer',
                  style: TextStyle(
                    color: _text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Hier lees je hoe DerdeDiv omgaat met gegevens, welke regels gelden voor het gebruik van de app en welke informatie als leidend geldt.',
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

class _QuickNav extends StatelessWidget {
  final VoidCallback onPrivacy;
  final VoidCallback onVoorwaarden;
  final VoidCallback onDisclaimer;

  const _QuickNav({
    required this.onPrivacy,
    required this.onVoorwaarden,
    required this.onDisclaimer,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _NavButton(
          label: 'Privacyverklaring',
          icon: Icons.lock_outline_rounded,
          onTap: onPrivacy,
        ),
        _NavButton(
          label: 'Gebruiksvoorwaarden',
          icon: Icons.gavel_rounded,
          onTap: onVoorwaarden,
        ),
        _NavButton(
          label: 'Disclaimer',
          icon: Icons.info_outline_rounded,
          onTap: onDisclaimer,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  static const Color _primary = _JuridischSchermState._primary;
  static const Color _primarySoft = _JuridischSchermState._primarySoft;
  static const Color _cardBorder = _JuridischSchermState._cardBorder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _primarySoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _primary, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final Key sectionKey;
  final IconData icon;
  final String title;
  final String version;
  final String date;
  final List<Widget> children;

  const _LegalSection({
    required this.sectionKey,
    required this.icon,
    required this.title,
    required this.version,
    required this.date,
    required this.children,
  });

  static const Color _primary = _JuridischSchermState._primary;
  static const Color _primarySoft = _JuridischSchermState._primarySoft;
  static const Color _cardBorder = _JuridischSchermState._cardBorder;
  static const Color _text = _JuridischSchermState._text;
  static const Color _muted = _JuridischSchermState._muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$version  ·  $date',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _LegalSubTitle extends StatelessWidget {
  final String text;

  const _LegalSubTitle(this.text);

  static const Color _text = _JuridischSchermState._text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _text,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  final String text;

  const _LegalParagraph(this.text);

  static const Color _muted = _JuridischSchermState._muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 15.5,
          height: 1.55,
        ),
      ),
    );
  }
}

class _LegalBullets extends StatelessWidget {
  final List<String> items;

  const _LegalBullets(this.items);

  static const Color _primary = _JuridischSchermState._primary;
  static const Color _muted = _JuridischSchermState._muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 8, right: 10),
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
