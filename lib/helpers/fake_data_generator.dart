// lib/screens/admin/seed_bulk_fake_v2_screen.dart
//
// Admin-only tool: bulk fake accounts + retro & future predictions met strikte regels.
// (versie aangepast: Dart/client Firestore heeft geen `listCollections()`; we verwijderen
// subcollecties op basis van een lijst van bekende subcollectie-namen)
// ignore_for_file: unused_element

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SeedBulkFakeV2Screen extends StatefulWidget {
  const SeedBulkFakeV2Screen({super.key});

  @override
  State<SeedBulkFakeV2Screen> createState() => _SeedBulkFakeV2ScreenState();
}

class _SeedBulkFakeV2ScreenState extends State<SeedBulkFakeV2Screen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _rnd = Random();

  bool _running = false;
  String _status = '';

  // -------- helpers --------

  String _compLabel(String ab) =>
      (ab == 'A') ? 'Derde Divisie A' : 'Derde Divisie B';

  String _randomUsername(String first, String last, int idx) {
    final c = _rnd.nextInt(4);
    if (c == 0) return '${first.toLowerCase()}${last.toLowerCase()}$idx';
    if (c == 1) return '${first.toLowerCase()}_${_rnd.nextInt(999)}';
    if (c == 2) return '${first.toLowerCase()}${_rnd.nextInt(999)}';
    return '${first.toLowerCase()}${last[0].toLowerCase()}${_rnd.nextInt(999)}';
  }

  String _randomEmail(String username, int idx) =>
      '${username}_${idx}_${_rnd.nextInt(99999)}@example.com';

  // Verdeling competities: 65% A, 10% A+B, 25% B
  List<String> _assignCompetitions() {
    final p = _rnd.nextDouble() * 100;
    if (p < 65) return ['A'];
    if (p < 75) return ['A', 'B'];
    return ['B'];
  }

  // (optioneel) teamlogo’s per comp (teams-collectie gebruikt 'competition': 'A'|'B')
  Future<List<String>> _fetchTeamLogos(String competitionAB) async {
    try {
      final snap = await _firestore
          .collection('teams')
          .where('competition', isEqualTo: competitionAB)
          .get();
      return snap.docs
          .map((d) => (d.data()['logoUrl'] as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // cap = punten van 5e echte speler - 1 (per competitieveld)
  Future<Map<String, int>> _fetchCapsAandB() async {
    int capA = 500, capB = 500;

    try {
      final snapA = await _firestore
          .collection('users')
          .where('isFake', isEqualTo: false)
          .orderBy('punten_A', descending: true)
          .limit(5)
          .get();
      if (snapA.docs.isNotEmpty) {
        final fifthA = snapA.docs.length == 5
            ? (snapA.docs.last.data()['punten_A'] ?? 0) as int
            : (snapA.docs.first.data()['punten_A'] ?? 0) as int;
        capA = max(0, fifthA - 1);
        if (capA <= 0) capA = 500;
      }
    } catch (_) {
      capA = 500;
    }

    try {
      final snapB = await _firestore
          .collection('users')
          .where('isFake', isEqualTo: false)
          .orderBy('punten_B', descending: true)
          .limit(5)
          .get();
      if (snapB.docs.isNotEmpty) {
        final fifthB = snapB.docs.length == 5
            ? (snapB.docs.last.data()['punten_B'] ?? 0) as int
            : (snapB.docs.first.data()['punten_B'] ?? 0) as int;
        capB = max(0, fifthB - 1);
        if (capB <= 0) capB = 500;
      }
    } catch (_) {
      capB = 500;
    }

    return {'A': capA, 'B': capB};
  }

  // Pseudo-voorspelling per wedstrijd
  Map<String, int> _generatePredictionForMatch(
    String userId,
    QueryDocumentSnapshot matchDoc,
  ) {
    final m = matchDoc.data() as Map<String, dynamic>;
    final seed = '$userId|${matchDoc.id}|${m['thuisteam']}|${m['uitteam']}';
    final rng = _rngFor(seed);
    final r = rng.nextDouble();
    int homeGoals, awayGoals;
    if (r < 0.25) {
      homeGoals = 1 + rng.nextInt(2); // 1-2
      awayGoals = rng.nextInt(2); // 0-1
    } else if (r < 0.5) {
      homeGoals = rng.nextInt(3); // 0-2
      awayGoals = rng.nextInt(3);
    } else if (r < 0.8) {
      homeGoals = rng.nextInt(4); // 0-3
      awayGoals = rng.nextInt(4);
    } else {
      homeGoals = 2 + rng.nextInt(3); // 2-4
      awayGoals = 1 + rng.nextInt(3); // 1-3
    }
    return {'homeGoals': homeGoals, 'awayGoals': awayGoals};
  }

  Random _rngFor(String seed) {
    int h = 0;
    for (final c in seed.codeUnits) {
      h = 0x1fffffff & (h + c);
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= (h >> 6);
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= (h >> 11);
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    return Random(h);
  }

  int _calcPoints({
    required int predHome,
    required int predAway,
    required int realHome,
    required int realAway,
  }) {
    int pts = 0;
    if (predHome == realHome && predAway == realAway) pts += 10;

    final predDiff = predHome - predAway;
    final realDiff = realHome - realAway;
    final predRes = predDiff == 0 ? 0 : (predDiff > 0 ? 1 : -1);
    final realRes = realDiff == 0 ? 0 : (realDiff > 0 ? 1 : -1);

    if (!(predHome == realHome && predAway == realAway)) {
      if (predRes == 0 && realRes == 0) {
        pts += 7; // gelijkspel goed
      } else if (predRes == realRes) {
        pts += 5; // winnaar goed
      }
    }
    if (predAway == realAway) pts += 2; // exact uit-score
    if (predHome == realHome) pts += 2; // exact thuis-score
    return pts;
  }

  bool _isAdminUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    const admins = ['ngijs@icloud.com', 'admin@voorbeeld.nl'];
    return admins.contains(user.email);
  }

  // -------- data helpers --------

  // Alle matches per competitie
  Future<List<QueryDocumentSnapshot>> _fetchMatchesByCompetition(
      String ab) async {
    final snap = await _firestore
        .collection('matches')
        .where('competitie', isEqualTo: _compLabel(ab))
        .get();
    return snap.docs;
  }

  // Verdeel matches per ronde en pak exact 9 per ronde (indien beschikbaar)
  Map<int, List<QueryDocumentSnapshot>> _groupRoundsPickNine(
      List<QueryDocumentSnapshot> matches,
      {bool onlyFinished = false}) {
    final byRound = <int, List<QueryDocumentSnapshot>>{};
    for (final m in matches) {
      final d = m.data() as Map<String, dynamic>;
      final hasResult = d['uitslagThuis'] != null && d['uitslagUit'] != null;
      if (onlyFinished && !hasResult) continue;
      if (!onlyFinished && hasResult) {
        continue; // voor future: alleen zonder uitslag
      }
      final r = (d['speelronde'] ?? 0) as int;
      byRound.putIfAbsent(r, () => []);
      byRound[r]!.add(m);
    }

    // sorteer binnen ronde op datum en neem max 9
    final result = <int, List<QueryDocumentSnapshot>>{};
    for (final entry in byRound.entries) {
      final list = [...entry.value];
      list.sort((a, b) {
        final da = (a.data() as Map<String, dynamic>)['datum'];
        final db = (b.data() as Map<String, dynamic>)['datum'];
        final ta = (da is Timestamp) ? da.toDate().millisecondsSinceEpoch : 0;
        final tb = (db is Timestamp) ? db.toDate().millisecondsSinceEpoch : 0;
        return ta.compareTo(tb);
      });
      result[entry.key] = list.length <= 9 ? list : list.sublist(0, 9);
    }
    return result;
  }

  Future<bool> _predictionExists(String userId, String matchId) async {
    final id = '${userId}_$matchId';
    final doc = await _firestore.collection('voorspellingen').doc(id).get();
    return doc.exists;
  }

  // ----------------- ACTIES -----------------

// ----------------- NIEUWE VERSIE _createAccounts() -----------------
  Future<void> _createAccounts({int count = 60}) async {
    setState(() {
      _running = true;
      _status =
          'Aanmaken van $count realistische fake accounts (met NL woonplaatsen)...';
    });

    try {
      final logosA = await _fetchTeamLogos('A');
      final logosB = await _fetchTeamLogos('B');

      // --- Naamdata ---
      final firstNames = [
        'Mark',
        'Joris',
        'Femke',
        'Ruben',
        'Lisa',
        'Kees',
        'Marieke',
        'Daan',
        'Noa',
        'Lotte',
        'Bas',
        'Sanne',
        'Jelle',
        'Myrthe',
        'Timo',
        'Anna',
        'Pieter',
        'Iris',
        'Roel',
        'Sophie',
        'Bram',
        'Eva',
        'Nick',
        'Lars',
        'Milan',
        'Romy',
        'Wouter',
        'Eline',
        'Thijs',
        'Nina',
        'Martijn',
        'Henk',
        'Johan',
        'Stefan',
        'Tom',
        'Rick',
        'Joost',
        'Gerard',
        'Dennis',
        'Frank',
        'Jantje',
        'Harm',
        'Niels',
        'Koen',
        'Arjan',
        'Dirk',
        'Pascal',
        'Tim',
        'Floor',
        'Stijn',
        'Elise',
        'Maarten',
        'Lieke',
        'Rosa',
        'Niek',
        'Sil',
        'Matthijs',
        'Sander',
        'Leonie',
        'Nadine'
      ];

      final lastNames = [
        'Jansen',
        'DeVries',
        'VanDijk',
        'Bakker',
        'Visser',
        'Smit',
        'Meijer',
        'Mulder',
        'Bos',
        'Kramer',
        'Kuiper',
        'Vos',
        'DeBoer',
        'Hendriks',
        'Peters',
        'Dekker',
        'VanDam',
        'Post',
        'Prins',
        'Verhoef',
        'DeGroot',
        'VanLeeuwen',
        'Hoekstra',
        'Koster',
        'Vermeer',
        'DeBruin',
        'VanLoon',
        'DeWit',
        'Groen',
        'Peeters',
        'Blom'
      ];

      // Clubs (voor username-tags of referenties)
      final clubTags = [
        'DVS',
        'TEC',
        'UNA',
        'VVSB',
        'DOVO',
        'HSC21',
        'ASWH',
        'Goes',
        'Urk',
        'FCU',
        'BlauwGeel',
        'RBC',
        'Gemert',
        'Hercules',
        'SteDoCo',
        'Sparta',
        'SCGenemuiden',
        'Rijnvogels',
        'Noordwijk',
        'Eemdijk',
        'Hoogeveen',
        'HarkemaseBoys',
        'Kloetinge',
        'ADO20',
        'Lisse'
      ];

      // Gemeenten (NL) — verkorte lijst, maar je kunt makkelijk uitbreiden
      final woonplaatsen = [
        'Amsterdam',
        'Rotterdam',
        'Den Haag',
        'Utrecht',
        'Eindhoven',
        'Tilburg',
        'Groningen',
        'Almere',
        'Breda',
        'Nijmegen',
        'Enschede',
        'Apeldoorn',
        'Haarlem',
        'Amersfoort',
        'Arnhem',
        'Zaanstad',
        'Den Bosch',
        'Zwolle',
        'Leeuwarden',
        'Maastricht',
        'Dordrecht',
        'Leiden',
        'Ede',
        'Leidschendam',
        'Emmen',
        'Alkmaar',
        'Assen',
        'Helmond',
        'Deventer',
        'Venlo',
        'Gouda',
        'Veenendaal',
        'Rijswijk',
        'Roermond',
        'Tiel',
        'Wierden',
        'Barneveld',
        'Zeist',
        'Epe',
        'Hengelo',
        'Oldenzaal',
        'Zutphen',
        'Meppel',
        'Hoogeveen',
        'Sneek',
        'Raalte',
        'Genemuiden',
        'Urk',
        'Rijnsburg',
        'Noordwijk',
        'Katwijk',
        'Hoorn',
        'Purmerend',
        'Harderwijk',
        'Lelystad',
        'Heerenveen',
        'Oss',
        'Doetinchem',
        'Hilversum',
        'Vught'
      ];

      final usersCol = _firestore.collection('users');
      var batch = _firestore.batch();
      var inBatch = 0;
      var created = 0;

      for (int i = 0; i < count; i++) {
        final first = firstNames[_rnd.nextInt(firstNames.length)];
        final last = lastNames[_rnd.nextInt(lastNames.length)];
        final displayName = '$first $last';
        final email =
            '${first.toLowerCase()}_${last.toLowerCase()}_${_rnd.nextInt(99999)}@example.com';

        final competitions = _assignCompetitions();
        final favComp = _compLabel(competitions.first);
        final isIdle = _rnd.nextDouble() < 0.08; // ~8% geen voorspellingen
        final showPreds = true;
        final woonplaats = woonplaatsen[_rnd.nextInt(woonplaatsen.length)];
        final clubTag = clubTags[_rnd.nextInt(clubTags.length)];

        // ----------- UNIEKE / REALISTISCHE USERNAME ------------
        String username;
        final style = _rnd.nextDouble();

        if (style < 0.25) {
          // voornaam + geboortejaar
          final year = 1970 + _rnd.nextInt(35);
          username = '$first$year';
        } else if (style < 0.45) {
          // kleine letters + club verwijzing
          final suffixes = ['fan', 'sup', 'boy', 'girl', 'support', 'rules'];
          username =
              '${clubTag.toLowerCase()}${suffixes[_rnd.nextInt(suffixes.length)]}';
        } else if (style < 0.65) {
          // korte versie met random nummer of underscore
          final base =
              '${first.toLowerCase()}${last.substring(0, 1).toLowerCase()}';
          if (_rnd.nextBool()) {
            username = '$base$_rnd.nextInt(999)';
          } else {
            username = '${base}_${_rnd.nextInt(99)}';
          }
        } else if (style < 0.85) {
          // speelse naam zoals jantjuhh01
          final endings = ['juh', 'uhh', 'ie', 'tje', 'zz', 'xx'];
          username =
              '${first.toLowerCase()}${endings[_rnd.nextInt(endings.length)]}${_rnd.nextInt(99).toString().padLeft(2, '0')}';
        } else {
          // naam + clubtag gecombineerd
          username = '$first$clubTag';
          if (_rnd.nextDouble() < 0.4) username += '${_rnd.nextInt(99)}';
        }

        // --------------- PROFIELAFBEELDING ---------------
        String avatarUrl =
            'https://firebasestorage.googleapis.com/v0/b/derde-divisie-app.firebasestorage.app/o/avatars%2Fstandaard%20profielfoto.webp?alt=media&token=b5137dac-fae6-445a-a4f2-d7e083fadbf7';

        // 5% kans clublogo ipv standaard
        if (_rnd.nextDouble() < 0.05) {
          final compForAvatar = competitions[_rnd.nextInt(competitions.length)];
          final pool = compForAvatar == 'A' ? logosA : logosB;
          if (pool.isNotEmpty) avatarUrl = pool[_rnd.nextInt(pool.length)];
        }

        final ref = usersCol.doc();
        batch.set(ref, {
          'displayName': displayName,
          'username': username,
          'email': email,
          'avatarUrl': avatarUrl,
          'punten_A': 0,
          'punten_B': 0,
          'totalen': 0,
          'predictionsMade': 0,
          'competitions': competitions,
          'isFake': true,
          'isIdle': isIdle,
          'joinedAt': FieldValue.serverTimestamp(),
          'ranglijstZichtbaar': false,
          'voorspellingenZichtbaar': showPreds,
          // profiel
          'eigenPoules': 0,
          'gejoinedePoules': 0,
          'favorieteClub': null,
          'favorieteCompetitie': favComp,
          'woonplaats': woonplaats,
          'heeftGebruikersnaamGewijzigd': false,
          'usernameChanged': true,
          'isModerator': false,
          'profileDescription': '',
        });

        inBatch++;
        created++;
        if (inBatch >= 300) {
          await batch.commit();
          batch = _firestore.batch();
          inBatch = 0;
        }
      }

      if (inBatch > 0) await batch.commit();

      setState(() =>
          _status = 'Klaar — $created realistische fake accounts aangemaakt.');
    } catch (e) {
      setState(() => _status = 'Fout bij aanmaken accounts: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  // 2) Retro: voorspellingen + punten toepassen, met cap per competitie
  //    - Alleen voor actieve fake users (isIdle == false)
  //    - Per competitie overslaan als user al punten heeft
  //    - Per wedstrijd eerst check of voorspelling bestaat; zo ja -> overslaan
  Future<void> _retroPredictAndScore() async {
    setState(() {
      _running = true;
      _status = 'Retro: voorspellingen genereren + punten toepassen...';
    });

    try {
      final caps = await _fetchCapsAandB();
      final capA = caps['A'] ?? 500;
      final capB = caps['B'] ?? 500;

      final usersSnap = await _firestore
          .collection('users')
          .where('isFake', isEqualTo: true)
          .where('isIdle', isEqualTo: false)
          .get();

      if (usersSnap.docs.isEmpty) {
        setState(() {
          _status = 'Geen geschikte fake accounts gevonden.';
          _running = false;
        });
        return;
      }

      // finished matches per comp -> per ronde maximaal 9
      final finishedByComp = <String, Map<int, List<QueryDocumentSnapshot>>>{};
      for (final comp in ['A', 'B']) {
        final all = await _fetchMatchesByCompetition(comp);
        finishedByComp[comp] =
            _groupRoundsPickNine(all, onlyFinished: true); // exact 9 per ronde
      }

      for (final u in usersSnap.docs) {
        final data = u.data();
        final userId = u.id;
        final comps = (data['competitions'] as List?)?.cast<String>() ?? ['A'];

        var curA = (data['punten_A'] ?? 0) as int;
        var curB = (data['punten_B'] ?? 0) as int;

        for (final comp in comps) {
          // Als user in deze competitie al punten heeft, overslaan (eis)
          if (comp == 'A' && curA > 0) continue;
          if (comp == 'B' && curB > 0) continue;

          final matchesByRound = finishedByComp[comp] ?? const {};
          for (final round in matchesByRound.keys.toList()..sort()) {
            final matches = matchesByRound[round]!;
            for (final m in matches) {
              // dubbele verwerking voorkomen
              if (await _predictionExists(userId, m.id)) continue;

              final pred = _generatePredictionForMatch(userId, m);
              final md = m.data() as Map<String, dynamic>;
              final realHome = (md['uitslagThuis'] as num).toInt();
              final realAway = (md['uitslagUit'] as num).toInt();

              final pts = _calcPoints(
                predHome: pred['homeGoals']!,
                predAway: pred['awayGoals']!,
                realHome: realHome,
                realAway: realAway,
              );

              final isA = comp == 'A';
              final cap = isA ? capA : capB;
              final current = isA ? curA : curB;
              if (current >= cap) continue;

              var apply = pts;
              final room = cap - current;
              if (apply > room) apply = room;

              final docId = '${userId}_${m.id}';
              await _firestore.collection('voorspellingen').doc(docId).set({
                'gebruikerId': userId,
                'wedstrijdId': m.id,
                'scoreThuis': pred['homeGoals'],
                'scoreUit': pred['awayGoals'],
                'timestamp': FieldValue.serverTimestamp(),
                'punten': apply,
                'verwerkt': true,
                'verwerktVoorUitslag': '$realHome-$realAway',
                'isFake': true,
              }, SetOptions(merge: true));

              final userRef = _firestore.collection('users').doc(userId);
              final veld = isA ? 'punten_A' : 'punten_B';
              await userRef.set(
                  {veld: FieldValue.increment(apply)}, SetOptions(merge: true));
              await userRef.set({'predictionsMade': FieldValue.increment(1)},
                  SetOptions(merge: true));

              if (isA) {
                curA += apply;
              } else {
                curB += apply;
              }
              final total = max(curA, curB);
              await userRef.set({'totalen': total}, SetOptions(merge: true));
            }
          }
        }
      }

      setState(() =>
          _status = 'Retro klaar — punten toegepast onder cap, geen dubbelen.');
    } catch (e) {
      setState(() => _status = 'Fout bij retro: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  // 3) Future: maak voorspellingen (zonder punten), nooit dubbel en alleen actief
  Future<void> _predictRemainingConsideringPoints() async {
    setState(() {
      _running = true;
      _status = 'Toekomst voorspellen (zonder punten)...';
    });

    try {
      final usersSnap = await _firestore
          .collection('users')
          .where('isFake', isEqualTo: true)
          .where('isIdle', isEqualTo: false)
          .get();

      if (usersSnap.docs.isEmpty) {
        setState(() {
          _status = 'Geen geschikte fake accounts gevonden.';
          _running = false;
        });
        return;
      }

      // upcoming per comp & ronde (exact 9 per ronde)
      final upcomingByComp = <String, Map<int, List<QueryDocumentSnapshot>>>{};
      for (final comp in ['A', 'B']) {
        final all = await _fetchMatchesByCompetition(comp);
        upcomingByComp[comp] = _groupRoundsPickNine(all, onlyFinished: false);
      }

      var created = 0;
      var batch = _firestore.batch();
      var inBatch = 0;

      for (final u in usersSnap.docs) {
        final data = u.data();
        final userId = u.id;
        final comps = (data['competitions'] as List?)?.cast<String>() ?? ['A'];

        for (final comp in comps) {
          final rounds = upcomingByComp[comp] ?? const {};
          for (final round in rounds.keys.toList()..sort()) {
            final matches = rounds[round]!;
            for (final m in matches) {
              // dubbele voorkomen
              final exists = await _predictionExists(userId, m.id);
              if (exists) continue;

              final pred = _generatePredictionForMatch(userId, m);
              final docId = '${userId}_${m.id}';
              final pr = _firestore.collection('voorspellingen').doc(docId);
              batch.set(
                  pr,
                  {
                    'gebruikerId': userId,
                    'wedstrijdId': m.id,
                    'scoreThuis': pred['homeGoals'],
                    'scoreUit': pred['awayGoals'],
                    'timestamp': FieldValue.serverTimestamp(),
                    'verwerkt': false,
                    'isFake': true,
                  },
                  SetOptions(merge: true));

              batch.set(
                  _firestore.collection('users').doc(userId),
                  {
                    'predictionsMade': FieldValue.increment(1),
                  },
                  SetOptions(merge: true));

              created++;
              inBatch++;
              if (inBatch >= 300) {
                await batch.commit();
                batch = _firestore.batch();
                inBatch = 0;
              }
            }
          }
        }
      }

      if (inBatch > 0) await batch.commit();

      setState(() => _status =
          'Toekomst-voorspellingen aangemaakt (zonder dubbelen): $created.');
    } catch (e) {
      setState(() => _status = 'Fout bij toekomst-voorspellen: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  // Legacy knop laten staan (geen functionaliteit in nieuwe flow)
  Future<void> _weeklyApplyScoring() async {
    setState(() {
      _running = true;
      _status =
          'Wekelijkse run (legacy) — in nieuwe flow doet puntenverwerker dit.';
    });
    setState(() => _running = false);
  }

  // 4) Opschonen: verwijder fake voorspellingen + oude predictions + fake users (inclusief subcollecties)
  Future<void> _deleteAllFakeData() async {
    setState(() {
      _running = true;
      _status =
          'Verwijderen fake users + voorspellingen (incl. subcollecties)…';
    });

    try {
      // In Flutter Firestore: listCollections() op DocumentReference bestaat niet.
      // Daarom werken we met een lijst van bekende subcollectienamen die je in je project gebruikt.
      // Pas deze lijst aan als je extra subcollecties hebt.
      Future<void> deleteSubcollections(DocumentReference docRef) async {
        // Voeg hier subcollecties toe die je onder users gebruikt.
        final knownSubcollections = <String>[
          'voorspellingen',
          'predictions',
          'poule_predictions',
          'poule_voorspellingen',
          'poules',
          'eigen_poules',
          'joined_poules',
          'user_settings',
          'sync_logs',
          // voeg meer namen toe indien nodig
        ];

        for (final name in knownSubcollections) {
          final subCol = docRef.collection(name);
          try {
            final snapshot = await subCol.get();
            if (snapshot.docs.isEmpty) continue;

            var batch = _firestore.batch();
            var inBatch = 0;
            for (final d in snapshot.docs) {
              batch.delete(d.reference);
              inBatch++;
              if (inBatch >= 300) {
                await batch.commit();
                batch = _firestore.batch();
                inBatch = 0;
              }
            }
            if (inBatch > 0) await batch.commit();
          } catch (e) {
            // negeren per subcollectie, maar log status
            // (we willen dat het proces doorloopt voor de andere subcollecties)
            // eventueel setState met foutmelding als je dat wilt
          }
        }
      }

      // nieuwe voorspellingen
      var snap = await _firestore
          .collection('voorspellingen')
          .where('isFake', isEqualTo: true)
          .get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }

      // oude predictions (indien aanwezig)
      snap = await _firestore
          .collection('predictions')
          .where('isFake', isEqualTo: true)
          .get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }

      // users + subcollecties
      final usersSnap = await _firestore
          .collection('users')
          .where('isFake', isEqualTo: true)
          .get();
      for (final userDoc in usersSnap.docs) {
        await deleteSubcollections(userDoc.reference);
        await userDoc.reference.delete();
      }

      setState(() => _status = 'Alle fake data verwijderd.');
    } catch (e) {
      setState(() => _status = 'Verwijderen mislukt: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  // 5) Sanitize: verwijder eventueel verouderd veld "points" uit fake users
  Future<void> _sanitizeRemovePointsField() async {
    setState(() {
      _running = true;
      _status = 'Sanitize: verwijder "points" bij fake users…';
    });

    try {
      final snap = await _firestore
          .collection('users')
          .where('isFake', isEqualTo: true)
          .get();
      var updated = 0;
      for (final d in snap.docs) {
        final data = d.data();
        if (data.containsKey('points')) {
          await d.reference.update({'points': FieldValue.delete()});
          updated++;
        }
      }
      setState(() => _status = 'Sanitize klaar — $updated users opgeschoond.');
    } catch (e) {
      setState(() => _status = 'Sanitize mislukt: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdminUser();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Bulk fake accounts v2')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isAdmin
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bulk fake accounts + retro & future predictions.\n'
                      'Default: niet zichtbaar in ranglijst, ~8% idle.\n'
                      'Distributie: 65% A, 10% A+B, 25% B.\n'
                      'Nooit dubbelen (per wedstrijd check) en per comp overslaan bij bestaande punten.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          _running ? null : () => _createAccounts(count: 30),
                      child: const Text('Stap 1: Maak ~30 accounts'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _running ? null : _retroPredictAndScore,
                      child: const Text(
                        'Stap 2: Retro voorspellen + punten toepassen (cap per competitie)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed:
                          _running ? null : _predictRemainingConsideringPoints,
                      child: const Text(
                          'Stap 3: Toekomst voorspellen (zonder punten)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _running ? null : _weeklyApplyScoring,
                      child: const Text('Wekelijkse run (legacy)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _running ? null : _deleteAllFakeData,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      child: const Text('Verwijder alle fake data'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _running ? null : _sanitizeRemovePointsField,
                      child:
                          const Text('Sanitize: verwijder oud veld "points"'),
                    ),
                    const SizedBox(height: 16),
                    if (_running) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text('Status: $_status'),
                    const SizedBox(height: 8),
                    const Text(
                      'NB: matches gebruiken NL velden: competitie="Derde Divisie A/B", '
                      'uitslagThuis/uitslagUit, speelronde, thuisteam/uitteam.',
                    ),
                  ],
                ),
              )
            : const Center(
                child: Text('Geen toegang — alleen admin/moderator')),
      ),
    );
  }
}
