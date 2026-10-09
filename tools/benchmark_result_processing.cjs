const adminRequire=require('node:module').createRequire(require('node:path').resolve(__dirname,'../functions/package.json'));
/* Local repeatable query benchmark. Refuses production. */
const fs=require('node:fs');const {performance}=require('node:perf_hooks');
const {initializeApp,deleteApp}=adminRequire('firebase-admin/app');
const {getFirestore,FieldPath,Timestamp}=adminRequire('firebase-admin/firestore');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Local emulator required');
const app=initializeApp({projectId:'demo-derdediv-benchmark'}),db=getFirestore(app),base='seasons/2026-2027';
async function main(){
 for(const collection of ['users',base+'/matches',base+'/teams',base+'/standings',base+'/processingAggregates',base+'/predictionContributions','voorspellingen','activityLogs'])await db.recursiveDelete(db.collection(collection));
 const {teams}=require('../functions/lib/season-teams'),{standings}=require('../functions/lib/result-domain');
 const writes=[];for(const t of teams)writes.push([base+'/teams/'+t.id,t]);for(const row of standings('B',{}))writes.push([base+'/standings/B_'+row.teamId,row]);
 for(let i=0;i<1000;i++)writes.push(['users/u'+i,{punten_A:i,punten_B:0,totalen:i,rankingName:'user'+String(i).padStart(4,'0')}]);
 for(let i=0;i<612;i++){const id='m'+i;writes.push([base+'/matches/'+id,{division:i<306?'A':'B',round:Math.floor((i%306)/9)+1,status:i%306<45?'finished':'scheduled'}]);writes.push(['voorspellingen/u_'+id,{gebruikerId:'u',wedstrijdId:id,timestamp:Timestamp.now()}]);}
 for(let i=0;i<100;i++)writes.push(['activityLogs/l'+i,{createdAt:Timestamp.now()}]);
 for(let i=0;i<writes.length;i+=400){const batch=db.batch();for(const [p,d]of writes.slice(i,i+400))batch.set(db.doc(p),d);await batch.commit();}
 const measure=async(fn)=>{const times=[];let returned;for(let i=0;i<6;i++){const start=performance.now();returned=await fn();if(i)times.push(performance.now()-start);}times.sort((a,b)=>a-b);return {medianMs:+times[2].toFixed(2),returnedDocuments:returned};};
 const result={environment:'Windows, local Firestore emulator, warm median of 5 runs; excludes mobile network/rendering',fixture:{users:1000,matches:612,predictions:612,logs:100},comparisons:{}};
 result.comparisons.ranking={before:await measure(async()=> (await db.collection('users').get()).size),after:await measure(async()=> (await db.collection('users').orderBy('punten_A','desc').orderBy('rankingName').orderBy(FieldPath.documentId()).limit(50).get()).size)};
 result.comparisons.dashboard={before:await measure(async()=>{const r=await Promise.all([db.collection(base+'/matches').get(),db.collection('activityLogs').limit(100).get()]);return r.reduce((n,s)=>n+s.size,0);}),after:await measure(async()=>{const matches=db.collection(base+'/matches');await Promise.all([matches.count().get(),matches.where('processed','==',true).where('status','==','finished').count().get(),matches.where('processingStatus','==','failed').count().get(),db.collection('activityLogs').orderBy('createdAt','desc').limit(100).count().get(),matches.where('status','==','scheduled').count().get(),matches.where('status','==','postponed').count().get()]);return 0;})};
 result.comparisons.relevantRound={before:await measure(async()=> (await db.collection(base+'/matches').where('division','==','A').get()).size),after:await measure(async()=> (await db.collection(base+'/matches').where('division','==','A').where('status','in',['scheduled','postponed']).orderBy('round').limit(1).get()).size)};
 result.comparisons.predictionMatches={before:await measure(async()=> (await db.collection(base+'/matches').get()).size),after:await measure(async()=> (await db.collection(base+'/matches').where(FieldPath.documentId(),'in',Array.from({length:9},(_,i)=>'m'+i)).get()).size)};
 // Measure source writes separately from completion of the new pipeline.
 const {processMatch}=require('../functions/lib/result-processor');
 const clubs=teams.filter(t=>t.division==='A');await db.doc('users/u').set({punten_A:0,punten_B:0,totalen:0,rankingName:'u'});
 for(let i=0;i<9;i++){
  await db.doc(base+'/matches/m'+i).update({status:'scheduled',homeTeamSlug:clubs[i*2].id,awayTeamSlug:clubs[i*2+1].id,scheduledAt:Timestamp.fromDate(new Date('2027-01-01T14:00:00Z'))});
  await db.doc('voorspellingen/u_m'+i).update({scoreThuis:2,scoreUit:1,timestamp:Timestamp.fromDate(new Date('2026-08-01T09:00:00Z'))});
 }
 const writeStart=performance.now();for(let i=0;i<9;i++)await db.doc(base+'/matches/m'+i).update({status:'finished',homeScore:2,awayScore:1});
 const saved=performance.now();await Promise.all(Array.from({length:9},(_,i)=>processMatch(db,'m'+i)));
 result.processing={sourceWrites9Ms:+(saved-writeStart).toFixed(2),completionAfterSave9Ms:+(performance.now()-saved).toFixed(2),verifiedUserPoints:(await db.doc('users/u').get()).data().punten_A};
 result.comparisons.standings={before:await measure(async()=>{const r=await Promise.all([db.collection(base+'/standings').get(),db.collection(base+'/teams').get(),db.collection(base+'/matches').get(),db.collection(base+'/standings').get()]);return r.reduce((n,s)=>n+s.size,0);}),after:await measure(async()=> (await db.collection(base+'/standings').where('division','==','A').get()).size)};
 result.sameDayKickoffWrite=await measure(async()=>{await db.doc(base+'/matches/m0').update({scheduledAt:Timestamp.fromDate(new Date('2027-01-01T18:00:00Z'))});return 0;});
 fs.mkdirSync('docs/reliability',{recursive:true});fs.writeFileSync('docs/reliability/query-benchmark.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));await deleteApp(app);
}main().catch(e=>{console.error(e);process.exitCode=1;});
