import 'package:flutter/material.dart';

class JuridischScherm extends StatefulWidget {
  final String? scrollTo; // 'privacy', 'voorwaarden', 'disclaimer'
  const JuridischScherm({super.key, this.scrollTo});

  @override
  State<JuridischScherm> createState() => _JuridischSchermState();
}

class _JuridischSchermState extends State<JuridischScherm> {
  final _privacyKey = GlobalKey();
  final _voorwaardenKey = GlobalKey();
  final _disclaimerKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
  }

  void _scrollToSection() {
    Future.delayed(const Duration(milliseconds: 300), () {
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
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Voorwaarden')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔒 PRIVACYVERKLARING
            _buildSectionTitle('Privacyverklaring', _privacyKey),
            _buildSectionBody(_privacyTekst),

            const SizedBox(height: 32),

            // ⚙️ GEBRUIKSVOORWAARDEN
            _buildSectionTitle('Gebruiksvoorwaarden', _voorwaardenKey),
            _buildSectionBody(_voorwaardenTekst),

            const SizedBox(height: 32),

            // ⚠️ DISCLAIMER
            _buildSectionTitle('Disclaimer', _disclaimerKey),
            _buildSectionBody(_disclaimerTekst),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Key key) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }

  // --------------------------------------------------------------------------
  // 📄 Inhoud: Privacyverklaring
  // --------------------------------------------------------------------------
  final String _privacyTekst = '''
**Versie:** 1.0  
**Datum:** oktober 2025  

Deze web-app wordt beheerd door **Derde Divisie**.  
Voor vragen of verzoeken over privacy kun je contact opnemen via:  
📧 **privacy.derdediv@gmail.com**

---

### Welke gegevens wij verzamelen
Wij verwerken o.a.:
- Accountgegevens (gebruikersnaam, e-mailadres, wachtwoord)
- Profielinformatie (favoriete competitie, club, woonplaats, profielfoto)
- Voorspellingen en resultaten
- Technische gegevens (IP-adres, apparaat, browser)
- Feedback of berichten die je ons stuurt

Wij verzamelen geen gevoelige persoonsgegevens.

---

### Waarvoor wij je gegevens gebruiken
- Voor accountbeheer en inloggen  
- Om voorspellingen, standen en ranglijsten te tonen  
- Voor verbetering van de app en beveiliging  
- Om aan wettelijke verplichtingen te voldoen  

Wij gebruiken geen gegevens voor advertenties van derden.

---

### Bewaartermijn
Je gegevens blijven bewaard zolang je account actief is.  
Na verwijdering van je account worden je gegevens binnen 30 dagen verwijderd.  
Back-ups kunnen nog tot 90 dagen bewaard blijven.

---

### Delen met derden
Wij delen gegevens alleen met:
- **Firebase (Google Ireland Ltd.)** – voor hosting, database en beveiliging  
- **Cloud Functions** – voor automatische verwerking van voorspellingen  

Wij verkopen je gegevens nooit.

---

### Beveiliging
Wij gebruiken HTTPS, versleutelde opslag en beperkte toegang voor beheerders.

---

### Jouw rechten
Je hebt recht op inzage, correctie of verwijdering van je gegevens.  
Mail je verzoek naar **privacy.derdediv@gmail.com** met onderwerp *Privacyverzoek*.

---

### Cookies
Alleen functionele en analytische cookies (Firebase).  
Geen tracking of advertenties.

---

### Contact
Voor algemene vragen kun je mailen naar **DerdeDiv@gmail.com**.  
Voor privacyvragen kun je mailen naar **privacy.derdediv@gmail.com**.

---

### Wijzigingen
De meest recente versie van deze verklaring staat altijd in de app.  
Er is geen aparte website; communicatie verloopt via onze app, X-account en bovenstaande e-mailadressen.
''';

  // --------------------------------------------------------------------------
  // ⚙️ Inhoud: Gebruiksvoorwaarden
  // --------------------------------------------------------------------------
  final String _voorwaardenTekst = '''
Door gebruik te maken van de web-app van **Derde Divisie** ga je akkoord met deze gebruiksvoorwaarden.

---

### Gebruik van de app
- De app is bedoeld voor het voorspellen van wedstrijden en het bekijken van standen en statistieken.  
- Je bent verantwoordelijk voor de juistheid van je eigen gegevens en voorspellingen.  
- Misbruik, meerdere accounts of ongepast gedrag kunnen leiden tot blokkering van je account.  
- De inhoud van de app mag niet worden gekopieerd, gedeeld of gewijzigd zonder toestemming van Derde Divisie.

---

### Aansprakelijkheid
- Wij streven naar correcte en actuele informatie, maar kunnen fouten of onvolledigheden niet volledig uitsluiten.  
- Derde Divisie is niet aansprakelijk voor schade die voortvloeit uit het gebruik van deze app of de inhoud ervan.

---

### Accounts
- Wachtwoorden worden versleuteld opgeslagen.  
- Je bent zelf verantwoordelijk voor de beveiliging van je inloggegevens.  
- Derde Divisie kan accounts verwijderen bij misbruik of langdurige inactiviteit.

---

### Communicatie
Wij hebben geen officiële website.  
Voor vragen of meldingen kun je contact opnemen via:
📧 **DerdeDiv@gmail.com**

---

### Wijzigingen
Wij kunnen deze gebruiksvoorwaarden aanpassen als de app of wetgeving verandert.  
De meest recente versie staat altijd in de app.
''';

  // --------------------------------------------------------------------------
  // ⚠️ Inhoud: Disclaimer
  // --------------------------------------------------------------------------
  final String _disclaimerTekst = '''
De informatie in deze web-app is met zorg samengesteld.  
Desondanks kan het voorkomen dat gegevens, uitslagen of standen onjuist of onvolledig zijn.  
Aan de inhoud van deze app kunnen **geen rechten** worden ontleend.

De officiële competitiestanden en uitslagen zijn leidend zoals gepubliceerd door de KNVB of andere bevoegde instanties.

Derde Divisie aanvaardt geen aansprakelijkheid voor directe of indirecte schade die voortvloeit uit het gebruik van de app of de daarin weergegeven informatie.

Voor contact over foutieve gegevens of verbeteringen kun je mailen naar **DerdeDiv@gmail.com**.
''';
}
