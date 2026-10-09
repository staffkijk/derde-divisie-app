const fs=require('node:fs');
let p='lib/features/profiel/bekijk_profiel_screen.dart',s=fs.readFileSync(p,'utf8');
s=s.replace('required this.userId});','required this.userId, this.profileLoader});').replace('  final String userId;','  final String userId;\n  final Future<Map<String,dynamic>?> Function()? profileLoader;');
s=s.replace('  bool isLoading = true;','  bool isLoading = true;\n  String? _error;');
const start=s.indexOf('    try {'),end=s.indexOf('\n  @override',start);
s=s.slice(0,start)+`    if(mounted) setState(() { isLoading=true; _error=null; });
    try {
      final data=await (widget.profileLoader?.call() ?? FirebaseFirestore.instance
        .collection('users').doc(widget.userId).get().then((doc)=>doc.data()))
        .timeout(const Duration(seconds:20));
      if(!mounted)return;
      if(data==null) { _error='Dit profiel bestaat niet.'; }
      else {
        avatarUrl=data['avatarUrl']; username=data['username'] ?? 'Gebruiker';
        profielbeschrijving=data['profileDescription']; woonplaats=data['woonplaats'];
        favorieteCompetitie=data['favorieteCompetitie']; favorieteClub=data['favorieteClub'];
      }
    } catch (_) { _error='Profiel kon niet worden geladen.'; }
    finally { if(mounted)setState(()=>isLoading=false); }
  }
`+s.slice(end);
s=s.replace('    return Scaffold(\r\n      appBar:', `    if(_error!=null) return Scaffold(appBar:AppBar(title:const Text('Profiel')),
      body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(_error!),
        TextButton(onPressed:_laadProfiel,child:const Text('Opnieuw proberen'))])));
    return Scaffold(\r\n      appBar:`);fs.writeFileSync(p,s);
p='lib/features/moderator/moderator_dashboard_screen.dart';s=fs.readFileSync(p,'utf8').replace('widget.moderatorStatusLoader?.call() ?? _loadAccess();','(widget.moderatorStatusLoader?.call() ?? _loadAccess()).timeout(const Duration(seconds:20));').replace('late final Future<_SummaryData> _future = _load();','late final Future<_SummaryData> _future = _load().timeout(const Duration(seconds:20));');fs.writeFileSync(p,s);
p='test/security/firestore-emulator.test.cjs';s=fs.readFileSync(p,'utf8');s=s.replace("await assertSucceeds(updateDoc(doc(db, 'voorspellingen/bob-prediction'), {", "await assertFails(updateDoc(doc(db, 'voorspellingen/bob-prediction'), {");
const at=s.lastIndexOf('\n});');s=s.slice(0,at)+`
  it('derived scores and ledgers are server-owned even for a moderator', async () => {
    const mod=authed('moderator'),alice=authed('alice');
    for(const collection of ['standings','periodStandings','predictionContributions','pouleContributions','processingAggregates','endstandContributions']) {
      await assertFails(setDoc(doc(mod,'seasons/2026-2027/'+collection+'/forged'),{points:999}));
    }
    await assertFails(updateDoc(doc(alice,'users/alice'),{punten_A:999}));
    await assertFails(updateDoc(doc(mod,'users/alice'),{punten_A:999}));
    await assertFails(setDoc(doc(alice,'voorspellingen/forged'),{gebruikerId:'alice',wedstrijdId:'A1',punten:999}));
    await assertFails(setDoc(doc(alice,'poules/poule-alice/deelnemers/alice'),{punten:999}));
  });
  it('maintenance freezes result and prediction source writes', async () => {
    await testEnv.withSecurityRulesDisabled(async ctx=>{
      await setDoc(doc(ctx.firestore(),'system/result_processing_maintenance'),{enabled:true});
    });
    await assertFails(setDoc(doc(authed('moderator'),'seasons/2026-2027/matches/blocked'),{division:'A'}));
    await assertFails(setDoc(doc(authed('alice'),'voorspellingen/blocked'),{gebruikerId:'alice',wedstrijdId:'A1',scoreThuis:1,scoreUit:0}));
  });
`+s.slice(at);fs.writeFileSync(p,s);
p='firestore.rules';s=fs.readFileSync(p,'utf8');
s=s.replace('allow create: if isModerator() || (isOwner(uid) && hasNoModeratorClaims() && safeUserScores());','allow create: if safeUserScores() && (isModerator() || (isOwner(uid) && hasNoModeratorClaims()));');
s=s.replace('allow update: if (isModerator() && (!processingMaintenance() || keepsUserScores())) || (isOwner(uid) && keepsModeratorClaimsUnchanged() && keepsUserScores());','allow update: if keepsUserScores() && (isModerator() || (isOwner(uid) && keepsModeratorClaimsUnchanged()));');
// Freeze deleting predictions during a repair as well.
for(const c of ['voorspellingen','poule_predictions','poule_voorspellingen','predictions']){
 const a=s.indexOf('    match /'+c+'/{predictionId}'),b=s.indexOf('\n    }',a);const block=s.slice(a,b).replace('allow delete: if isModerator();','allow delete: if !processingMaintenance() && isModerator();');s=s.slice(0,a)+block+s.slice(b);
}
s=s.replace('allow delete: if isModerator() && !(collection','allow delete: if !processingMaintenance() && isModerator() && !(collection');fs.writeFileSync(p,s);
p='.github/workflows/regression.yml';s=fs.readFileSync(p,'utf8').replace("node-version: '20'","node-version: '22'").replace('      - name: Flutter tests', '      - name: Flutter analyze\n        run: flutter analyze\n\n      - name: Result processing emulator scenarios\n        run: npm run test:processing\n\n      - name: Flutter tests');fs.writeFileSync(p,s);
p='package.json';const json=JSON.parse(fs.readFileSync(p,'utf8'));json.scripts['test:processing']='npm --prefix functions run build && firebase emulators:exec --only firestore --project demo-derdediv-processing "node --test functions/integration/*.test.cjs"';json.scripts['benchmark:processing']='npm --prefix functions run build && firebase emulators:exec --only firestore --project demo-derdediv-processing "node tools/benchmark_result_processing.cjs"';fs.writeFileSync(p,JSON.stringify(json,null,2)+'\n');
