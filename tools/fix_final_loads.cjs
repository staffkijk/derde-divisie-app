const fs=require('fs');const edit=(p,f)=>fs.writeFileSync(p,f(fs.readFileSync(p,'utf8')));
edit('test/features/eindstand_points_structure_test.dart',s=>s.replace("contains('seasons/${ACTIVE_SEASON}/matches')","contains(r'seasons/${ACTIVE_SEASON}/matches')"));
for(const p of ['lib/features/poules/wedstrijden_poule_dda_screen.dart','lib/features/poules/wedstrijden_poule_ddb_screen.dart'])edit(p,s=>s.replace(/^  static const String _fsCompetitie = .*\r?\n/gm,''));
edit('lib/helpers/sync_service.dart',s=>s.replace(/  String _fsCompetitionName\(String code\) \{[\s\S]*?\r?\n  \}\r?\n\r?\n/,''));
edit('lib/features/poules/poule_voorspellingen_screen.dart',s=>s.replace('if (!matchesSnap.hasData)',"if (matchesSnap.hasError) { return const Center(child: Text('Wedstrijden konden niet worden geladen.')); }\n                  if (!matchesSnap.hasData)"));
edit('lib/features/poules/voorspel_competitie_poule_screen.dart',s=>s.replace('bool isLoading = true;','bool isLoading = true;\n  String? _error;\n  DateTime _date(Map<String,dynamic> data) { final value=data[\'scheduledAt\'] ?? data[\'date\'] ?? data[\'datum\']; return value is Timestamp ? value.toDate() : DateTime(1970); }').replace('final comp = _mapCompetitie(widget.competitie);','try {\n    final comp = _mapCompetitie(widget.competitie);').replace("(a['datum'] as Timestamp).toDate()","_date(a.data() as Map<String,dynamic>)").replace("(b['datum'] as Timestamp).toDate()","_date(b.data() as Map<String,dynamic>)").replace("(data['datum'] as Timestamp).toDate()","_date(data)").replace('setState(() => isLoading = false);',"} catch (_) { _error='Wedstrijden en voorspellingen konden niet worden geladen.'; } finally { if(mounted)setState(() => isLoading=false); }").replace(': ListView.builder(',": _error!=null ? Center(child: Text(_error!)) : ListView.builder(").replace('.get();','.get().timeout(const Duration(seconds:20));'));
edit('lib/features/moderator/moderator_menu_screen.dart',s=>s.replace('if (homeScore == null || awayScore == null)', 'if (homeScore == null || awayScore == null || homeScore < 0 || awayScore < 0)'));
edit('tools/benchmark_result_processing.cjs',s=>s.replace("fs.mkdirSync('docs/reliability'",`// Measure source writes separately from completion of the new pipeline.
 const {teams}=require('../functions/lib/season-teams'),{processMatch}=require('../functions/lib/result-processor');
 const clubs=teams.filter(t=>t.division==='A');await db.doc('users/u').set({punten_A:0,punten_B:0,totalen:0,rankingName:'u'});
 for(let i=0;i<9;i++){
  await db.doc(base+'/matches/m'+i).update({status:'scheduled',homeTeamSlug:clubs[i*2].id,awayTeamSlug:clubs[i*2+1].id,scheduledAt:Timestamp.fromDate(new Date('2027-01-01T14:00:00Z'))});
  await db.doc('voorspellingen/u_m'+i).update({scoreThuis:2,scoreUit:1,timestamp:Timestamp.fromDate(new Date('2026-08-01T09:00:00Z'))});
 }
 const writeStart=performance.now();for(let i=0;i<9;i++)await db.doc(base+'/matches/m'+i).update({status:'finished',homeScore:2,awayScore:1});
 const saved=performance.now();await Promise.all(Array.from({length:9},(_,i)=>processMatch(db,'m'+i)));
 result.processing={sourceWrites9Ms:+(saved-writeStart).toFixed(2),completionAfterSave9Ms:+(performance.now()-saved).toFixed(2),verifiedUserPoints:(await db.doc('users/u').get()).data().punten_A};
 result.sameDayKickoffWrite=await measure(async()=>{await db.doc(base+'/matches/m0').update({scheduledAt:Timestamp.fromDate(new Date('2027-01-01T18:00:00Z'))});return 0;});
 fs.mkdirSync('docs/reliability'`));
