const fs=require('fs');const p='functions/integration/result-processor.test.cjs';let s=fs.readFileSync(p,'utf8');s=s.replace(/await Promise.all\(fixture.filter\(m=>m.data.division==='A'[\s\S]*?await Promise.all\(fixture.filter\(m=>m.data.division==='B'\).map\(async m=>\{await finish\(m.id\);await processMatch\(db,m.id\);\}\)\);/,"await Promise.all(fixture.filter(m=>m.id!=='A0').map(async m=>{await finish(m.id);await processMatch(db,m.id);}));");s+=`

test('B: nine quick sequential moderator saves complete concurrently without lost points',async()=>{
 const fixture=await seed(),division=fixture.filter(m=>m.data.division==='A');
 const started=performance.now();for(const m of division)await finish(m.id);
 console.log(JSON.stringify({measurement:'9 source saves only, local emulator',milliseconds:performance.now()-started}));
 await Promise.all(division.map(m=>processMatch(db,m.id)));await invariant();
 assert.equal((await db.doc('users/u').get()).data().punten_A,90);
});
`;fs.writeFileSync(p,s);
