// tools/import_matches_2026_2027.js
// Import Derde Divisie A/B programma 2026-2027 naar Firestore.
// Dry-run: node tools/import_matches_2026_2027.js
// Echt schrijven: $env:WRITE="true"; node tools/import_matches_2026_2027.js
// Overschrijven: $env:WRITE="true"; $env:OVERWRITE="true"; node tools/import_matches_2026_2027.js

const fs = require('fs');
const path = require('path');

const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const SEASON = '2026-2027';
const WRITE = process.env.WRITE === 'true';
const OVERWRITE = process.env.OVERWRITE === 'true';
const MATCHES_FILE = path.join(__dirname, 'matches_2026_2027.json');

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
    ? Number(match[1]) * 60 + (Number(match[2] || 0) * Math.sign(Number(match[1])))
    : 60;

  return new Date(Date.UTC(year, month - 1, day, hour, minute, 0) - offsetMinutes * 60 * 1000);
}

function chunkArray(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

function readMatches() {
  if (!fs.existsSync(MATCHES_FILE)) {
    throw new Error(`Bestand niet gevonden: ${MATCHES_FILE}`);
  }

  const parsed = JSON.parse(fs.readFileSync(MATCHES_FILE, 'utf8'));

  if (Array.isArray(parsed)) {
    return parsed;
  }

  if (Array.isArray(parsed.matches)) {
    return parsed.matches;
  }

  throw new Error('matches_2026_2027.json bevat geen array met wedstrijden.');
}

async function main() {
  const db = initFirebase();
  const matches = readMatches();

  if (matches.length !== 612) {
    throw new Error(`Verwacht 612 wedstrijden, gevonden: ${matches.length}`);
  }

  const ids = new Set(matches.map((m) => m.id));
  if (ids.size !== matches.length) {
    throw new Error(`Dubbele match-id gevonden. Uniek: ${ids.size}, totaal: ${matches.length}`);
  }

  const byDivision = matches.reduce((acc, match) => {
    acc[match.division] = (acc[match.division] || 0) + 1;
    return acc;
  }, {});

  console.log('Import programma', SEASON);
  console.log('Aantal wedstrijden:', matches.length, byDivision);
  console.log('WRITE:', WRITE);
  console.log('OVERWRITE:', OVERWRITE);

  if (!WRITE) {
    console.log('');
    console.log('DRY-RUN. Er wordt nog niets naar Firestore geschreven.');
    console.log('Voorbeeldwedstrijd:');
    console.log(matches[0]);
    console.log('');
    console.log('Als dit goed is, draai dan:');
    console.log('$env:WRITE="true"');
    console.log('node tools/import_matches_2026_2027.js');
    return;
  }

  let written = 0;
  let skipped = 0;

  for (const chunk of chunkArray(matches, 450)) {
    const batch = db.batch();
    let writesInBatch = 0;

    for (const match of chunk) {
      const ref = db
        .collection('seasons')
        .doc(SEASON)
        .collection('matches')
        .doc(match.id);

      const snapshot = await ref.get();

      if (snapshot.exists && !OVERWRITE) {
        skipped++;
        continue;
      }

      const data = {
        id: match.id,
        season: SEASON,
        division: match.division,
        round: match.round,
        roundMatchIndex: match.roundMatchIndex,

        date: match.date,
        weekdayNl: match.weekdayNl,
        kickoffTime: match.kickoffTime,
        kickoffTimeConfirmed: match.kickoffTimeConfirmed ?? false,
        kickoffTimeSource: match.kickoffTimeSource || 'club_default_or_fallback',
        scheduledAt: Timestamp.fromDate(
          amsterdamDateTimeToUtcDate(match.date, match.kickoffTime)
        ),

        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        homeTeamSlug: match.teamSlugs?.home || null,
        awayTeamSlug: match.teamSlugs?.away || null,

        homeScore: null,
        awayScore: null,
        status: 'scheduled',

        source: match.source || {
          type: 'official_pdf',
          season: SEASON,
        },

        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      };

      batch.set(ref, data, OVERWRITE ? { merge: true } : undefined);
      writesInBatch++;
      written++;
    }

    if (writesInBatch > 0) {
      await batch.commit();
    }
  }

  await db.collection('seasons').doc(SEASON).set({
    hasSchedule: true,
    scheduleImportedAt: FieldValue.serverTimestamp(),
    scheduleSource: 'KNVB official PDFs, kickoff times provisional',
    matchCount: matches.length,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('');
  console.log('Klaar.');
  console.log('Geschreven:', written);
  console.log('Overgeslagen bestaand:', skipped);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});