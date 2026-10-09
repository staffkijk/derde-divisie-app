import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:derde_divisie/features/voorspellen/ranking_screen.dart';
import 'package:derde_divisie/features/voorspellen/ranking_repository.dart';
import 'package:derde_divisie/features/voorspellen/ranking_logic.dart';
void main() {
  testWidgets('K: ranking failure exits spinner and can retry', (tester) async {
    var calls=0;
    await tester.pumpWidget(MaterialApp(home:RankingScreen(type:RankingType.divisionA,pageLoader:() async {
      if(calls++==0)throw StateError('offline');return const RankingPage([],false);
    })));
    await tester.pumpAndSettle();expect(find.text('Ranglijst kon niet worden geladen.'),findsOneWidget);
    expect(find.byType(CircularProgressIndicator),findsNothing);
    await tester.tap(find.text('Opnieuw proberen'));await tester.pumpAndSettle();
    expect(find.text('Nog geen deelnemers.'),findsOneWidget);expect(calls,2);
  });
  testWidgets('L: large ranking renders a page and loads another without refetching earlier rows', (tester) async {
    var calls=0;
    await tester.pumpWidget(MaterialApp(home:RankingScreen(type:RankingType.global,pageLoader:() async {
      final n=calls++;return RankingPage([RankingEntry('u$n',{'username':'User $n','punten_A':10,'punten_B':2})],n==0);
    })));
    await tester.pumpAndSettle();expect(find.text('User 0'),findsOneWidget);
    await tester.tap(find.text('Meer deelnemers laden'));await tester.pumpAndSettle();
    expect(find.text('User 0'),findsOneWidget);expect(find.text('User 1'),findsOneWidget);expect(calls,2);
    await tester.tap(find.text('User 1'));await tester.pumpAndSettle();expect(find.text('Bekijk voorspellingen'),findsOneWidget);
  });
}
