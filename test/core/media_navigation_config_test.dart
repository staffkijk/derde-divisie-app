import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/config/main_navigation_config.dart';
import 'package:derde_divisie/core/config/media_config.dart';
import 'package:derde_divisie/features/media/intro_video_screen.dart';
import 'package:derde_divisie/main_screen.dart';

void main() {
  group('MediaConfig', () {
    test('bewaart de introfilm URL centraal als Firebase Storage Uri', () {
      expect(MediaConfig.introVideo20262027Url.scheme, 'https');
      expect(
        MediaConfig.introVideo20262027Url.host,
        'firebasestorage.googleapis.com',
      );
      expect(
        MediaConfig.introVideo20262027Url.toString(),
        contains('videos%2Fderdediv_intro_2026_2027_web_v2.mp4'),
      );
    });
  });

  group('MainNavigationConfig', () {
    test('houdt menu-indexen stabiel zonder Introfilm-menuitem', () {
      expect(MainNavigationConfig.items[MainNavigationConfig.homeIndex].label,
          'Home');
      expect(
        MainNavigationConfig.items[MainNavigationConfig.divisionAIndex].label,
        'Derde Divisie A',
      );
      expect(
        MainNavigationConfig.items[MainNavigationConfig.divisionBIndex].label,
        'Derde Divisie B',
      );
      expect(
        MainNavigationConfig.items[MainNavigationConfig.programIndex].label,
        'Programma',
      );
      expect(
        MainNavigationConfig.items[MainNavigationConfig.profileIndex].label,
        'Profiel',
      );
      expect(
        MainNavigationConfig.items.map((item) => item.label),
        isNot(contains('Introfilm')),
      );
    });

    test('houdt schermmapping gelijk aan menu-items', () {
      expect(
        mainNavigationScreenTypes[MainNavigationConfig.homeIndex],
        isNot(IntroVideoScreen),
      );
      expect(
        mainNavigationScreenTypes.length,
        MainNavigationConfig.items.length,
      );
    });
  });

  testWidgets('IntroVideoErrorPanel toont Nederlandse fouttekst en retryknop',
      (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntroVideoErrorPanel(
            message: 'De browser ondersteunt dit videoformaat mogelijk niet.',
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Video niet beschikbaar'), findsOneWidget);
    expect(
      find.text('De browser ondersteunt dit videoformaat mogelijk niet.'),
      findsOneWidget,
    );
    expect(find.text('Probeer opnieuw'), findsOneWidget);

    await tester.tap(find.text('Probeer opnieuw'));
    expect(retryCount, 1);
  });
}
