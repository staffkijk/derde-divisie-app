const fs=require('node:fs');
let p='functions/src/result-domain.ts',s=fs.readFileSync(p,'utf8');
s=s.replace('division(m), m.round ?? m.speelronde, m.status,', 'division(m), m.processingRequest ?? 0, m.round ?? m.speelronde, m.status,');
s=s.replace('    if (!user || !eligible(doc.data,m)) continue;',`    if (!user || !eligible(doc.data,m) || (doc.data.seasonId && doc.data.seasonId !== ACTIVE_SEASON)) continue;`);fs.writeFileSync(p,s);
p='functions/src/result-processor.ts';s=fs.readFileSync(p,'utf8');
s=s.replace('class Superseded extends Error {}',`class Superseded extends Error {}
class MaintenancePaused extends Error {}
async function checkMaintenance(tx: FirebaseFirestore.Transaction, db: Firestore): Promise<void> {
  if ((await tx.get(db.doc('system/result_processing_maintenance'))).data()?.enabled === true) throw new MaintenancePaused();
}`);
s=s.replaceAll('async tx => {','async tx => {\n    await checkMaintenance(tx,db);');
s=s.replace('    if (error instanceof Superseded) return;', '    if (error instanceof MaintenancePaused) throw error;\n    if (error instanceof Superseded) return;');
fs.writeFileSync(p,s);
p='functions/src/result-functions.ts';s=fs.readFileSync(p,'utf8');
s+=`
async function predictionSourceChanged(change: functions.Change<admin.firestore.DocumentSnapshot>): Promise<void> {
  const before=change.before.data(),after=change.after.data();
  const source=(p: any) => p ? [p.gebruikerId,p.userId,p.uid,p.matchId,p.wedstrijdId,p.pouleId,p.scoreThuis,p.scoreUit,p.homeScore,p.awayScore,p.timestamp?.toMillis(),p.seasonId] : null;
  if (JSON.stringify(source(before)) === JSON.stringify(source(after))) return;
  const p=after ?? before;if(!p || (p.seasonId && p.seasonId !== ACTIVE_SEASON)) return;
  const id=p.matchId ?? p.wedstrijdId;if(typeof id !== 'string' || id.includes('/')) return;
  const db=admin.firestore(),ref=db.doc('seasons/'+ACTIVE_SEASON+'/matches/'+id);
  await db.runTransaction(async tx => {
    const lock=await tx.get(db.doc('system/result_processing_maintenance'));if(lock.data()?.enabled)throw Error('Maintenance active');
    const match=await tx.get(ref);if(!match.exists || match.data()?.status !== 'finished')return;
    tx.update(ref,{processingRequest:admin.firestore.FieldValue.increment(1),processed:false,verwerkt:false,processingStatus:'pending',predictionProcessingComplete:false});
  });
}
const predictionTrigger = (path: string) => functions.region('europe-west1').runWith({failurePolicy:true})
  .firestore.document(path).onWrite(predictionSourceChanged);
export const processSeasonPredictionEdit = functions.region('europe-west1').runWith({failurePolicy:true})
  .firestore.document('seasons/{seasonId}/predictions/{id}').onWrite(async (change,context) => {
    if(context.params.seasonId===ACTIVE_SEASON) await predictionSourceChanged(change);
  });
export const processGeneralPredictionEdit=predictionTrigger('voorspellingen/{id}');
export const processPouleAPredictionEdit=predictionTrigger('poule_predictions/{id}');
export const processPouleBPredictionEdit=predictionTrigger('poule_voorspellingen/{id}');
export const processTeamPredictionEdit=predictionTrigger('predictions/{id}');
`;
fs.writeFileSync(p,s);
p='functions/src/index.ts';s=fs.readFileSync(p,'utf8');s+='\nexport {processSeasonPredictionEdit, processGeneralPredictionEdit, processPouleAPredictionEdit, processPouleBPredictionEdit, processTeamPredictionEdit} from "./result-functions";\n';
// A single application cache TTL + HTTP TTL otherwise adds up to ten minutes.
s=s.replace('public, max-age=300, s-maxage=300, stale-while-revalidate=60','no-cache, max-age=0, must-revalidate');fs.writeFileSync(p,s);
p='lib/data/models/poule_prediction.dart';s=fs.readFileSync(p,'utf8').replace("      'punten': punten,\r\n",'').replace("      'punten': punten,\n",'');fs.writeFileSync(p,s);
p='firestore.rules';s=fs.readFileSync(p,'utf8');s=s.replace('    function signedIn() {',`    function processingMaintenance() {
      return exists(/databases/$(database)/documents/system/result_processing_maintenance) &&
        get(/databases/$(database)/documents/system/result_processing_maintenance).data.enabled == true;
    }
    function signedIn() {`);
// Freeze source writes for an explicitly authorised audited repair.
s=s.replaceAll('if noDerivedPredictionFields() &&','if !processingMaintenance() && noDerivedPredictionFields() &&').replaceAll('if keepsDerivedPredictionFields() &&','if !processingMaintenance() && keepsDerivedPredictionFields() &&');
s=s.replaceAll('allow create: if isModerator() && !(collection','allow create: if !processingMaintenance() && isModerator() && !(collection').replaceAll('allow update: if isModerator() && !(collection','allow update: if !processingMaintenance() && isModerator() && !(collection');
s=s.replace('allow update: if isModerator() || (isOwner(uid)', 'allow update: if (isModerator() && (!processingMaintenance() || keepsUserScores())) || (isOwner(uid)');
fs.writeFileSync(p,s);
