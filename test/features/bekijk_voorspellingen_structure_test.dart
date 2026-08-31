import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/features/voorspellen/bekijk_voorspellingen_screen.dart')
          .readAsStringSync();

  test('laadflow stopt altijd en biedt een retry zonder technische fout', () {
    expect(source, contains('finally'));
    expect(source, contains('if (mounted) setState(() => geladen = true)'));
    expect(source, contains('De voorspellingen konden niet worden geladen.'));
    expect(source, contains('Opnieuw proberen'));
  });

  test(
      'actueel seizoen is primair en legacy wordt per wedstrijd gededupliceerd',
      () {
    expect(source, contains('SeasonPaths.currentSeasonPredictions'));
    expect(source, contains('SeasonPaths.currentSeasonMatches'));
    expect(source, contains('byMatch.putIfAbsent'));
    expect(source, contains("collection('voorspellingen')"));
  });

  test('wedstrijdmetadata wordt eenmalig in bulk geladen en lokaal hergebruikt',
      () {
    expect(source, contains('Map<String, Map<String, dynamic>>? _matchesById'));
    expect(source, contains('SeasonPaths.currentSeasonMatches.get()'));
    expect(source, contains('final m = matches[wedstrijdId]'));
    expect(
        source, isNot(contains('currentSeasonMatches.doc(wedstrijdId).get()')));
  });

  test('wedstrijd- en eindstandlogo gebruiken dezelfde centrale widget', () {
    expect(RegExp(r'TeamLogo\(teamName:').allMatches(source), hasLength(2));
    expect(source, isNot(contains('String getLogoPath')));
  });
  test('alleen ondersteunde eindstandcollectie wordt gelezen', () {
    expect(source, contains("'eindstand_voorspellingen'"));
    expect(source, isNot(contains("'eindstandVoorspellingen'")));
    expect(source, contains('Geen zichtbare eindstand-voorspelling.'));
  });

  test('actuele en noodzakelijke legacy matchvelden worden veilig gelezen', () {
    for (final field in [
      'homeTeamName',
      'awayTeamName',
      'homeScore',
      'awayScore',
      'round',
      'division',
      'kickoff',
      'thuisteam',
      'uitteam',
      'speelronde',
      'competitie'
    ]) {
      expect(source, contains(field));
    }
    expect(source, contains('value is num ? value.toInt()'));
  });
}
