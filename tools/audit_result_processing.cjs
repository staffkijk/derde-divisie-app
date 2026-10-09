const adminRequire=require('node:module').createRequire(require('node:path').resolve(__dirname,'../functions/package.json'));
/* Safe active-season audit. Dry run by default. Never deletes source data. */
const fs=require('node:fs');
const {initializeApp,applicationDefault}=adminRequire('firebase-admin/app');
const {getFirestore,FieldPath,FieldValue}=adminRequire('firebase-admin/firestore');
const {ACTIVE_SEASON,division,result,contribution,standings,selectLatest,uid,score,points,integer,fingerprint}=require('../functions/lib/result-domain');
const {predictionDocs}=require('../functions/lib/result-processor');
const args=process.argv.slice(2),value=name=>args.findLast(a=>a.startsWith(name+'='))?.slice(name.length+1);
const project=value('--project');
if(!project || !['derde-divisie-app','demo-derdediv-processing'].includes(project))throw Error('Use an explicit approved --project=derde-divisie-app or demo-derdediv-processing');
const apply=args.includes('--apply'),emulator=!!process.env.FIRESTORE_EMULATOR_HOST;
if(apply && !emulator && value('--confirm-production')!==project)throw Error('Production apply requires explicit --confirm-production=derde-divisie-app after human approval');
if(!emulator && project.startsWith('demo-'))throw Error('Demo project requires emulator');
initializeApp({projectId:project,...(!emulator?{credential:applicationDefault()}:{})});const db=getFirestore();
const base=`seasons/${ACTIVE_SEASON}`,lock=db.doc('system/result_processing_maintenance');
async function all(collection) {
 const docs=[];let last;
 for(;;){let q=db.collection(collection).orderBy(FieldPath.documentId()).limit(300);if(last)q=q.startAfter(last);
  const page=await q.get();docs.push(...page.docs);if(page.size<300)break;last=page.docs.at(-1);}
 return docs;
}
async function main() {
 let locked=false,writesStarted=false,completed=false,resuming=false;
 try {
  if(apply){await db.runTransaction(async tx=>{const state=await tx.get(lock);if(state.data()?.enabled && !args.includes('--resume-maintenance'))throw Error('Maintenance active. Inspect the previous backup/report before --resume-maintenance');resuming=state.data()?.enabled===true;tx.set(lock,{enabled:true,seasonId:ACTIVE_SEASON,startedAt:FieldValue.serverTimestamp()});});locked=true;}
  const matches=(await all(`${base}/matches`)).filter(d=>d.id!=='_meta');
  const users=await all('users'),userById=new Map(users.map(d=>[d.id,d]));
  const bonus=await all('eindstand_voorspellingen');
  const changes=[],issues=[],expectedTotals=new Map(),pouleTotals=new Map(),backup=[],expectedLedgers=new Set(),bonusOwners=new Set();
  const expected=(id)=>{if(!expectedTotals.has(id))expectedTotals.set(id,{punten_A:0,punten_B:0});return expectedTotals.get(id);};
  function plan(path,data,current) {
   if(!current || Object.entries(data).some(([k,v])=>JSON.stringify(current[k])!==JSON.stringify(v))){changes.push({path,data});}
  }
  const knownPoules=new Set();
  for(const c of ['predictionContributions','pouleContributions'])for(const doc of await all(base+'/'+c))if(doc.data().pouleId)knownPoules.add(doc.data().pouleId);
  for(const doc of await all('poules'))if(doc.data().seasonId===ACTIVE_SEASON)knownPoules.add(doc.id);
  for(const id of knownPoules)for(const doc of await all('poules/'+id+'/deelnemers'))pouleTotals.set(doc.ref.path,0);
  const byDivision={A:{},B:{}};
  for(const match of matches){const m=match.data();try{byDivision[division(m)][match.id]=contribution(m);}catch(error){issues.push({path:match.ref.path,error:String(error)});}}
  for(const div of ['A','B']) {
   if(Object.keys(byDivision[div]).length!==306)issues.push({division:div,error:`Expected 306 matches, found ${Object.keys(byDivision[div]).length}`});
   for(let period=0;period<=3;period++) {
    const collection=period?'periodStandings':'standings',stored=new Map((await all(`${base}/${collection}`)).map(d=>[d.id,d.data()]));
    for(const row of standings(div,byDivision[div],period)) {
     const id=period?`${div}_P${period}_${row.teamId}`:`${div}_${row.teamId}`;plan(`${base}/${collection}/${id}`,row,stored.get(id));
    }
   }
   plan(`${base}/processingAggregates/${div}`,{contributions:byDivision[div]},(await db.doc(`${base}/processingAggregates/${div}`).get()).data());
  }
  // Match-scoped queries keep this audit independent of historic season documents.
  for(const match of matches) {
   const m=match.data();let div,r;try{div=division(m);r=result(m);}catch(_){continue;}
   const generalDocs=await predictionDocs(db,match.id,[`${base}/predictions`,'voorspellingen']);
   const pouleDocs=await predictionDocs(db,match.id,['poule_predictions','poule_voorspellingen','predictions']);
   const selected=selectLatest(generalDocs,m),poules=selectLatest(pouleDocs,m,true);
   for(const [user,doc]of selected) {
    try {
     const next=r?points(score(doc.data,true),score(doc.data,false),...r):0;
     expected(user)[`punten_${div}`]+=next;
     const ledger=`${base}/predictionContributions/${div}__${user}__${match.id}`;
     const fields={punten:next,verwerkt:!!r,verwerktVoorUitslag:r?r.join('-'):''};
     plan(doc.path,fields,doc.data);
     const ledgerData={userId:user,matchId:match.id,division:div,predictionPath:doc.path,points:next,processed:!!r,resultKey:r?r.join('-'):'',inputKey:fingerprint(m)};
     expectedLedgers.add(ledger);
     plan(ledger,ledgerData,(await db.doc(ledger).get()).data());
    }catch(error){issues.push({path:doc.path,error:String(error)});}
   }
   for(const doc of poules.values()) {
    try {
     const user=uid(doc.data),poule=String(doc.data.pouleId??doc.data.poule??'');if(!poule)throw Error('Missing poule');
     const next=r?points(score(doc.data,true),score(doc.data,false),...r):0;
     const participant=`poules/${poule}/deelnemers/${user}`;
     const direct=await db.doc(participant).get();
     const participantDoc=direct.exists?direct:(await db.collection(`poules/${poule}/deelnemers`).where('userId','==',user).limit(1).get()).docs[0];
     if(!participantDoc)throw Error('Missing participant');
     pouleTotals.set(participantDoc.ref.path,(pouleTotals.get(participantDoc.ref.path)??0)+next);
     plan(doc.path,{punten:next,verwerkt:!!r,verwerktVoorUitslag:r?r.join('-'):''},doc.data);
     const ledger=`${base}/pouleContributions/${poule}__${user}__${match.id}`;
     expectedLedgers.add(ledger);
     plan(ledger,{userId:user,pouleId:poule,matchId:match.id,division:div,predictionPath:doc.path,points:next,processed:!!r,resultKey:r?r.join('-'):'',inputKey:fingerprint(m)},(await db.doc(ledger).get()).data());
    }catch(error){issues.push({path:doc.path,error:String(error)});}
   }
   const chosen=new Set([...selected.values(),...poules.values()].map(d=>d.path));
   for(const doc of [...generalDocs,...pouleDocs])if(!chosen.has(doc.path)&&(!doc.data.seasonId||doc.data.seasonId===ACTIVE_SEASON))plan(doc.path,{punten:0,verwerkt:false,verwerktVoorUitslag:''},doc.data);
  }
  // Preserve the awarded season-end bonus separately from match contributions.
  for(const doc of bonus){const d=doc.data();if(d.seasonId && d.seasonId!==ACTIVE_SEASON)continue;
   if(!d.seasonId && (integer(d.eindstand_A_punten)||integer(d.eindstand_B_punten))){issues.push({path:doc.ref.path,error:'Awarded bonus lacks a season; verify manually before repair'});continue;}
   const user=uid(d);if(!user)continue;const div=String(d.divisie??'');if(['A','B'].includes(div)){const key=div+'__'+user;if(bonusOwners.has(key)){issues.push({path:doc.ref.path,error:'Duplicate bonus ownership; verify manually'});continue;}bonusOwners.add(key);expected(user)[`punten_${div}`]+=integer(d[`eindstand_${div}_punten`]);
     const path=`${base}/endstandContributions/${div}__${user}`;plan(path,{userId:user,division:div,points:integer(d[`eindstand_${div}_punten`]),predictionPath:doc.ref.path},(await db.doc(path).get()).data());}}
  for(const user of users) {
   const data=user.data(),totals=expectedTotals.get(user.id)??{punten_A:0,punten_B:0};
   for(const div of ['A','B'])if(data[div==='A'?'eindstandA_awarded':'eindstandB_awarded'] && !bonusOwners.has(div+'__'+user.id))issues.push({path:user.ref.path,error:'Awarded bonus has no current-season marker'});
   const name=[data.username,data.usernameLower,data.usernameKey].find(v=>typeof v==='string'&&v.trim())??'Onbekend';
   plan(user.ref.path,{...totals,totalen:Math.max(totals.punten_A,totals.punten_B),rankingName:name.trim().toLowerCase()},data);
  }
  for(const [path,total]of pouleTotals)plan(path,{punten:total},(await db.doc(path).get()).data());
  // Old ledger-only entries must be zeroed as well, including deleted predictions.
  const desired=new Map(changes.map(c=>[c.path,c.data]));
  for(const collection of ['predictionContributions','pouleContributions'])for(const doc of await all(`${base}/${collection}`)) {
   const d=doc.data();if(!matches.some(m=>m.id===d.matchId)){issues.push({path:doc.ref.path,error:'Orphan ledger without active match'});continue;}
   if(expectedLedgers.has(doc.ref.path))continue;
   if(!desired.has(doc.ref.path))plan(doc.ref.path,{points:0,processed:false,resultKey:''},d);
  }
  const report={season:ACTIVE_SEASON,project,mode:apply?'apply':'dry-run',matchCounts:Object.fromEntries(Object.entries(byDivision).map(([d,c])=>[d,Object.keys(c).length])),issues,changes};
  for(const id of expectedTotals.keys())if(!userById.has(id))issues.push({path:'users/'+id,error:'Missing prediction owner'});
  const out=value('--output')??'result-processing-audit.json';fs.writeFileSync(out,JSON.stringify(report,null,2));
  console.log(JSON.stringify({mode:report.mode,season:ACTIVE_SEASON,changes:changes.length,issues:issues.length,report:out}));
  if(!apply)return;
  if(issues.length && !(emulator && args.includes('--allow-fixture') && issues.every(i=>i.error.startsWith('Expected 306'))))throw Error('Audit has unresolved issues; no corrections written');
  for(const change of changes){const doc=await db.doc(change.path).get();backup.push({path:change.path,exists:doc.exists,data:doc.data()??null});}
  fs.writeFileSync(out+'.backup.json',JSON.stringify(backup,null,2),{flag:'wx'});
  for(let i=0;i<changes.length;i+=400){writesStarted=true;const batch=db.batch();for(const c of changes.slice(i,i+400))batch.set(db.doc(c.path),c.data,{merge:true});await batch.commit();if(emulator && value('--fail-after-batch')===String(Math.floor(i/400)+1))throw Error('Injected emulator-only interruption after committed batch');}
  completed=true;
  console.log('Corrections completed. Run dry-run again to verify. Source predictions and match results were preserved.');
 }finally{if(locked && (completed || (!writesStarted && !resuming)))await lock.set({enabled:false,completedAt:FieldValue.serverTimestamp()},{merge:true});}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
