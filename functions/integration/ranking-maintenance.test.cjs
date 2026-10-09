const assert = require('node:assert/strict');
const {test, after} = require('node:test');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {updateRankingMetadata} = require('../lib/ranking-fields');

if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Firestore emulator required');
const app = initializeApp({projectId: 'demo-ranking-maintenance-isolated', name: 'ranking-maintenance-test'});
const db = getFirestore(app);
after(async () => { await deleteApp(app); });

test('ranking metadata cannot overwrite historical scores or fill absent score fields', async () => {
  const ref = db.doc('users/ranking-maintenance-user');
  await db.doc('system/result_processing_maintenance').set({enabled:false});
  await ref.set({username:' FAN ',punten_A:15,totalen:212});
  await updateRankingMetadata(db,ref);
  assert.deepEqual((await ref.get()).data(),{
    username:' FAN ',punten_A:15,totalen:212,rankingName:'fan'
  });
  await updateRankingMetadata(db,ref);
  assert.equal((await ref.get()).data().punten_B,undefined);
});

test('active maintenance lock prohibits changes even to ranking metadata', async () => {
  const ref = db.doc('users/ranking-maintenance-user');
  await ref.update({username:'New name'});
  await db.doc('system/result_processing_maintenance').set({enabled:true});
  await updateRankingMetadata(db,ref);
  const user=(await ref.get()).data();
  assert.equal(user.rankingName,'fan');
  assert.equal(user.punten_A,15);
  assert.equal(user.totalen,212);
  await db.doc('system/result_processing_maintenance').set({enabled:false});
  await updateRankingMetadata(db,ref);
  assert.equal((await ref.get()).data().rankingName,'new name');
});
