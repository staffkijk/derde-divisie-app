/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const {initializeApp, getApps, applicationDefault} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');

const REQUIRED_PROJECT = 'derde-divisie-app';
const APPLY = process.argv.includes('--apply');
const projectArg = process.argv.find((arg) => arg.startsWith('--project='));
const PROJECT_ID = projectArg?.split('=')[1] || process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT || REQUIRED_PROJECT;
const DATA_PATH = path.join(__dirname, 'data', 'club_venues.json');
const EXPECTED_CLUB_IDS = new Set([
  'acv','ado20','blauw_geel_38','dvs33_ermelo','evv_echt','excelsior31',
  'excelsior_maassluis','fc_lisse','fc_rijnvogels','harkemase_boys',
  'hvv_hollandia','vpv_purmersteijn','rbc','rksv_groene_ster','sc_genemuiden',
  'sportlust46','sv_poortugaal','sv_tec','svzw','togb','udi19','usv_hercules',
  'vv_achilles_veen','vv_dongen','vv_dovo','vv_eemdijk','vv_gemert','vv_goes',
  'vv_hoogeveen','vv_noordwijk','vv_scherpenzeel','vv_sparta_nijkerk',
  'vv_staphorst','vv_una','vv_zwaluwen','vvsb',
]);
const VENUE_FIELDS = ['venueName','venueAddress','venuePostalCode','venueCity'];

function loadAndValidate() {
  const rows = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
  if (!Array.isArray(rows)) throw new Error('club_venues.json moet een array zijn.');
  const ids = new Set();
  for (const row of rows) {
    if (!row.clubId || !row.name) throw new Error(`Ongeldige rij: ${JSON.stringify(row)}`);
    if (ids.has(row.clubId)) throw new Error(`Dubbele clubId: ${row.clubId}`);
    ids.add(row.clubId);
  }
  const missing = [...EXPECTED_CLUB_IDS].filter((id) => !ids.has(id));
  const unknown = [...ids].filter((id) => !EXPECTED_CLUB_IDS.has(id));
  const incomplete = rows.filter((row) => VENUE_FIELDS.some((key) => !String(row[key] || '').trim()));
  console.log(`Ontbrekende club-ID's: ${missing.length ? missing.join(', ') : 'geen'}`);
  console.log(`Onbekende club-ID's: ${unknown.length ? unknown.join(', ') : 'geen'}`);
  console.log(`Clubs met lege of onvolledige locatie: ${incomplete.length}`);
  if (incomplete.length) console.log(incomplete.map((row) => row.clubId).join(', '));
  if (missing.length || unknown.length) throw new Error('Club-ID-validatie mislukt.');
  return rows;
}

async function main() {
  console.log(`Firebase-project: ${PROJECT_ID}`);
  console.log(`Modus: ${APPLY ? 'APPLY' : 'DRY RUN'}`);
  console.log('Doelcollectie: teams/{clubId}');
  if (PROJECT_ID !== REQUIRED_PROJECT) {
    throw new Error(`Afgebroken: project moet ${REQUIRED_PROJECT} zijn.`);
  }
  const rows = loadAndValidate();
  if (!APPLY) {
    console.log(`Samenvatting: toegevoegd=0, aangevuld=0, overgeslagen=${rows.length}`);
    console.log('Dry run voltooid: Firestore is niet geïnitialiseerd en er is niets geschreven. Gebruik --apply om expliciet toe te passen.');
    return;
  }
  if (!getApps().length) initializeApp({credential: applicationDefault(), projectId: PROJECT_ID});
  const db = getFirestore();
  const existing = await db.collection('teams').get();
  const existingById = new Map(existing.docs.map((doc) => [doc.id, doc.data()]));
  const dataIds = new Set(rows.map((row) => row.clubId));
  const firestoreUnknown = existing.docs.map((doc) => doc.id).filter((id) => !dataIds.has(id));
  console.log(`Centrale documenten buiten gegevensbestand: ${firestoreUnknown.length ? firestoreUnknown.join(', ') : 'geen'}`);

  let added = 0; let updated = 0; let skipped = 0;
  for (const row of rows) {
    const current = existingById.get(row.clubId) || {};
    const payload = {};
    if (!String(current.name || '').trim()) payload.name = row.name;
    for (const key of VENUE_FIELDS) {
      const incoming = String(row[key] || '').trim();
      if (incoming && !String(current[key] || '').trim()) payload[key] = incoming;
    }
    if (!Object.keys(payload).length) { skipped += 1; continue; }
    if (!existingById.has(row.clubId)) added += 1; else updated += 1;
    if (APPLY) await db.collection('teams').doc(row.clubId).set(payload, {merge: true});
  }
  console.log(`Samenvatting: toegevoegd=${added}, aangevuld=${updated}, overgeslagen=${skipped}`);
}

main().catch((error) => { console.error(error.message || error); process.exitCode = 1; });
