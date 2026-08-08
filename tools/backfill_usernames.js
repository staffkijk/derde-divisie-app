/* eslint-disable no-console */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldPath } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');
const APPLY = process.argv.includes('--apply');

if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount) });
}

const db = getFirestore();

function usable(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function anonymize(value) {
  const text = String(value).trim();
  return `${text.slice(0, 2)}… (${text.length} tekens)`;
}

async function main() {
  const snapshot = await db.collection('users').orderBy(FieldPath.documentId()).get();
  const changes = snapshot.docs.flatMap((doc) => {
    const data = doc.data();
    if (usable(data.username)) return [];
    const source = usable(data.usernameLower)
      ? 'usernameLower'
      : usable(data.usernameKey)
        ? 'usernameKey'
        : null;
    return source === null
      ? []
      : [{ doc, source, username: data[source].trim() }];
  });

  console.log(`Project: ${serviceAccount.project_id}`);
  console.log(`Users gecontroleerd: ${snapshot.size}`);
  console.log(`Username-aanvullingen: ${changes.length}`);
  for (const change of changes.slice(0, 10)) {
    console.log(`- ${change.source}: ${anonymize(change.username)}`);
  }

  if (!APPLY) {
    console.log('DRY-RUN: niets geschreven. Gebruik expliciet --apply om username aan te vullen.');
    return;
  }

  let batch = db.batch();
  let operations = 0;
  for (const change of changes) {
    batch.set(change.doc.ref, { username: change.username }, { merge: true });
    operations++;
    if (operations === 450) {
      await batch.commit();
      batch = db.batch();
      operations = 0;
    }
  }
  if (operations > 0) await batch.commit();
  console.log(`APPLY voltooid: ${changes.length} usernames aangevuld.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
