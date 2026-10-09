const assert=require('node:assert/strict');
const {test,before,after}=require('node:test');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp,FieldValue}=require('firebase-admin/firestore');
const {performance}=require('node:perf_hooks');
const {processMatch}=require('../lib/result-processor');
const {fingerprint,standings,contribution,points}=require('../lib/result-domain');
const {teams}=require('../lib/season-teams');
if(!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required; production access refused');
const app=initializeApp({projectId:'demo-derdediv-processing'}),db=getFirestore(app);
const base='seasons/2026-2027';let fixture;
async function seed() {
 await db.recursiveDelete(db.collection('seasons'));await db.recursiveDelete(db.collection('users'));await db.recursiveDelete(db.collection('poules'));
 for(const c of ['voorspellingen','poule_predictions','poule_voorspellingen','predictions'])await db.recursiveDelete(db.collection(c));
 const batch=db.batch(),matches=[];
 batch.set(db.doc('users/u'),{punten_A:0,punten_B:0,totalen:0,username:'User',rankingName:'user'});
 batch.set(db.doc('poules/p/deelnemers/u'),{punten:0,userId:'u'});
 for(const division of ['A','B']) {
  const ts=teams.filter(t=>t.division===division);
  for(let i=0;i<9;i++) {
   const id=`${division}${i}`,data={division,round:1,status:'scheduled',homeTeamSlug:ts[2*i].id,awayTeamSlug:ts[2*i+1].id,
    scheduledAt:Timestamp.fromDate(new Date('2026-10-10T13:00:00Z'))};
   matches.push({id,data});batch.set(db.doc(`${base}/matches/${id}`),data);
   const pred={gebruikerId:'u',wedstrijdId:id,scoreThuis:2,scoreUit:1,timestamp:Timestamp.fromDate(new Date('2026-10-10T09:00:00Z'))};
   batch.set(db.doc(`${base}/predictions/u_${id}`),pred);
   batch.set(db.doc(`poule_predictions/p_${id}`),{...pred,pouleId:'p',matchId:id});
  }
 }
 await batch.commit();return matches;
}
async function finish(id,h=2,a=1) {await db.doc(`${base}/matches/${id}`).update({status:'finished',homeScore:h,awayScore:a});}
async function invariant() {
 const matches=await db.collection(`${base}/matches`).get();
 const user=(await db.doc('users/u').get()).data();let a=0,b=0;
 for(const m of matches.docs)if(m.data().status==='finished') {
  const p=points(2,1,m.data().homeScore,m.data().awayScore);if(m.data().division==='A')a+=p;else b+=p;
 }
 assert.equal(user.punten_A,a);assert.equal(user.punten_B,b);assert.equal(user.totalen,Math.max(a,b));
 assert.equal((await db.doc('poules/p/deelnemers/u').get()).data().punten,a+b);
 for(const div of ['A','B']) {
  const cs=Object.fromEntries(matches.docs.filter(m=>m.data().division===div).map(m=>[m.id,contribution(m.data())]));
  for(let period=0;period<=3;period++)for(const expected of standings(div,cs,period)) {
   const collection=period?'periodStandings':'standings',id=period?`${div}_P${period}_${expected.teamId}`:`${div}_${expected.teamId}`;
   const actual=(await db.doc(`${base}/${collection}/${id}`).get()).data();
   if(!actual && !matches.docs.some(m=>m.data().division===div&&m.data().processed))continue;
   for(const field of ['played','wins','draws','losses','goalsFor','goalsAgainst','points','position'])assert.equal(actual[field],expected[field],`${id}.${field}`);
  }
 }
}
before(async()=>{fixture=await seed();});after(async()=>{await deleteApp(app);});
test('A, B, C, D, G, I: one, nine and eighteen concurrent results; duplicate delivery; shared user',async()=>{
 const start=performance.now();
 await finish('A0');await processMatch(db,'A0');await processMatch(db,'A0');await invariant();
 await Promise.all(fixture.filter(m=>m.id!=='A0').map(async m=>{await finish(m.id);await processMatch(db,m.id);}));
 await invariant();
 assert.equal((await db.doc('users/u').get()).data().punten_A,90);
 console.log(JSON.stringify({measurement:'18 result writes and server processing, local emulator',milliseconds:performance.now()-start}));
});
test('E, F: corrections and rollback retain consistent standings and totals',async()=>{
 await finish('A0',0,3);await Promise.all([processMatch(db,'A0'),processMatch(db,'A0')]);await invariant();
 await db.doc(`${base}/matches/A0`).update({status:'postponed',homeScore:FieldValue.delete(),awayScore:FieldValue.delete()});
 await processMatch(db,'A0');await processMatch(db,'A0');await invariant();
});
test('H: interrupted after general points, retry completes poules exactly once',async()=>{
 await finish('A0');await assert.rejects(processMatch(db,'A0',{afterGeneral:async()=>{throw Error('injected interruption');}}));
 assert.equal((await db.doc(`${base}/matches/A0`).get()).data().processed,false);
 await processMatch(db,'A0');await invariant();
});
test('latest result wins while an older worker is paused',async()=>{
 await finish('A0',1,1);
 let release,reached;const gate=new Promise(r=>release=r),ready=new Promise(r=>reached=r);
 const old=processMatch(db,'A0',{afterGeneral:async()=>{reached();await gate;}});await ready;
 await finish('A0',4,0);await processMatch(db,'A0');release();await old;await invariant();
 const current=(await db.doc(`${base}/matches/A0`).get()).data();assert.equal(current.processedInputKey,fingerprint(current));
});
test('J: same-day kickoff change is immediately stored and leaves points unchanged',async()=>{
 const ref=db.doc(`${base}/matches/A0`),old=(await ref.get()).data();
 await ref.update({scheduledAt:Timestamp.fromDate(new Date('2026-10-10T18:00:00Z'))});
 const current=(await ref.get()).data();assert.equal(fingerprint(current),fingerprint(old));await invariant();
});
test('deleted or ineligible prediction rolls back its existing ledger contribution',async()=>{
 await db.doc(`${base}/predictions/u_A1`).delete();await db.doc('poule_predictions/p_A1').delete();
 await db.doc(`${base}/matches/A1`).update({processingRequest:FieldValue.increment(1)});
 await processMatch(db,'A1');
 const ledger=(await db.doc(`${base}/predictionContributions/A__u__A1`).get()).data();assert.equal(ledger.points,0);
 await processMatch(db,'A1');assert.equal((await db.doc('users/u').get()).data().punten_A,70+points(2,1,4,0));
});

test('L: dry-run, backed-up repair and repeated verification converge without source changes',async()=>{
 const {spawnSync}=require('node:child_process'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'derdediv-audit-'));
 const output=path.join(dir,'audit.json');
 const matchBefore=(await db.doc(`${base}/matches/A0`).get()).data();
 await db.doc('users/u').update({punten_A:999,totalen:999});
 function audit(...args){const child=spawnSync(process.execPath,['tools/audit_result_processing.cjs','--project=demo-derdediv-processing',`--output=${output}`,...args],{cwd:path.resolve(__dirname,'../..'),env:process.env,encoding:'utf8'});assert.equal(child.status,args.includes('--fail-after-batch=1')?1:0,child.stdout+child.stderr);return JSON.parse(fs.readFileSync(args.findLast(a=>a.startsWith('--output='))?.slice(9) ?? output));}
 const dry=audit();assert.ok(dry.changes.some(c=>c.path==='users/u'));assert.equal((await db.doc('users/u').get()).data().punten_A,999);
 audit('--apply','--allow-fixture');assert.ok(fs.existsSync(output+'.backup.json'));
 assert.equal(audit().changes.length,0);
 assert.deepEqual((await db.doc(`${base}/matches/A0`).get()).data(),matchBefore);
 assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,false);
 await db.doc('users/u').update({punten_A:999});
 audit('--apply','--allow-fixture','--fail-after-batch=1',`--output=${path.join(dir,'interrupted.json')}`);
 assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,true);
 audit('--apply','--allow-fixture','--resume-maintenance',`--output=${path.join(dir,'resumed.json')}`);
 assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,false);
 assert.equal(audit().changes.length,0);
});

