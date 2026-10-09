import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eindstandpunten gebruiken wedstrijden uit het actieve seizoen', () {
    final source = File(
      'lib/Puntensysteem/eindstand_puntenverwerker.dart',
    ).readAsStringSync();

    expect(source, contains("httpsCallable('processFinalStandings')"));
    final server = File('functions/src/final-points.ts').readAsStringSync();
    expect(server, contains(r'seasons/${ACTIVE_SEASON}/matches'));
    expect(server, contains('runTransaction'));
    expect(source, isNot(contains("collection('matches')")));
    expect(server, contains('punten_A'));
    expect(server, contains('punten_B'));
    expect(server, contains('Math.max(a, b)'));
  });
}
