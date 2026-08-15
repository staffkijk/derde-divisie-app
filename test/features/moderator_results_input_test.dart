import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/moderator/moderator_menu_screen.dart';

class MatchStreamSource {
  final calls = <String>[];
  final _controllers = <String, StreamController<List<ModeratorMatchData>>>{};

  Stream<List<ModeratorMatchData>> create(
    String division,
    int round,
  ) {
    final key = '$division-$round';
    calls.add(key);
    return _controllers
        .putIfAbsent(key, StreamController<List<ModeratorMatchData>>.broadcast)
        .stream;
  }

  void emit(String division, int round, List<ModeratorMatchData> matches) {
    _controllers['$division-$round']!.add(matches);
  }

  Future<void> close() => Future.wait(
        _controllers.values.map((controller) => controller.close()),
      );
}

class ResultWrite {
  const ResultWrite(
      this.matchId, this.division, this.round, this.home, this.away);
  final String matchId;
  final String division;
  final int round;
  final int home;
  final int away;
}

class ViewportHarness extends StatefulWidget {
  const ViewportHarness({
    super.key,
    required this.child,
    this.initialWidth = 390,
  });
  final Widget child;
  final double initialWidth;

  @override
  State<ViewportHarness> createState() => ViewportHarnessState();
}

class ViewportHarnessState extends State<ViewportHarness> {
  late double width = widget.initialWidth;

  void setWidth(double value) => setState(() => width = value);

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: widget.child,
      );
}

ModeratorMatchData matchDoc({
  required String id,
  String division = 'A',
  int round = 1,
  String home = 'ACV',
  String away = "ADO '20",
  int? homeScore,
  int? awayScore,
}) =>
    ModeratorMatchData(
      id: id,
      division: division,
      round: round,
      roundMatchIndex: 1,
      homeTeam: home,
      awayTeam: away,
      homeTeamSlug: home.toLowerCase(),
      awayTeamSlug: away.toLowerCase(),
      status: homeScore == null || awayScore == null ? 'scheduled' : 'finished',
      homeScore: homeScore,
      awayScore: awayScore,
    );
Finder scoreField(String side, String matchId) => find.descendant(
      of: find.byKey(ValueKey('$side-score-$matchId')),
      matching: find.byType(TextField),
    );

Future<void> loadSelection(
  WidgetTester tester,
  MatchStreamSource source,
  List<ModeratorMatchData> matches, {
  String division = 'A',
  int round = 1,
}) async {
  source.emit(division, round, matches);
  await tester.pump();
}

