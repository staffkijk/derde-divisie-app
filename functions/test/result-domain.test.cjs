const assert=require('node:assert/strict');
const {test}=require('node:test');
const {Timestamp}=require('firebase-admin/firestore');
const d=require('../lib/result-domain');
const {teams}=require('../lib/season-teams');
const match={division:'A',round:1,status:'finished',homeScore:2,awayScore:1,homeTeamSlug:teams.find(t=>t.division==='A').id,
  awayTeamSlug:teams.filter(t=>t.division==='A')[1].id,scheduledAt:Timestamp.fromDate(new Date('2026-10-10T13:00:00Z'))};
test('all score combinations agree with the documented point rules',()=>{
 for(let h=0;h<6;h++)for(let a=0;a<6;a++)for(let ph=0;ph<6;ph++)for(let pa=0;pa<6;pa++) {
  const expected=ph===h&&pa===a?10:h===a&&ph===pa?7:(h!==a&&Math.sign(h-a)===Math.sign(ph-pa)?5:0)+(h===ph?2:0)+(a===pa?2:0);
  assert.equal(d.points(ph,pa,h,a),expected);
 }
});
test('Amsterdam noon deadline works in winter and summer',()=>{
 assert.equal(new Date(d.deadline(match)).toISOString(),'2026-10-10T10:00:00.000Z');
 assert.equal(new Date(d.deadline({...match,scheduledAt:Timestamp.fromDate(new Date('2027-01-10T13:00:00Z'))})).toISOString(),'2027-01-10T11:00:00.000Z');
});
test('same-day kickoff edits do not change score input; a new date does',()=>{
 assert.equal(d.fingerprint(match),d.fingerprint({...match,scheduledAt:Timestamp.fromDate(new Date('2026-10-10T17:00:00Z'))}));
 assert.notEqual(d.fingerprint(match),d.fingerprint({...match,scheduledAt:Timestamp.fromDate(new Date('2026-10-11T17:00:00Z'))}));
});
test('period boundaries, postponed results and 18 stable team rows',()=>{
 const inputs={m:d.contribution(match),late:d.contribution({...match,round:13}),cancelled:d.contribution({...match,status:'postponed'})};
 assert.equal(d.standings('A',inputs).length,18);
 assert.equal(d.standings('A',inputs).find(r=>r.teamId===match.homeTeamSlug).points,6);
 assert.equal(d.standings('A',inputs,1).find(r=>r.teamId===match.homeTeamSlug).points,3);
 assert.equal(d.standings('A',inputs,2).find(r=>r.teamId===match.homeTeamSlug).points,3);
 assert.equal(d.standings('A',inputs,3).find(r=>r.teamId===match.homeTeamSlug).points,0);
});
test('duplicate predictions have deterministic selection and enforce deadline',()=>{
 const p={gebruikerId:'u',scoreThuis:2,scoreUit:1,timestamp:Timestamp.fromDate(new Date('2026-10-10T09:00:00Z'))};
 const selected=d.selectLatest([{path:'z',data:p},{path:'a',data:p},{path:'late',data:{...p,timestamp:Timestamp.fromDate(new Date('2026-10-10T11:00:00Z'))}}],match);
 assert.equal(selected.get('u').path,'a');
});
test('configured teams match the Flutter active season',()=>{
 const fs=require('node:fs');const dart=fs.readFileSync('../lib/data/config/season_config.dart','utf8');
 const ids=[...dart.matchAll(/id: '([^']+)'/g)].map(m=>m[1]);
 assert.deepEqual(teams.map(t=>t.id).sort(),ids.sort());
 assert.equal(teams.filter(t=>t.division==='A').length,18);assert.equal(teams.filter(t=>t.division==='B').length,18);
});
