import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy algemene puntenverwerker heeft geen productieaanroepers', () {
    const legacyPath = 'lib/Puntensysteem/puntenverwerker.dart';
    const forbiddenSymbols = <String>[
      'verwerkUitslagVoorWedstrijd(',
      'verwerkVoorspellingenVoorWedstrijd(',
      'draaiVoorspellingenVoorWedstrijdTerug(',
      'resetWedstrijd(',
    ];

    final offenders = <String>[];
    final lib = Directory('lib');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized == legacyPath) continue;

      final source = entity.readAsStringSync();
      final importsLegacy = source.contains(
        'package:derde_divisie/Puntensysteem/puntenverwerker.dart',
      );
      final callsLegacy = forbiddenSymbols.any(source.contains);
      if (importsLegacy || callsLegacy) offenders.add(normalized);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Algemene wedstrijdpunten moeten uitsluitend via GeneralPredictionPointsService lopen. '
          'De legacy puntenverwerker mag niet opnieuw aan een productiepad worden gekoppeld.',
    );
  });
}