test('final bonus reset adopts legacy marker once and preserves match points on duplicate runs',async()=>{
 const {awardFinalPoints}=require('../lib/final-points');
 await db.doc('eindstand_voorspellingen/u_A').set({seasonId:'2026-2027',divisie:'A',gebruikerId:'u',eindstand_A_punten:30});
 const before=(await db.doc('users/u').get()).data().punten_A;
 await db.doc('users/u').update({punten_A:before+30,totalen:before+30});
 await Promise.all([awardFinalPoints(db,'A',true),awardFinalPoints(db,'A',true)]);
 assert.equal((await db.doc('users/u').get()).data().punten_A,before);
 await assert.rejects(awardFinalPoints(db,'A'),/306/);
});


test('server endpoints reject ordinary users and source triggers ignore score metadata/time-only edits',async()=>{
 const f=require('../lib/result-functions');
 await assert.rejects(f.retryMatchResult.run({matchId:'A0'},{auth:{uid:'u'}}),e=>e.code==='permission-denied');
 await assert.rejects(f.processFinalStandings.run({division:'A'},{auth:{uid:'u'}}),e=>e.code==='permission-denied');
 const ref=db.doc(base+'/matches/A2'),before=await ref.get();
 await ref.update({scheduledAt:Timestamp.fromDate(new Date('2026-10-10T17:00:00Z'))});
 const after=await ref.get();
 await f.processMatchResult.run({before,after},{params:{seasonId:'2026-2027',matchId:'A2'}});
 assert.equal((await ref.get()).data().processingAttempts,before.data().processingAttempts);
 const pred=db.doc(base+'/predictions/u_A2'),p1=await pred.get();
 await pred.update({punten:123});const p2=await pred.get();
 await f.processSeasonPredictionEdit.run({before:p1,after:p2},{params:{seasonId:'2026-2027',id:'u_A2'}});
 assert.equal((await ref.get()).data().processingRequest,before.data().processingRequest);
 await pred.update({punten:p1.data().punten});
});


test('B: nine quick sequential moderator saves complete concurrently without lost points',async()=>{
 const fixture=await seed(),division=fixture.filter(m=>m.data.division==='A');
 const started=performance.now();for(const m of division)await finish(m.id);
 console.log(JSON.stringify({measurement:'9 source saves only, local emulator',milliseconds:performance.now()-started}));
 await Promise.all(division.map(m=>processMatch(db,m.id)));await invariant();
 assert.equal((await db.doc('users/u').get()).data().punten_A,90);
});


test('invalid source becomes failed without recursively processing its failure metadata',async()=>{
 const f=require('../lib/result-functions'),ref=db.doc(base+'/matches/bad');
 await ref.set({...fixture[0].data,homeTeamSlug:'unknown-club'});const before=await ref.get();
 await assert.rejects(processMatch(db,'bad'),/Unknown team/);const after=await ref.get();
 assert.equal(after.data().processingStatus,'failed');
 await f.processMatchResult.run({before,after},{params:{seasonId:'2026-2027',matchId:'bad'}});
 await assert.rejects(processMatch(db,'bad'),/Unknown team/);
 assert.deepEqual((await ref.get()).data(),after.data());await ref.delete();
});
