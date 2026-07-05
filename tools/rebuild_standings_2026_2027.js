const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const SEASON = '2026-2027';
const WRITE = process.env.WRITE === 'true';

function initFirebase() {
  if (!getApps().length) {
    initializeApp({
      projectId: 'derde-divisie-app',
    });
  }

  return getFirestore();
}

function chunkArray(items, size) {
  const chunks = [];

  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }

  return chunks;
}

function getTeamName(team) {
  return team.name || team.teamName || team.clubName || team.team || null;
}

function getTeamSlug(doc, team) {
  return team.slug || team.teamSlug || doc.id;
}

async function main() {
  const db = initFirebase();

  const teamsSnap = await db.collection(`seasons/${SEASON}/teams`).get();
  const standingsSnap = await db.collection(`seasons/${SEASON}/standings`).get();

  const teams = teamsSnap.docs.map((doc) => {
    const data = doc.data();

    return {
      docId: doc.id,
      name: getTeamName(data),
      slug: getTeamSlug(doc, data),
      division: data.division,
      logoAsset: data.logoAsset || data.logoPath || null,
      raw: data,
    };
  });

  const invalidTeams = teams.filter((team) => !team.name || !team.slug || !team.division);

  if (invalidTeams.length > 0) {
    console.log('Ongeldige team documenten gevonden:');
    console.log(invalidTeams);
    throw new Error('Stop. Niet alle teams hebben name, slug en division.');
  }

  const countA = teams.filter((team) => team.division === 'A').length;
  const countB = teams.filter((team) => team.division === 'B').length;

  console.log('Teams gevonden:', teams.length);
  console.log('Divisie A:', countA);
  console.log('Divisie B:', countB);
  console.log('Huidige standings docs:', standingsSnap.size);
  console.log('WRITE:', WRITE);

  if (teams.length !== 36 || countA !== 18 || countB !== 18) {
    throw new Error('Stop. Teams collectie is niet precies 18 A en 18 B.');
  }

  const duplicateNames = new Map();

  for (const team of teams) {
    const key = `${team.division}|${team.name}`;
    duplicateNames.set(key, (duplicateNames.get(key) || 0) + 1);
  }

  const duplicates = [...duplicateNames.entries()].filter(([, count]) => count > 1);

  if (duplicates.length > 0) {
    console.log('Dubbele teams in teams collectie:');
    console.log(duplicates);
    throw new Error('Stop. Dubbele teams gevonden.');
  }

  if (!WRITE) {
    console.log('');
    console.log('DRY RUN. Er wordt nog niets aangepast.');
    console.log('Nieuwe standings worden opgebouwd met deze teams:');

    teams
      .sort((a, b) => a.division.localeCompare(b.division) || a.name.localeCompare(b.name))
      .forEach((team) => {
        console.log(`${team.division} | ${team.slug} | ${team.name}`);
      });

    console.log('');
    console.log('Als dit klopt, draai dan:');
    console.log('$env:WRITE="true"');
    console.log('node tools/rebuild_standings_2026_2027.js');

    return;
  }

  for (const chunk of chunkArray(standingsSnap.docs, 450)) {
    const batch = db.batch();

    chunk.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
  }

  let positionA = 1;
  let positionB = 1;

  const sortedTeams = teams.sort((a, b) => {
    if (a.division !== b.division) {
      return a.division.localeCompare(b.division);
    }

    return a.name.localeCompare(b.name);
  });

  for (const chunk of chunkArray(sortedTeams, 450)) {
    const batch = db.batch();

    chunk.forEach((team) => {
      const position = team.division === 'A' ? positionA++ : positionB++;

      const ref = db
        .collection(`seasons/${SEASON}/standings`)
        .doc(team.slug);

      batch.set(ref, {
        season: SEASON,
        division: team.division,
        teamName: team.name,
        name: team.name,
        teamSlug: team.slug,
        slug: team.slug,
        logoAsset: team.logoAsset,

        position,
        played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        goalDifference: 0,
        points: 0,

        period1Points: 0,
        period2Points: 0,
        period3Points: 0,

        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
  }

  await db.collection('seasons').doc(SEASON).set({
    standingsRebuiltAt: FieldValue.serverTimestamp(),
    standingsCount: 36,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('');
  console.log('Klaar.');
  console.log('Oude standings verwijderd:', standingsSnap.size);
  console.log('Nieuwe standings geschreven:', sortedTeams.length);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});