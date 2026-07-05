const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const SEASON = '2026-2027';

function initFirebase() {
  if (!getApps().length) {
    initializeApp({
      projectId: 'derde-divisie-app',
    });
  }

  return getFirestore();
}

async function printCollection(db, path) {
  const snap = await db.collection(path).get();

  console.log('');
  console.log('Collectie:', path);
  console.log('Aantal docs:', snap.size);

  const byDivision = {};
  const byName = {};

  snap.docs.forEach((doc) => {
    const data = doc.data();
    const name = data.teamName || data.name || data.team || data.clubName || doc.id;
    const division = data.division || data.poule || data.divisie || 'onbekend';

    byDivision[division] = (byDivision[division] || 0) + 1;
    byName[name] = byName[name] || [];
    byName[name].push({
      id: doc.id,
      division,
      data,
    });
  });

  console.log('Per divisie:', byDivision);

  const duplicates = Object.entries(byName).filter(([, rows]) => rows.length > 1);

  if (duplicates.length) {
    console.log('');
    console.log('Dubbele teams:');
    duplicates.forEach(([name, rows]) => {
      console.log(`- ${name}: ${rows.length}x`);
      rows.forEach((row) => {
        console.log(`  ${row.id} | divisie=${row.division}`);
      });
    });
  } else {
    console.log('Geen dubbele teamnamen gevonden.');
  }
}

async function main() {
  const db = initFirebase();

  await printCollection(db, `seasons/${SEASON}/standings`);
  await printCollection(db, `seasons/${SEASON}/teams`);

  const divA = await db.collection(`seasons/${SEASON}/divisions/A/teams`).get();
  const divB = await db.collection(`seasons/${SEASON}/divisions/B/teams`).get();

  console.log('');
  console.log(`seasons/${SEASON}/divisions/A/teams:`, divA.size);
  console.log(`seasons/${SEASON}/divisions/B/teams:`, divB.size);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});