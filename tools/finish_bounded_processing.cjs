const fs=require('fs');const edit=(p,f)=>fs.writeFileSync(p,f(fs.readFileSync(p,'utf8')));
edit('functions/src/result-processor.ts',s=>s.replace('const stamp = () =>',`async function bounded<T>(items: T[], action: (item: T) => Promise<void>): Promise<void> {
  for(let i=0;i<items.length;i+=4) {
    const results=await Promise.allSettled(items.slice(i,i+4).map(action));
    const failed=results.find(r=>r.status==='rejected');
    if(failed?.status==='rejected')throw failed.reason;
  }
}
const stamp = () =>`).replace('for (const [user, doc] of general) {\r\n      if (!user) continue;','await bounded([...general], async ([user,doc]) => {\n      if (!user) return;').replace('for (const [user, doc] of general) {\n      if (!user) continue;','await bounded([...general], async ([user,doc]) => {\n      if (!user) return;').replace(/(db.doc\(`\$\{base\}\/predictionContributions\/\$\{div\}__\$\{user\}__\$\{matchId\}`\)\);)\r?\n    \}/,'$1\n    });').replace('for (const doc of poules.values()) {','await bounded([...poules.values()], async (doc) => {').replace(/(await applyPrediction\(db, matchRef, expected, user, doc.path \|\| null, db.doc\(`\$\{base\}\/pouleContributions\/\$\{id\}`\), poule\);)\r?\n    \}/,'$1\n    });'));
edit('functions/src/result-functions.ts',s=>s.replace('p.thuisScore, p.uitScore, p.timestamp','p.thuisScore, p.uitScore, p.voorspellingThuis, p.voorspellingUit, p.thuis, p.uit, p.home, p.away, p.goalsHome, p.goalsAway, p.predHome, p.predAway, p.timestamp'));
// Legacy sync reads must use the same match IDs as current predictions.
edit('lib/helpers/sync_service.dart',s=>{
 if(!s.includes("import 'package:derde_divisie/data/firestore/season_paths.dart';"))s="import 'package:derde_divisie/data/firestore/season_paths.dart';\n"+s;
 return s.replace(/_db\s*\.collection\('matches'\)/g,'SeasonPaths.currentSeasonMatches').replace(".where('competitie', isEqualTo: fsComp)",".where('division', isEqualTo: competition == 'ddb' ? 'B' : 'A')").replace(".where('speelronde', isEqualTo: round)",".where('round', isEqualTo: round)").replace(".orderBy('datum')",'').replace("final fsComp = _fsCompetitionName(competition);",'').replace("final ts = d.data()['datum'];","final ts = d.data()['scheduledAt'] ?? d.data()['date'] ?? d.data()['datum'];");
});
