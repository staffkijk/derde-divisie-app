import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/utils/match_formatters.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';

void main() {
  group('MatchDateTimeFormatter', () {
    test('combineert losse datum en aftraptijd', () {
      final result = MatchDateTimeFormatter.dateTimeFromData({
        'date': '2026-08-15',
        'kickoffTime': '14:30',
      });

      expect(result, DateTime(2026, 8, 15, 14, 30));
    });

    test('toont geen onbedoelde middernachttijd', () {
      expect(
        MatchDateTimeFormatter.publicTime({'date': '2026-08-15'}),
        'Tijd onbekend',
      );
    });

    test('sorteert binnen een datum op tijd', () {
      final early = {
        'division': 'A',
        'round': 1,
        'date': '2026-08-15',
        'kickoffTime': '14:00',
      };
      final late = {
        'division': 'A',
        'round': 1,
        'date': '2026-08-15',
        'kickoffTime': '15:00',
      };

      expect(MatchDateTimeFormatter.compare(early, late), lessThan(0));
    });

    test('corrigeert Scherpenzeel thuis zonder bevestigde tijd naar 15:00', () {
      expect(
        MatchDateTimeFormatter.publicTime({
          'season': '2026-2027',
          'homeTeamName': 'Scherpenzeel',
          'awayTeamName': 'Hoogeveen',
          'date': '2026-08-15',
          'kickoffTime': '14:30',
          'kickoffTimeConfirmed': false,
        }),
        '15:00',
      );
    });

    test('past Scherpenzeel uit niet aan', () {
      expect(
        MatchDateTimeFormatter.publicTime({
          'season': '2026-2027',
          'homeTeamName': 'DOVO',
          'awayTeamName': 'Scherpenzeel',
          'date': '2026-08-15',
          'kickoffTime': '14:30',
          'kickoffTimeConfirmed': false,
        }),
        '14:30',
      );
    });

    test('overschrijft bevestigde Scherpenzeel-thuistijd niet', () {
      expect(
        MatchDateTimeFormatter.publicTime({
          'season': '2026-2027',
          'homeTeamSlug': 'vv_scherpenzeel',
          'awayTeamName': 'Excelsior31',
          'date': '2026-08-15',
          'kickoffTime': '14:00',
          'kickoffTimeConfirmed': true,
        }),
        '14:00',
      );
    });

    test('andere thuisclub en ontbrekende tijd blijven regulier', () {
      expect(
        MatchDateTimeFormatter.publicTime({
          'season': '2026-2027',
          'homeTeamName': 'Hoogeveen',
          'awayTeamName': 'DOVO',
          'date': '2026-08-15',
        }),
        'Tijd onbekend',
      );
    });

    test('al correcte Scherpenzeel-thuistijd blijft 15:00', () {
      expect(
        MatchDateTimeFormatter.publicTime({
          'season': '2026-2027',
          'homeTeamName': 'VV Scherpenzeel',
          'awayTeamName': 'DOVO',
          'date': '2026-08-15',
          'kickoffTime': '15:00',
        }),
        '15:00',
      );
    });
  });

  group('matchstatus', () {
    test('ondersteunt de vijf publieke statussen', () {
      expect(parseMatchStatus('scheduled'), MatchStatus.scheduled);
      expect(parseMatchStatus('finished'), MatchStatus.finished);
      expect(parseMatchStatus('postponed'), MatchStatus.postponed);
      expect(parseMatchStatus('cancelled'), MatchStatus.cancelled);
      expect(parseMatchStatus('abandoned'), MatchStatus.abandoned);
    });

    test('normaliseert oude leeswaarden zonder live terug te brengen', () {
      expect(parseMatchStatus('afgelopen'), MatchStatus.finished);
      expect(parseMatchStatus('uitgesteld'), MatchStatus.postponed);
      expect(parseMatchStatus('onbekend'), MatchStatus.scheduled);
    });
  });
}
