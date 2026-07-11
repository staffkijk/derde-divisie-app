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
        contains('videos%2Fderdediv_intro_2026_2027_web.mp4'),
      );
    });
  });

  group('MainNavigationConfig', () {
    test('plaatst Introfilm direct na Home en houdt bestaande indices stabiel',
        () {
      expect(MainNavigationConfig.items[MainNavigationConfig.homeIndex].label,
          'Home');
      expect(
        MainNavigationConfig.items[MainNavigationConfig.introfilmIndex].label,
        'Introfilm',
      );
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
    });

    test('maakt Introfilm publiek en koppelt index 1 aan IntroVideoScreen', () {
      final introItem =
          MainNavigationConfig.items[MainNavigationConfig.introfilmIndex];

      expect(introItem.destination, MainNavigationDestination.introfilm);
      expect(introItem.protected, isFalse);
      expect(introItem.selectedIcon, Icons.ondemand_video_rounded);
      expect(
        mainNavigationScreenTypes[MainNavigationConfig.introfilmIndex],
        IntroVideoScreen,
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
