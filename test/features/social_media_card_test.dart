import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/features/moderator/social_media_card_screen.dart';

void main() {
  testWidgets('rendert negen wedstrijden in desktoppreview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matches = List.generate(
      9,
      (index) => SocialCardMatch(
        id: '$index',
        division: 'A',
        round: 1,
        homeTeam: 'Thuisclub $index',
        awayTeam: 'Uitclub $index',
        kickoffTime: '15:00',
        status: MatchStatus.scheduled,
        data: {
          'division': 'A',
          'round': 1,
          'date': '2026-08-15',
          'kickoffTime': '15:00',
          'roundMatchIndex': index,
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialMediaMatchCard(
            divisionName: 'Derde Divisie A',
            round: 1,
            mode: SocialCardMode.program,
            matches: matches,
            tweetText: 'Programma speelronde 1',
          ),
        ),
      ),
    );

    expect(find.text('Programma'), findsOneWidget);
    expect(
        find.textContaining('Derde Divisie A - speelronde 1'), findsOneWidget);
    expect(find.text('Thuisclub 0'), findsOneWidget);
    expect(find.text('Uitclub 8'), findsOneWidget);
  });

  testWidgets('toont uitgestelde en afgelaste wedstrijden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final matches = List.generate(
      9,
      (index) => SocialCardMatch(
        id: '$index',
        division: 'B',
        round: 4,
        homeTeam: 'Thuis $index',
        awayTeam: 'Uit $index',
        kickoffTime: '14:30',
        status: index == 0
            ? MatchStatus.postponed
            : index == 1
                ? MatchStatus.cancelled
                : MatchStatus.scheduled,
        data: {
          'division': 'B',
          'round': 4,
          'date': '2026-09-12',
          'kickoffTime': '14:30',
          'roundMatchIndex': index,
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialMediaMatchCard(
            divisionName: 'Derde Divisie B',
            round: 4,
            mode: SocialCardMode.program,
            matches: matches,
            tweetText: 'Programma speelronde 4',
          ),
        ),
      ),
    );

    expect(find.text('Uitgesteld'), findsOneWidget);
    expect(find.text('Afgelast'), findsOneWidget);
  });
}
