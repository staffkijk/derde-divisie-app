// tools/normalize_team_names_2026_2027.js
// Uniformeert teamnamen seizoen 2026-2027 naar KNVB schrijfwijze.
// Dry-run:
// node tools/normalize_team_names_2026_2027.js
//
// Echt schrijven:
// $env:WRITE="true"; node tools/normalize_team_names_2026_2027.js

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

const TEAM_NAME_MAP = {
  "ADO'20": "ADO '20",
  "ADO ’20": "ADO '20",
  "Excelsior '31": "Excelsior'31",
  "HVV Hollandia": "Hollandia",
  "SV TEC": "TEC",
  "Sportlust '46": "Sportlust'46",
  "USV Hercules": "Hercules",
  "VPV Purmersteijn": "Purmersteijn",
  "VV DOVO": "DOVO",
  "VV Eemdijk": "Eemdijk",
  "VV Hoogeveen": "Hoogeveen",
  "VV Scherpenzeel": "Scherpenzeel",
  "VV Sparta Nijkerk": "Sparta Nijkerk",
  "VV Staphorst": "Staphorst",

  "Blauw Geel '38": "Blauw Geel'38/Jumbo",
  "Blauw Geel'38/JUMBO": "Blauw Geel'38/Jumbo",
  "Blauw Geel'38/Jumbo": "Blauw Geel'38/Jumbo",
  "FC Rijnvogels": "Rijnvogels",
  "GOES": "Goes",
  "RKSV Groene Ster": "Groene Ster",
  "SV Poortugaal": "sv Poortugaal",
  "VV Achilles Veen": "Achilles Veen",
  "VV Dongen": "Dongen",
  "VV Gemert": "Gemert",
  "VV Noordwijk": "Noordwijk",
  "VV UNA": "UNA",
  "VV Zwaluwen": "Zwaluwen",
};

const FIELD_NAMES = [
  'name',
  'teamName',
  'displayName',
  'clubName',
  'team',
  'homeTeam',
  'awayTeam',
];

function normalizeName(value) {
  if (typeof value !== 'string') return value;

  const trimmed = value.trim();

  return TEAM_NAME_MAP[trimmed] || trimmed;
}

function collectUpdates(data, fields) {
  const updates = {};

  for (const field of fields) {
    if (!Object.prototype.hasOwnProperty.call(data, field)) continue;

    const oldValue = data[field];
    const newValue = normalizeName(oldValue);

    if (newValue !== oldValue) {
      updates[field] = newValue;
    }
  }

  return updates;
}

function logChange(path, updates, data) {
  const parts = Object.entries(updates).map(([field, value]) => {
    return `${field}: "${data[field]}" -> "${value}"`;
  });

  console.log(`${path}`);
  console.log(`  ${parts.join(', ')}`);
}

async function updateCollectionDocs(db, collectionPath, fields) {
  const snap = await db.collection(collectionPath).get();

  let changed = 0;
  const writes = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const updates = collectUpdates(data, fields);

    if (Object.keys(updates).length === 0) continue;

    changed++;
    logChange(`${collectionPath}/${doc.id}`, updates, data);

    writes.push({
      ref: doc.ref,
      updates: {
        ...updates,
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }

  if (WRITE) {
    for (const chunk of chunkArray(writes, 450)) {
      const batch = db.batch();

      for (const item of chunk) {
        batch.set(item.ref, item.updates, { merge: true });
      }

      await batch.commit();
    }
  }

  return {
    total: snap.size,
    changed,
  };
}

async function updateSeasonDivisionTeamArrays(db) {
  const ref = db.collection('seasons').doc(SEASON);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new Error(`Seizoensdocument niet gevonden: seasons/${SEASON}`);
  }

  const data = snap.data();
  const divisions = data.divisions || {};
  const updates = {};

  for (const divisionCode of ['A', 'B']) {
    const teams = divisions?.[divisionCode]?.teams;

    if (!Array.isArray(teams)) continue;

    const normalizedTeams = teams.map(normalizeName);
    const changed = normalizedTeams.some((team, index) => team !== teams[index]);

    if (!changed) continue;

    updates[`divisions.${divisionCode}.teams`] = normalizedTeams;

    console.log(`seasons/${SEASON} divisions.${divisionCode}.teams`);
    teams.forEach((oldName, index) => {
      const newName = normalizedTeams[index];

      if (oldName !== newName) {
        console.log(`  "${oldName}" -> "${newName}"`);
      }
    });
  }

  if (WRITE && Object.keys(updates).length > 0) {
    await ref.set({
      ...updates,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  return {
    changed: Object.keys(updates).length,
  };
}

async function main() {
  const db = initFirebase();

  console.log('Uniformeren teamnamen', SEASON);
  console.log('WRITE:', WRITE);
  console.log('');

  const seasonDocResult = await updateSeasonDivisionTeamArrays(db);

  const teamsResult = await updateCollectionDocs(
    db,
    `seasons/${SEASON}/teams`,
    ['name', 'teamName', 'displayName', 'clubName', 'team']
  );

  const matchesResult = await updateCollectionDocs(
    db,
    `seasons/${SEASON}/matches`,
    ['homeTeam', 'awayTeam']
  );

  const standingsResult = await updateCollectionDocs(
    db,
    `seasons/${SEASON}/standings`,
    ['name', 'teamName', 'displayName', 'clubName', 'team']
  );

  const periodResult = await updateCollectionDocs(
    db,
    `seasons/${SEASON}/periodStandings`,
    ['name', 'teamName', 'displayName', 'clubName', 'team']
  );

  if (WRITE) {
    await db.collection('seasons').doc(SEASON).set({
      teamNamesNormalizedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  console.log('');
  console.log('Samenvatting');
  console.log('Seizoensdocument arrays aangepast:', seasonDocResult.changed);
  console.log('Teams docs aangepast:', `${teamsResult.changed}/${teamsResult.total}`);
  console.log('Matches docs aangepast:', `${matchesResult.changed}/${matchesResult.total}`);
  console.log('Standings docs aangepast:', `${standingsResult.changed}/${standingsResult.total}`);
  console.log('Periodestand docs aangepast:', `${periodResult.changed}/${periodResult.total}`);

  if (!WRITE) {
    console.log('');
    console.log('DRY-RUN. Er is niets aangepast.');
    console.log('Als dit klopt, draai dan:');
    console.log('$env:WRITE="true"; node tools/normalize_team_names_2026_2027.js');
  } else {
    console.log('');
    console.log('Klaar. Teamnamen zijn aangepast.');
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});