import 'package:derde_divisie/features/calendar/calendar_subscription_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async => null));
  for (final width in [360.0, 390.0, 412.0, 1000.0]) {
    testWidgets('dialog has no overflow at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: CalendarSubscriptionDialog())));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar-subscription-dialog')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('club choice enables copying', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CalendarSubscriptionDialog())));
    await tester.tap(find.byKey(const Key('calendar-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programma van één club').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-team-picker')), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'ACV');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACV').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('copy-calendar-link')))
            .onPressed,
        isNotNull);
    await tester.tap(find.byKey(const Key('copy-calendar-link')));
    await tester.pump();
    expect(find.text('Abonnementslink gekopieerd.'), findsOneWidget);
  });
}
