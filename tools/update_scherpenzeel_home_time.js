// tools/update_scherpenzeel_home_time.js
// Corrigeer Scherpenzeel-thuiswedstrijden 2026-2027 naar 15:00.
// Dry-run: node tools/update_scherpenzeel_home_time.js
// Echt schrijven: $env:WRITE="true"; node tools/update_scherpenzeel_home_time.js

const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const SEASON = '2026-2027';
const HOME_TEAM = 'Scherpenzeel';
const NEW_KICKOFF_TIME = '15:00';
const WRITE = process.env.WRITE === 'true';

function initFirebase() {
  if (!getApps().length) {
    initializeApp({
      projectId: 'derde-divisie-app',
    });
  }

  return getFirestore();
}

function amsterdamDateTimeToUtcDate(date, time) {
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);

  const utcGuess = new Date(Date.UTC(year, month - 1, day, hour, minute, 0));
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Europe/Amsterdam',
    timeZoneName: 'shortOffset',
  }).formatToParts(utcGuess);

  const tzName = parts.find((part) => part.type === 'timeZoneName')?.value || 'GMT+1';
  const match = tzName.match(/GMT([+-]\d{1,2})(?::(\d{2}))?/);

  const offsetMinutes = match
    ? Number(match[1]) * 60 + Number(match[2] || 0) * Math.sign(Number(match[1]))
    : 60;

  return new Date(Date.UTC(year, month - 1, day, hour, minute, 0) - offsetMinutes * 60 * 1000);
}

function normalizeDate(value, documentId) {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }

  throw new Error(`Document ${documentId} heeft geen geldige date in formaat YYYY-MM-DD.`);
}

function chunkArray(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

async function main() {
  const db = initFirebase();
  const snapshot = await db
    .collection('seasons')
    .doc(SEASON)
    .collection('matches')
    .where('homeTeam', '==', HOME_TEAM)
    .get();

  const rows = snapshot.docs.map((doc) => {
    const data = doc.data();
    const date = normalizeDate(data.date, doc.id);

    return {
      ref: doc.ref,
      update: {
        kickoffTime: NEW_KICKOFF_TIME,
        scheduledAt: Timestamp.fromDate(amsterdamDateTimeToUtcDate(date, NEW_KICKOFF_TIME)),
        kickoffTimeConfirmed: false,
        kickoffTimeSource: 'club_default_corrected',
        updatedAt: FieldValue.serverTimestamp(),
      },
      dryRun: {
        documentId: doc.id,
        thuisclub: data.homeTeam,
        uitclub: data.awayTeam,
        datum: date,
        oudeTijd: data.kickoffTime ?? null,
        nieuweTijd: NEW_KICKOFF_TIME,
      },
    };
  });

  console.log(`Scherpenzeel-thuiswedstrijden gevonden: ${rows.length}`);
  console.log(`WRITE: ${WRITE}`);
  console.log('');

  if (rows.length > 0) {
    console.table(rows.map((row) => row.dryRun));
  }

  if (!WRITE) {
    console.log('');
    console.log('DRY-RUN. Er is niets naar Firestore geschreven.');
    console.log('Schrijven kan met: $env:WRITE="true"; node tools/update_scherpenzeel_home_time.js');
    return;
  }

  let written = 0;
  for (const chunk of chunkArray(rows, 450)) {
    const batch = db.batch();

    for (const row of chunk) {
      batch.update(row.ref, row.update);
      written++;
    }

    await batch.commit();
  }

  console.log('');
  console.log(`Klaar. Bijgewerkte documenten: ${written}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
