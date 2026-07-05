import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/models/poule_prediction_scope.dart';
import 'package:derde_divisie/data/services/division_data_service.dart';

void main() {
  group('definitieve divisie-indeling 2026/2027', () {
    test('beide divisies bevatten exact 18 unieke clubs', () {
      final divisionA = SeasonConfig.teamsForDivision('A');
      final divisionB = SeasonConfig.teamsForDivision('B');

      expect(divisionA, hasLength(18));
      expect(divisionB, hasLength(18));
      expect(
        {...divisionA.map((team) => team.id)}
            .intersection({...divisionB.map((team) => team.id)}),
        isEmpty,
      );
    });

    test('bekende zuidelijke clubs staan in B', () {
      expect(SeasonConfig.teamById('rksv_groene_ster')?.division, 'B');
      expect(SeasonConfig.teamById('togb')?.division, 'B');
      expect(SeasonConfig.teamById('blauw_geel_38')?.division, 'B');
    });
  });

  group('divisiefilter', () {
    test('toont een B-wedstrijd nooit in A', () {
      final match = {
        'division': 'B',
        'homeTeamSlug': 'rksv_groene_ster',
        'awayTeamSlug': 'togb',
      };

      expect(
        DivisionDataService.matchBelongsToDivision(match, 'A'),
        isFalse,
      );
      expect(
        DivisionDataService.matchBelongsToDivision(match, 'B'),
        isTrue,
      );
    });

    test('blokkeert een verkeerd gelabelde kruisdivisiewedstrijd', () {
      final match = {
        'division': 'A',
        'homeTeamSlug': 'acv',
        'awayTeamSlug': 'togb',
      };

      expect(
        DivisionDataService.matchBelongsToDivision(match, 'A'),
        isFalse,
      );
    });

    test(
        'leidt een ontbrekende divisie alleen af bij twee clubs uit dezelfde divisie',
        () {
      expect(
        DivisionDataService.matchBelongsToDivision(
          {
            'homeTeamSlug': 'acv',
            'awayTeamSlug': 'vv_dovo',
          },
          'A',
        ),
        isTrue,
      );
      expect(
        DivisionDataService.matchBelongsToDivision(
          {
            'homeTeamSlug': 'acv',
            'awayTeamSlug': 'togb',
          },
          'A',
        ),
        isFalse,
      );
    });
  });

  group('standpositie binnen divisie', () {
    test('negeert verkeerd gelabelde clubs en blijft tussen 1 en 18', () {
      final standings = [
        for (var index = 0;
            index < SeasonConfig.teamsForDivision('B').length;
            index++)
          DivisionStanding(
            id: SeasonConfig.teamsForDivision('B')[index].id,
            data: {
              'teamId': SeasonConfig.teamsForDivision('B')[index].id,
              'division': 'B',
              'points': 30 - index,
              'played': 10,
            },
          ),
        const DivisionStanding(
          id: 'acv',
          data: {
            'teamId': 'acv',
            'division': 'B',
            'points': 99,
            'played': 10,
          },
        ),
      ];

      final divisionB = DivisionDataService.standingsForDivision(
        standings,
        'B',
      );
      final togbPosition =
          divisionB.indexWhere((standing) => standing.id == 'togb') + 1;

      expect(divisionB, hasLength(18));
      expect(divisionB.any((standing) => standing.id == 'acv'), isFalse);
      expect(togbPosition, inInclusiveRange(1, 18));
    });
  });

  group('poule predictionScope', () {
    test('oude documenten vallen veilig terug op wedstrijden', () {
      expect(
        parsePoulePredictionScope(null),
        PoulePredictionScope.matches,
      );
      expect(
        parsePoulePredictionScope('onbekend'),
        PoulePredictionScope.matches,
      );
    });

    test('alle ondersteunde waarden maken een roundtrip', () {
      for (final scope in PoulePredictionScope.values) {
        expect(parsePoulePredictionScope(scope.firestoreValue), scope);
      }
    });
  });
}
