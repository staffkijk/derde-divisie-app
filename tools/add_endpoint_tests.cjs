const fs=require('fs');const p='functions/integration/result-processor.test.cjs';let s=fs.readFileSync(p,'utf8');s=s.replace("await Promise.all(fixture.filter(m=>m.id!=='A0').map(async m=>{await finish(m.id);await processMatch(db,m.id);}));",`await Promise.all(fixture.filter(m=>m.data.division==='A'&&m.id!=='A0').map(async m=>{await finish(m.id);await processMatch(db,m.id);}));
 await invariant();assert.equal((await db.doc('users/u').get()).data().punten_A,90);
 await Promise.all(fixture.filter(m=>m.data.division==='B').map(async m=>{await finish(m.id);await processMatch(db,m.id);}));`);
s+=`

test('server endpoints reject ordinary users and source triggers ignore score metadata/time-only edits',async()=>{
 const f=require('../lib/result-functions');
 await assert.rejects(f.retryMatchResult.run({matchId:'A0'},{auth:{uid:'u'}}),e=>e.code==='permission-denied');
 await assert.rejects(f.processFinalStandings.run({division:'A'},{auth:{uid:'u'}}),e=>e.code==='permission-denied');
 const ref=db.doc(base+'/matches/A1'),before=await ref.get();
 await ref.update({scheduledAt:Timestamp.fromDate(new Date('2026-10-10T17:00:00Z'))});
 const after=await ref.get();
 await f.processMatchResult.run({before,after},{params:{seasonId:'2026-2027',matchId:'A1'}});
 assert.equal((await ref.get()).data().processingAttempts,before.data().processingAttempts);
 const pred=db.doc(base+'/predictions/u_A1'),p1=await pred.get();
 await pred.update({punten:123});const p2=await pred.get();
 await f.processSeasonPredictionEdit.run({before:p1,after:p2},{params:{seasonId:'2026-2027',id:'u_A1'}});
 assert.equal((await ref.get()).data().processingRequest,before.data().processingRequest);
 await pred.update({punten:p1.data().punten});
});
`;fs.writeFileSync(p,s);
