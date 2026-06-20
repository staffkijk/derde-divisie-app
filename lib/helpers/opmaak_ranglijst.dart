// lib/helpers/opmaak_ranglijst.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔹 Vormberekening per team (laatste 5 wedstrijden op basis van Firestore)
Future<List<String>> bepaalVorm(String teamCode, String competitie) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Haal alle verwerkte wedstrijden op binnen de juiste divisie
    final snapshot = await firestore
        .collection('matches')
        .where('competitie', isEqualTo: competitie)
        .where('verwerkt', isEqualTo: true)
        .get();

    final alleWedstrijden = snapshot.docs.map((d) => d.data()).toList();

    // Normaliseer de teamcode: lowercase, zonder spaties of accenten
    final normalizedCode =
        teamCode.replaceAll(' ', '').replaceAll("'", '').toLowerCase();

    // Filter wedstrijden van dit team (thuis of uit)
    final teamMatches = alleWedstrijden.where((m) {
      final homeCode =
          (m['homeTeamCode'] ?? '').toString().toLowerCase();
      final awayCode =
          (m['awayTeamCode'] ?? '').toString().toLowerCase();
      return homeCode == normalizedCode || awayCode == normalizedCode;
    }).toList();

    // Sorteer op datum (nieuwste eerst)
    teamMatches.sort((a, b) {
      final da = a['datum'] is Timestamp
          ? (a['datum'] as Timestamp).toDate()
          : DateTime.now();
      final db = b['datum'] is Timestamp
          ? (b['datum'] as Timestamp).toDate()
          : DateTime.now();
      return db.compareTo(da);
    });

    // Bepaal de laatste 5 resultaten (nieuwste links)
    final laatsteVijf = teamMatches.take(5).map((m) {
      final isThuis = (m['homeTeamCode'] ?? '').toString().toLowerCase() ==
          normalizedCode;
      final thuisGoals = m['uitslagThuis'] ?? 0;
      final uitGoals = m['uitslagUit'] ?? 0;
      final diff = isThuis
          ? (thuisGoals - uitGoals)
          : (uitGoals - thuisGoals);
      if (diff > 0) return 'W';
      if (diff == 0) return 'G';
      return 'V';
    }).toList();

    return laatsteVijf;
  } catch (e) {
    debugPrint('⚠️ Fout bij berekenen van vorm voor $teamCode: $e');
    return [];
  }
}

/// 🔹 Widget voor vormweergave (5 gekleurde blokjes)
Widget vormVakjes(List<String> vorm) {
  return Row(
    children: vorm.map((v) {
      Color kleur;
      switch (v) {
        case 'W':
          kleur = Colors.green;
          break;
        case 'G':
          kleur = Colors.orange;
          break;
        case 'V':
          kleur = Colors.red;
          break;
        default:
          kleur = Colors.grey.shade400;
      }
      return Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: kleur,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }).toList(),
  );
}

/// 🔹 Helper om periodekampioen te markeren
String markeerPeriodeKampioen(String clubNaam, List<String> periodeKampioenen) {
  return periodeKampioenen.contains(clubNaam) ? '$clubNaam 🏅' : clubNaam;
}
