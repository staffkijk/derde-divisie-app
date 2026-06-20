import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ'), backgroundColor: Colors.green),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '❓ Veelgestelde vragen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          const FaqSectionTitle(title: '📅 Voorspellen'),
          const FaqCard(
            question: 'Tot wanneer kan ik voorspellen?',
            answer: 'Tot 12:00 uur op de wedstrijddag van de eerste wedstrijd in die speelronde.',
          ),
          const FaqCard(
            question: 'Kan ik mijn voorspellingen aanpassen?',
            answer: 'Ja, zolang de deadline nog niet verstreken is.',
          ),
          const FaqCard(
            question: 'Kan ik de voorspellingen van anderen bekijken?',
            answer: 'Ja, als een gebruiker dit toestaat in zijn profiel. Na de deadline zijn alle voorspellingen zichtbaar.',
          ),

          const SizedBox(height: 24),
          const FaqSectionTitle(title: '👤 Profiel'),
          const FaqCard(
            question: 'Hoe wijzig ik mijn gebruikersnaam?',
            answer: 'Je gebruikersnaam kun je één keer aanpassen via je profielpagina.',
          ),
          const FaqCard(
            question: 'Hoe wijzig ik mijn profielfoto?',
            answer: 'Klik op je huidige profielfoto en kies een nieuwe afbeelding uit de lijst.',
          ),

          const SizedBox(height: 24),
          const FaqSectionTitle(title: '👥 Poules'),
          const FaqCard(
            question: 'Hoe maak ik een poule aan?',
            answer: 'Ga naar het tabblad "Poules", klik op "Nieuwe poule" en volg de stappen.',
          ),
          const FaqCard(
            question: 'Wat is het verschil tussen een poule met één team en een volledige poule?',
            answer: 'In een één-teampoule voorspel je alleen wedstrijden van dat ene team. In een volledige poule voorspel je het programma van een hele divisie.',
          ),

          const SizedBox(height: 24),
          const FaqSectionTitle(title: '📊 Puntentelling'),
          const FaqCard(
            question: 'Hoe werkt de puntentelling?',
            answer: 'Bekijk de volledige Puntentelling-pagina via het vraagtekenmenu.',
          ),
        ],
      ),
    );
  }
}

class FaqSectionTitle extends StatelessWidget {
  final String title;
  const FaqSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }
}

class FaqCard extends StatelessWidget {
  final String question;
  final String answer;

  const FaqCard({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q: $question',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'A: $answer',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
