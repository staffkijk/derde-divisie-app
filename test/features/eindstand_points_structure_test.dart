import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eindstandpunten gebruiken wedstrijden uit het actieve seizoen', () {
    final source = File(
      'lib/Puntensysteem/eindstand_puntenverwerker.dart',
    ).readAsStringSync();

    expect(source, contains('SeasonPaths.currentSeasonMatches'));
    expect(source, isNot(contains("collection('matches')")));
    expect(source, contains("'punten_A' : 'punten_B'"));
    expect(source, contains("{'totalen': hoogste}"));
  });
}
