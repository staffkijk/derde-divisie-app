// Dry-run: node tools/update_scherpenzeel_kickoff_2026_2027.js
// Write:   $env:WRITE="true"; node tools/update_scherpenzeel_kickoff_2026_2027.js

const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const SEASON = '2026-2027';
const TARGET_TIME = '15:00';
const TARGET_SOURCE = 'club_default_scherpenzeel_1500';
const WRITE = process.env.WRITE === 'true';

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function isScherpenzeelHome(data) {
  const values = [
    data.homeTeamSlug,
    data.homeTeamCode,
    data.homeTeamName,
    data.homeTeam,
    data.thuisteam,
  ].map(normalize);

  return values.includes('vvscherpenzeel') || values.includes('scherpenzeel');
}

function isConfirmed(data) {
  const value = data.kickoffTimeConfirmed;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  return ['true', '1', 'yes', 'ja'].includes(String(value || '').toLowerCase());
}

function initDb() {
  if (!getApps().length) {
    initializeApp({ projectId: 'derde-divisie-app' });
  }
  return getFirestore();
}

async function main() {
  const db = initDb();
  const snapshot = await db
    .collection('seasons')
    .doc(SEASON)
    .collection('matches')
    .get();

  const found = [];
  const skipped = [];
  const updates = [];

  for (const doc of snapshot.docs) {
    if (doc.id === '_meta') continue;
    const data = doc.data();
    if (!isScherpenzeelHome(data)) continue;

    found.push(doc);

    if (isConfirmed(data)) {
      skipped.push({ id: doc.id, reason: 'kickoffTimeConfirmed=true', old: data.kickoffTime || null });
      continue;
    }

    if (data.kickoffTime === TARGET_TIME && data.kickoffTimeSource === TARGET_SOURCE) {
      skipped.push({ id: doc.id, reason: 'already-correct', old: data.kickoffTime || null });
      continue;
    }

    updates.push({
      ref: doc.ref,
      id: doc.id,
      home: data.homeTeamName || data.homeTeam || data.thuisteam || '',
      away: data.awayTeamName || data.awayTeam || data.uitteam || '',
      date: data.date || data.matchDate || null,
      oldTime: data.kickoffTime || null,
      newTime: TARGET_TIME,
      oldSource: data.kickoffTimeSource || null,
      newSource: TARGET_SOURCE,
    });
  }

  console.log(`Seizoen: ${SEASON}`);
  console.log(`WRITE: ${WRITE}`);
  console.log(`Scherpenzeel-thuiswedstrijden gevonden: ${found.length}`);
  console.log(`Overgeslagen: ${skipped.length}`);
  console.log(`Te wijzigen: ${updates.length}`);

  if (updates.length) {
    console.table(
      updates.map(({ id, home, away, date, oldTime, newTime, oldSource, newSource }) => ({
        id,
        home,
        away,
        date,
        oldTime,
        newTime,
        oldSource,
        newSource,
      })),
    );
  }

  if (skipped.length) {
    console.table(skipped);
  }

  if (!WRITE) {
    console.log('DRY RUN: er is niets naar Firestore geschreven.');
    return;
  }

  const batch = db.batch();
  for (const update of updates) {
    batch.update(update.ref, {
      kickoffTime: TARGET_TIME,
      kickoffTimeSource: TARGET_SOURCE,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Klaar. Bijgewerkte documenten: ${updates.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
