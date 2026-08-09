/* eslint-disable no-console */

const { initializeApp, getApps, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldPath } = require('firebase-admin/firestore');

const PROJECT_ID = 'derde-divisie-app';
const EXPECTED_SEASON_ID = '2026-2027';
const APPLY = process.argv.includes('--apply');

if (getApps().length === 0) {
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
}

const db = getFirestore();

async function main() {
  const currentSeason = await db.collection('system').doc('current_season').get();
  const seasonId = currentSeason.data()?.seasonId;
  if (seasonId !== EXPECTED_SEASON_ID) {
    throw new Error(
      `Veiligheidsstop: system/current_season is ${seasonId ?? 'niet gezet'}, ` +
        `verwacht ${EXPECTED_SEASON_ID}.`,
    );
  }

  const snapshot = await db.collection('users').orderBy(FieldPath.documentId()).get();
  const changes = snapshot.docs.flatMap((doc) => {
    const data = doc.data();
    const missing = ['punten_A', 'punten_B', 'totalen'].filter(
      (field) => !Object.prototype.hasOwnProperty.call(data, field),
    );
    return missing.length === 0 ? [] : [{ doc, missing }];
  });

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Actief seizoen: ${seasonId}`);
  console.log(`Users gecontroleerd: ${snapshot.size}`);
  console.log(`Users geraakt: ${changes.length}`);
  for (const change of changes) {
    console.log(`- users/${change.doc.id}: ${change.missing.join(', ')}`);
  }

  if (!APPLY) {
    console.log('DRY-RUN: niets geschreven. Gebruik --apply om alleen ontbrekende velden op 0 te zetten.');
    return;
  }

  let batch = db.batch();
  let operations = 0;
  let written = 0;
  for (const change of changes) {
    batch.set(
      change.doc.ref,
      Object.fromEntries(change.missing.map((field) => [field, 0])),
      { merge: true },
    );
    operations++;
    written++;
    if (operations === 450) {
      await batch.commit();
      batch = db.batch();
      operations = 0;
    }
  }
  if (operations > 0) await batch.commit();
  console.log(`APPLY voltooid: ${written} users aangevuld; bestaande velden zijn behouden.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