void main() {
  late MatchStreamSource source;
  late List<ResultWrite> writes;
  late GlobalKey<ViewportHarnessState> viewportKey;

  setUp(() {
    source = MatchStreamSource();
    writes = [];
    viewportKey = GlobalKey<ViewportHarnessState>();
  });

  tearDown(() => source.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ViewportHarness(
          key: viewportKey,
          child: ModeratorMenuScreen(
            matchesStreamFactory: source.create,
            resultWriter: ({
              required matchId,
              required division,
              required round,
              required homeScore,
              required awayScore,
            }) async {
              writes.add(ResultWrite(
                matchId,
                division,
                round,
                homeScore,
                awayScore,
              ));
            },
          ),
        ),
      ),
    );
    expect(source.calls, ['A-1']);
  }

  testWidgets('thuisscore en beide scorevelden blijven lokaal zichtbaar',
      (tester) async {
    await pumpScreen(tester);
    await loadSelection(tester, source, [matchDoc(id: 'm1')]);

    await tester.enterText(scoreField('home', 'm1'), '2');
    await tester.pump();
    expect(scoreField('home', 'm1'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);

    await tester.enterText(scoreField('away', 'm1'), '1');
    await tester.pump();
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);
  });

  testWidgets('viewport rebuild behoudt invoer, velden, lijst en stream',
      (tester) async {
    await pumpScreen(tester);
    await loadSelection(tester, source, [matchDoc(id: 'm1')]);
    await tester.enterText(scoreField('home', 'm1'), '2');
    await tester.enterText(scoreField('away', 'm1'), '1');

    viewportKey.currentState!.setWidth(700);
    await tester.pump();

    expect(source.calls, ['A-1']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('result-m1')), findsOneWidget);
    expect(scoreField('home', 'm1'), findsOneWidget);
    expect(scoreField('away', 'm1'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);
  });

  testWidgets('bestaande uitslag initialiseert en overleeft lokale rebuild',
      (tester) async {
    await pumpScreen(tester);
    await loadSelection(
      tester,
      source,
      [matchDoc(id: 'm1', homeScore: 3, awayScore: 0)],
    );
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    expect(find.widgetWithText(TextField, '0'), findsOneWidget);

    await tester.enterText(scoreField('home', 'm1'), '4');
    viewportKey.currentState!.setWidth(800);
    await tester.pump();

    expect(find.widgetWithText(TextField, '4'), findsOneWidget);
    expect(find.widgetWithText(TextField, '0'), findsOneWidget);
    expect(source.calls, ['A-1']);
  });

  testWidgets('wisselen van speelronde maakt nieuwe selectie en controllers',
      (tester) async {
    await pumpScreen(tester);
    await loadSelection(tester, source, [matchDoc(id: 'a1')]);
    await tester.enterText(scoreField('home', 'a1'), '8');

    await tester.tap(find.byKey(const ValueKey('moderator-round-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speelronde 2').last);
    await tester.pump();

    expect(source.calls, ['A-1', 'A-2']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await loadSelection(
      tester,
      source,
      [matchDoc(id: 'a2', round: 2, home: 'DOVO', away: 'Hercules')],
      round: 2,
    );
    expect(find.byKey(const ValueKey('result-a1')), findsNothing);
    expect(find.byKey(const ValueKey('result-a2')), findsOneWidget);
    expect(scoreField('home', 'a2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '8'), findsNothing);
  });

  testWidgets('wisselen van Divisie A naar B maakt nieuwe selectie',
      (tester) async {
    await pumpScreen(tester);
    await loadSelection(tester, source, [matchDoc(id: 'a1')]);

    await tester.tap(find.byKey(const ValueKey('moderator-division-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Divisie B').last);
    await tester.pump();

    expect(source.calls, ['A-1', 'B-1']);
    await loadSelection(
      tester,
      source,
      [matchDoc(id: 'b1', division: 'B', home: 'UNA', away: 'TOGB')],
      division: 'B',
    );
    expect(find.byKey(const ValueKey('result-a1')), findsNothing);
    expect(find.byKey(const ValueKey('result-b1')), findsOneWidget);
  });

  testWidgets('Alles opslaan weigert half ingevuld resultaat', (tester) async {
    await pumpScreen(tester);
    await loadSelection(tester, source, [matchDoc(id: 'm1')]);
    await tester.enterText(scoreField('home', 'm1'), '2');

    await tester.tap(find.byKey(const ValueKey('save-all-results')));
    await tester.pump();

    expect(writes, isEmpty);
    expect(find.textContaining('is onvolledig'), findsOneWidget);
  });

  testWidgets('Alles opslaan accepteert volledig resultaat en slaat leeg over',
      (tester) async {
    await pumpScreen(tester);
    await loadSelection(tester, source, [
      matchDoc(id: 'complete', home: 'ACV', away: 'DOVO'),
      matchDoc(id: 'empty', home: 'TEC', away: 'Hercules'),
    ]);
    await tester.enterText(scoreField('home', 'complete'), '2');
    await tester.enterText(scoreField('away', 'complete'), '1');

    await tester.tap(find.byKey(const ValueKey('save-all-results')));
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    expect(writes.single.matchId, 'complete');
    expect(writes.single.home, 2);
    expect(writes.single.away, 1);
    expect(find.text('1 uitslagen opgeslagen.'), findsOneWidget);
  });
}
