const assert = require('node:assert/strict');
const {test, after} = require('node:test');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {processMatch} = require('../lib/result-processor');
const {teams} = require('../lib/season-teams');

if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required: production prohibited');
const app = initializeApp({projectId: 'demo-balance-protection-fixture', name: 'balance-protection'});
const db = getFirestore(app);
const base = 'seasons/2026-2027';
const a = teams.filter(t => t.division === 'A');
const date = Timestamp.fromDate(new Date('2026-10-10T13:00:00Z'));
const predicted = Timestamp.fromDate(new Date('2026-10-10T09:00:00Z'));
after(async () => {await deleteApp(app);});

async function arrange(id, user, fields) {
  const matchId = 'A' + id;
  await db.doc('users/' + user).set({username:'Fixture', ...fields});
  await db.doc(base + '/matches/' + matchId).set({
    division:'A', round:1, status:'finished', homeTeamSlug:a[0].id,
    awayTeamSlug:a[1].id, scheduledAt:date, homeScore:2, awayScore:1,
  });
  await db.doc(base + '/predictions/' + user + '_' + matchId).set({
    gebruikerId:user, wedstrijdId:matchId, scoreThuis:2, scoreUit:1,
    timestamp:predicted, verwerkt:true, punten:10, verwerktVoorUitslag:'2-1',
  });
  return matchId;
}

test('unreconciled historical total is never normalized on an incoming result', async () => {
  const matchId = await arrange('historical','historical',{punten_A:10,punten_B:5,totalen:212});
  await assert.rejects(processMatch(db,matchId),/Unreconciled user points/);
  const stored = (await db.doc('users/historical').get()).data();
  assert.equal(stored.punten_A,10);
  assert.equal(stored.punten_B,5);
  assert.equal(stored.totalen,212);
  assert.equal((await db.doc(base + '/matches/' + matchId).get()).data().processingStatus,'failed');
});

test('incomplete point fields are preserved, not silently replaced with zero', async () => {
  const matchId = await arrange('incomplete','incomplete',{punten_A:10,totalen:10});
  await assert.rejects(processMatch(db,matchId),/Unreconciled user points/);
  const stored = (await db.doc('users/incomplete').get()).data();
  assert.equal(stored.punten_B,undefined);
  assert.equal(stored.punten_A,10);
});

test('legacy scored prediction and duplicate old ledger never credit the same result again', async () => {
  const matchId = await arrange('legacy','legacy',{punten_A:10,punten_B:0,totalen:10});
  await db.doc(base + '/predictionContributions/old_format_' + matchId).set({
    userId:'legacy',matchId,division:'A',points:10,processed:true,
  });
  await processMatch(db,matchId);
  await processMatch(db,matchId);
  const stored = (await db.doc('users/legacy').get()).data();
  assert.equal(stored.punten_A,10);
  assert.equal(stored.totalen,10);
  assert.equal((await db.doc(base + '/predictionContributions/A__legacy__' + matchId).get()).data().points,10);
});

test('a failed match retry preserves disputed balance and never awards healthy user twice', async () => {
  const matchId=await arrange('mixed','disputed',{punten_A:10,punten_B:5,totalen:212});
  await db.doc('users/healthy').set({username:'Healthy',punten_A:0,punten_B:0,totalen:0});
  await db.doc(base + '/predictions/healthy_' + matchId).set({
    gebruikerId:'healthy',wedstrijdId:matchId,scoreThuis:2,scoreUit:1,
    timestamp:predicted,
  });
  for (let attempt=0;attempt<2;attempt++) {
    await assert.rejects(processMatch(db,matchId),/Unreconciled user points/);
    const disputed=(await db.doc('users/disputed').get()).data();
    const healthy=(await db.doc('users/healthy').get()).data();
    assert.deepEqual(
      {a:disputed.punten_A,b:disputed.punten_B,total:disputed.totalen},
      {a:10,b:5,total:212}
    );
    assert.equal(healthy.punten_A,10);
    assert.equal(healthy.totalen,10);
    assert.equal((await db.doc(base+'/matches/'+matchId).get()).data().processingStatus,'failed');
  }
});
