const fs=require('node:fs');
let p='lib/features/moderator/moderator_dashboard_screen.dart',s=fs.readFileSync(p,'utf8');
s=s.replace('if (!snapshot.hasData) {',`if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('Moderatorrechten konden niet worden gecontroleerd.')));
        }
        if (!snapshot.hasData) {`);
s=s.replace('class _ModeratorSummary extends StatelessWidget {\r\n  const _ModeratorSummary();','class _ModeratorSummary extends StatefulWidget {\r\n  const _ModeratorSummary();\r\n  @override\r\n  State<_ModeratorSummary> createState() => _ModeratorSummaryState();\r\n}\r\nclass _ModeratorSummaryState extends State<_ModeratorSummary> {\r\n  late final Future<_SummaryData> _future = _load();');
const start=s.indexOf('    final results = await Future.wait(['),end=s.indexOf('\n  @override',start);
s=s.slice(0,start)+`    final matches = SeasonPaths.currentSeasonMatches;
    final counts = await Future.wait([
      matches.count().get(),
      matches.where('processed', isEqualTo: true).where('status', isEqualTo: 'finished').count().get(),
      matches.where('processingStatus', isEqualTo: 'failed').count().get(),
      FirebaseFirestore.instance.collection('activityLogs').orderBy('createdAt', descending: true).limit(100).count().get(),
      matches.where('status', isEqualTo: 'scheduled').count().get(),
      matches.where('status', isEqualTo: 'postponed').count().get(),
    ]);
    return _SummaryData(matches: counts[0].count ?? 0, processed: counts[1].count ?? 0,
      errors: counts[2].count ?? 0, recentActivities: counts[3].count ?? 0,
      scheduled: counts[4].count ?? 0, postponed: counts[5].count ?? 0);
  }
`+s.slice(end);
s=s.replace('future: _load(),','future: _future,');fs.writeFileSync(p,s);
p='lib/features/moderator/moderator_menu_screen.dart';s=fs.readFileSync(p,'utf8');
s=s.replace('  bool _savingAll = false;',`  bool _savingAll = false;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  @override
  void initState() { super.initState(); _stream = _matchesQuery().snapshots(); }`);
s=s.replaceAll('_clearControllers();','_clearControllers();\n                            _stream = _matchesQuery().snapshots();');
s=s.replace('_matchesQuery().snapshots(),','_stream,');
s=s.replace('homeScore == null || awayScore == null','homeScore == null || awayScore == null || homeScore < 0 || awayScore < 0');
// Surface asynchronous server status and a safe retry directly on each result row.
s=s.replace('  final String status;', '  final String status;\n  final String processingStatus;');
s=s.replace('required this.status,','required this.status,\n    required this.processingStatus,');
s=s.replace("status: _string(data['status'], 'scheduled'),", "status: _string(data['status'], 'scheduled'),\n      processingStatus: _string(data['processingStatus'], ''),");
s=s.replace('MatchStatusBadge(status: parseMatchStatus(match.status)),',`MatchStatusBadge(status: parseMatchStatus(match.status)),
              if (match.processingStatus.isNotEmpty)
                Text(match.processingStatus == 'processed' ? 'Verwerkt' : match.processingStatus == 'failed' ? 'Verwerking mislukt' : 'Opgeslagen; verwerking bezig'),
              if (match.processingStatus == 'failed')
                TextButton(onPressed: () async {
                  try { await ResultProcessingService.requestProcessing(match.id); }
                  catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opnieuw verwerken aanvragen mislukt.'))); }
                }, child: const Text('Opnieuw verwerken')),`);
fs.writeFileSync(p,s);
p='lib/features/voorspellen/bekijk_voorspellingen_screen.dart';s=fs.readFileSync(p,'utf8');
s=s.replace('      await _laadGebruikerData();','      await _laadGebruikerData().timeout(const Duration(seconds: 20));').replace('      await _laadVoorspellingenVoorContext();','      await _laadVoorspellingenVoorContext().timeout(const Duration(seconds: 30));').replace('        await _laadEindstandVoorContext();','        await _laadEindstandVoorContext().timeout(const Duration(seconds: 15));');
const a=s.indexOf('    final predictionSnapshot ='),b=s.indexOf('    final doelDivisie =',a);
s=s.slice(0,a)+`    final byMatch = <String, Map<String, dynamic>>{};
    for (final collection in [FirebaseFirestore.instance.collection('voorspellingen'), SeasonPaths.currentSeasonPredictions]) {
      for (final ownerField in ['gebruikerId', 'userId', 'uid']) {
        QueryDocumentSnapshot<Map<String, dynamic>>? last;
        while (true) {
          Query<Map<String, dynamic>> q = collection.where(ownerField, isEqualTo: widget.userId)
              .orderBy(FieldPath.documentId).limit(200);
          if (last != null) q = q.startAfterDocument(last);
          final page = await q.get();
          for (final doc in page.docs) {
            final prediction = doc.data();
            final id = (prediction['wedstrijdId'] ?? prediction['matchId'] ?? '').toString();
            if (id.isNotEmpty) {
              final old = byMatch[id];
              final ts = prediction['timestamp'] is Timestamp ? (prediction['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
              final previousTs = old?['timestamp'] is Timestamp ? (old!['timestamp'] as Timestamp).millisecondsSinceEpoch : -1;
              if (ts >= previousTs) byMatch[id] = prediction;
            }
          }
          if (page.docs.length < 200) break;
          last = page.docs.last;
        }
      }
    }
    final matchesById = <String, Map<String, dynamic>>{};
    final ids = byMatch.keys.toList();
    // Fetch only matches referenced by this user, with bounded whereIn requests.
    for (var i = 0; i < ids.length; i += 30) {
      final end = (i + 30).clamp(0, ids.length);
      final page = await SeasonPaths.currentSeasonMatches.where(FieldPath.documentId, whereIn: ids.sublist(i,end)).get();
      for (final doc in page.docs) { matchesById[doc.id] = doc.data(); }
    }
`+s.slice(b);
s=s.replace('    for (final doc in predictionSnapshot.docs) {\r\n      final prediction = doc.data();\r\n      final wedstrijdId = (prediction[\'wedstrijdId\'] ?? \'\').toString().trim();',"    for (final entry in byMatch.entries) {\n      final prediction = entry.value;\n      final wedstrijdId = entry.key;");
fs.writeFileSync(p,s);
// Existing repair buttons enqueue current-source processing instead of writing competing score snapshots.
p='lib/features/moderator/mod_tools.dart';s=fs.readFileSync(p,'utf8');
s=s.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:derde_divisie/data/firestore/season_paths.dart';\nimport 'package:derde_divisie/features/moderator/result_processing_service.dart';");
const names=['herstelVoorspellingenSpeelronde18A','herstelAlleAlgemeneVoorspellingenEnUserTotalen','herstelAllePoulePunten','herstelAllePeriodestanden','hardeResetEnHerberekenAlles','herberekenAlleWedstrijden'];
for(const name of names) {
 const start=s.indexOf('Future<void> '+name+'(');if(start<0)throw Error(name);
 const end=s.indexOf('\n}',start)+2;
 s=s.slice(0,start)+`Future<void> ${name}() async {
  final matches = await SeasonPaths.currentSeasonMatches${name==='herstelVoorspellingenSpeelronde18A' ? ".where('division', isEqualTo: 'A').where('round', isEqualTo: 18)" : ''}.get();
  for (final match in matches.docs.where((doc) => doc.id != '_meta')) {
    await ResultProcessingService.requestProcessing(match.id);
  }
}\n`+s.slice(end);
}
fs.writeFileSync(p,s);
