/* eslint-disable no-console */
/**
 * Apply the validated synthetic 2026/2027 dataset.
 * Default is a read-only dry run. Firestore writes require explicit --apply.
 * This script never uses Firebase Authentication.
 */
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { spawnSync } = require('child_process');
const { applicationDefault, getApps, initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'derde-divisie-app';
const SEASON = '2026-2027';
const FULL_RUN_ID = 'synthetic-2026-2027-v2';
const PILOT_RUN_ID = 'synthetic-2026-2027-v1';
const VALIDATED_CONFIG_HASH = '205bef84';
const PILOT_CONFIG_HASH = 'e665f878b1ab1880da46230d2c25668340c52075e4700ed8724a6633e0825a13';
const EFFECTIVE_CONFIG_HASH = 'e361be99cb7b5648526bb8f84fbf19f6887a5b5d06318c0fc30dbf6d8d5d6a62';
const PILOT_IDS = new Set();
const MARKERS = { isFake: true, accountType: 'synthetic', syntheticSeason: SEASON };
const AVATAR = 'assets/images/profiel_bal.png';
const APPLY = process.argv.includes('--apply');
const pilotArg = process.argv.find((arg) => arg.startsWith('--pilot='));
const PILOT = pilotArg ? Number(pilotArg.split('=')[1]) : null;

if (PILOT !== null && PILOT !== 5) throw new Error('Alleen --pilot=5 wordt ondersteund.');
if (process.argv.some((arg) => arg.startsWith('--pilot')) && !pilotArg) throw new Error('Gebruik --pilot=5.');

if (!getApps().length) initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

function normalize(value) { return String(value || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, ''); }
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  return value;
}
function hash(value) { return crypto.createHash('sha256').update(JSON.stringify(stable(value))).digest('hex').slice(0, 8); }
function chunks(items, size = 200) { const out = []; for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size)); return out; }
function fail(message) { throw new Error(message); }
function loadValidatedReport() {
  const script = path.join(__dirname, 'synthetic_2026_2027_v2_dry_run.js');
  const result = spawnSync(process.execPath, [script], { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
  if (result.status !== 0) fail(`Gevalideerde dry-run kon niet worden geladen:\n${result.stderr}`);
  const marker = 'MACHINE-READABLE FULL REPORT';
  const startMarker = result.stdout.indexOf(marker);
  const start = result.stdout.indexOf('{', startMarker);
  const end = result.stdout.indexOf('\n\nDRY RUN VOLTOOID', start);
  if (startMarker < 0 || start < 0 || end < 0) fail('Machine-readable dry-runrapport niet gevonden.');
  return JSON.parse(result.stdout.slice(start, end));
}
function selectDataset(report) {
  if (report.legacyConfigHash !== VALIDATED_CONFIG_HASH) fail(`Legacy configHash mismatch: verwacht ${VALIDATED_CONFIG_HASH}, kreeg ${report.legacyConfigHash}.`);
  if (report.futureApplyPlan.manifest.configHash !== EFFECTIVE_CONFIG_HASH) fail(`Effectieve configHash mismatch: verwacht ${EFFECTIVE_CONFIG_HASH}, kreeg ${report.futureApplyPlan.manifest.configHash}.`);
  if (!report.validation.valid) fail('De volledige v2 dry-run is niet valide.');
  const players = report.players.rows;
  const pools = report.pools;
  const finals = report.finalStandings.predictions;
  const predictions = report.fullSeasonPredictions.matches.flatMap((match) => match.predictions.map((p) => ({ ...p, matchId: match.matchId, round: match.round, division: match.division, home: match.home, away: match.away })));
  return { runId: FULL_RUN_ID, configHash: EFFECTIVE_CONFIG_HASH, players, pools, finals, predictions, report };
}
function marker(runId) { return { ...MARKERS, syntheticRunId: runId }; }
function poolCounts(dataset, uid) {
  const memberships = dataset.pools.filter((p) => p.memberIds.includes(uid));
  return { joined: memberships.length, owned: memberships.filter((p) => p.creatorSyntheticId === uid).length };
}
async function loadTeams() {
  const snap = await db.collection('seasons').doc(SEASON).collection('teams').get();
  const rows = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const division = (row) => String(row.division || row.divisie || row.competition || '').toUpperCase();
  const name = (row) => row.name || row.naam || row.teamName;
  return { rows, division, name, byName: new Map(rows.map((row) => [normalize(name(row)), row])) };
}
function buildOperations(dataset, teams) {
  const timestamp = () => FieldValue.serverTimestamp();
  const ops = { users: [], usernames: [], predictions: [], finals: [], pools: [] };
  for (const p of dataset.players.filter((player) => !PILOT_IDS.has(player.syntheticId))) {
    const key = normalize(p.username); const team = teams.byName.get(normalize(p.favoriteClub)); const counts = poolCounts(dataset, p.syntheticId);
    ops.users.push({ path: `users/${p.syntheticId}`, data: { uid: p.syntheticId, displayName: p.displayName, username: p.username, usernameLower: p.username.toLowerCase().trim(), usernameKey: key, email: `${p.syntheticId}@synthetic.invalid`, ismoderator: false, isModerator: false, heeftGebruikersnaamGewijzigd: false, avatarUrl: AVATAR, woonplaats: '', favorieteCompetitie: p.competitions.length === 1 ? p.competitions[0] : 'A+B', favorieteClub: p.favoriteClub || 'Geen voorkeur', ...(team ? { favoriteTeamSlug: team.id, favoriteTeamName: teams.name(team), favoriteDivision: teams.division(team) } : {}), allowEmailSharingWithPouleOwner: false, notificationPreferences: {}, points: 0, punten: 0, punten_A: 0, punten_B: 0, totaalPunten: 0, totalPoints: 0, competitions: p.competitions, ranglijstZichtbaar: true, voorspellingenZichtbaar: true, eigenPoules: counts.owned, gejoinedePoules: counts.joined, isIdle: p.isIdle, predictionProfile: p.predictionProfile, aangemaaktOp: timestamp(), ...marker(dataset.runId) } });
    ops.usernames.push({ path: `usernames/${key}`, data: { uid: p.syntheticId, username: p.username, displayName: p.displayName, email: `${p.syntheticId}@synthetic.invalid`, usernameKey: key, updatedAt: timestamp(), ...marker(dataset.runId) } });
  }
  for (const p of dataset.predictions.filter((prediction) => !(PILOT_IDS.has(prediction.syntheticId) && prediction.round === 1))) ops.predictions.push({ path: `seasons/${SEASON}/predictions/${p.syntheticId}_${p.matchId}`, data: { gebruikerId: p.syntheticId, userId: p.syntheticId, wedstrijdId: p.matchId, matchId: p.matchId, thuisScore: p.homeGoals, uitScore: p.awayGoals, homeScore: p.homeGoals, awayScore: p.awayGoals, divisie: p.division, division: p.division, seasonId: SEASON, punten: 0, verwerkt: false, timestamp: timestamp(), predictionProfile: p.profile, ...marker(dataset.runId) } });
  for (const p of dataset.finals.filter((prediction) => !PILOT_IDS.has(prediction.syntheticId))) ops.finals.push({ path: `eindstand_voorspellingen/${p.syntheticId}_${p.division}`, data: { gebruikerId: p.syntheticId, divisie: p.division, seasonId: SEASON, voorspelling: p.ranking, timestamp: timestamp(), predictionProfile: p.profile, ...marker(dataset.runId) } });
  for (const p of dataset.pools) {
    const privatePool = !p.isPublic;
    const password = privatePool ? process.env.SYNTHETIC_POOL_PASSWORD : '';
    if (APPLY && privatePool && !password) fail('SYNTHETIC_POOL_PASSWORD is vereist voor gesloten poules bij --apply.');
    const team = p.teamName ? teams.byName.get(normalize(p.teamName)) : null;
    ops.pools.push({ path: `poules/${p.id}`, data: { id: p.id, name: p.name, description: 'Synthetische poule 2026/2027', ownerId: p.creatorSyntheticId, isPublic: p.isPublic, password, type: p.kind === 'club' ? 'team' : 'competition', competition: p.kind === 'club' ? 'team' : 'competition', ...(team ? { teamId: team.id, teamName: teams.name(team) } : {}), division: p.division === 'A+B' ? null : p.division, seasonId: SEASON, predictionScope: p.predictionScope, includeMatchPredictions: ['matches', 'both'].includes(p.predictionScope), includeFinalStandingPredictions: ['standings', 'both'].includes(p.predictionScope), createdAt: timestamp(), ...marker(dataset.runId) } });
    for (const member of p.members) {
      ops.pools.push({ path: `poules/${p.id}/deelnemers/${member.syntheticId}`, data: { joinedAt: timestamp(), punten: 0, rol: member.role, voorspellingenZichtbaarVoorDeadline: false, syncEnabled: true, ...marker(dataset.runId) } });
      ops.pools.push({ path: `users/${member.syntheticId}/poules/${p.id}`, data: { joinedAt: timestamp(), ...marker(dataset.runId) } });
    }
  }
  return ops;
}
async function verifyInheritedPilot(dataset) {
  const errors = [];
  const manifestPath = 'synthetic_runs/synthetic-2026-2027-v1';
  const manifestSnap = await db.doc(manifestPath).get();
  if (!manifestSnap.exists) return { valid: false, errors: ['v1 hoofdmanifest ontbreekt'], manifestPath };
  const manifest = manifestSnap.data();
  if (manifest.status !== 'verified') errors.push(`v1 status=${manifest.status}`);
  if (manifest.effectiveDatasetHash !== PILOT_CONFIG_HASH) errors.push(`v1 effectiveDatasetHash=${manifest.effectiveDatasetHash}`);
  const refs = Array.from({length: 50}, (_, i) => db.doc(`users/syn_2026_2027_${String(i + 1).padStart(3, '0')}`));
  const users = await db.getAll(...refs);
  if (users.filter((x) => x.exists).length !== 50) errors.push('v1 users niet exact 50');
  for (const user of users) if (user.exists) {
    const n = Number(user.id.slice(-3));
    const expected = n <= 5 ? 'synthetic-2026-2027-pilot-v1' : 'synthetic-2026-2027-v1';
    if (user.data().syntheticRunId !== expected) errors.push(`${user.ref.path}: marker wijkt af`);
  }
  return { valid: errors.length === 0, errors, manifestPath, status: manifest.status, effectiveDatasetHash: manifest.effectiveDatasetHash, inheritedUsers: users.length };
}

async function partitionExistingOperations(fullOps, runId) {
  const remaining = {}; const inheritedSuccessfulPaths = []; const existingItems = [];
  for (const [type, items] of Object.entries(fullOps)) {
    remaining[type] = [];
    for (const group of chunks(items, 100)) {
      const snapshots = await db.getAll(...group.map((item) => db.doc(item.path)));
      snapshots.forEach((snapshot, index) => { if (snapshot.exists) { existingItems.push(group[index]); inheritedSuccessfulPaths.push(group[index].path); } else remaining[type].push(group[index]); });
    }
  }
  if (existingItems.length) await verify(existingItems, runId);
  return { remaining, existingItems, inheritedSuccessfulPaths };
}
async function preflight(dataset, teams, ops) {
  const errors = [];
  const activeProjectId = getApps()[0].options.projectId || '';
  if (activeProjectId !== PROJECT_ID) errors.push('Verkeerd project: ' + activeProjectId);
  const a = teams.rows.filter((r) => teams.division(r) === 'A'); const b = teams.rows.filter((r) => teams.division(r) === 'B');
  const teamNames = [...a, ...b].map(teams.name); const teamSet = new Set(teamNames.map(normalize));
  if (a.length !== 18 || b.length !== 18 || teamSet.size !== 36) errors.push(`Teamset ongeldig: A=${a.length}, B=${b.length}, uniek=${teamSet.size}.`);
  const matchSnap = await db.collection('seasons').doc(SEASON).collection('matches').get();
  const matchMap = new Map(matchSnap.docs.map((d) => [d.id, d.data()]));
  for (const p of dataset.predictions) { const m = matchMap.get(p.matchId); if (!m) errors.push(`Wedstrijd ontbreekt: ${p.matchId}`); else { const home = m.homeTeamName || m.homeTeam || m.thuisteam || ''; const away = m.awayTeamName || m.awayTeam || m.uitteam || ''; if (!teamSet.has(normalize(home)) || !teamSet.has(normalize(away))) errors.push(`Wedstrijd buiten teamset: ${p.matchId}`); if (normalize(home) !== normalize(p.home) || normalize(away) !== normalize(p.away)) errors.push(`Wedstrijdreferentie wijkt af: ${p.matchId}`); } }
  const all = Object.values(ops).flat(); const paths = all.map((o) => o.path); const unique = new Set(paths);
  if (unique.size !== paths.length) errors.push('Dubbele doelpaden in schrijfplan.');
  const existing = [];
  for (const group of chunks(paths.concat(`synthetic_runs/${dataset.runId}`), 100)) for (const snap of await db.getAll(...group.map((p) => db.doc(p)))) if (snap.exists) existing.push(snap.ref.path);
  if (existing.length) errors.push(`Doelpaden bestaan al: ${existing.join(', ')}`);
  const usernameKeys = dataset.players.filter((p) => !PILOT_IDS.has(p.syntheticId)).map((p) => normalize(p.username));
  for (const group of chunks(usernameKeys, 10)) { const snap = await db.collection('users').where('usernameKey', 'in', group).get(); const foreign = snap.docs.filter((doc) => doc.data().syntheticRunId !== dataset.runId); if (foreign.length) errors.push('Usernamebotsing in users: ' + foreign.map((d) => d.id).join(', ')); }
  if (dataset.players.some((p) => !teamSet.has(normalize(p.favoriteClub)))) errors.push('Favoriete club buiten actuele teamset.');
  return { valid: errors.length === 0, errors, projectId: activeProjectId, teams: { A: a.length, B: b.length, unique: teamSet.size }, matches: matchSnap.size, counts: Object.fromEntries(Object.entries(ops).map(([k, v]) => [k, v.length])), documentWritesBeforeManifest: paths.length, manifestWrites: 1, totalWrites: paths.length + 1 };
}
function recoveryPath(runId) { return path.join(os.tmpdir(), `recovery_${runId}.json`); }
function writeRecovery(runId, successfulPaths, status, error) { fs.writeFileSync(recoveryPath(runId), JSON.stringify({ runId, status, updatedAt: new Date().toISOString(), successfulPaths, error: error ? String(error.stack || error) : null }, null, 2)); }
async function commitPhase(name, items, dataset, successfulPaths) {
  console.log(`START ${name} (${items.length})`);
  try { for (const group of chunks(items)) { const batch = db.batch(); for (const item of group) batch.create(db.doc(item.path), item.data); await batch.commit(); successfulPaths.push(...group.map((x) => x.path)); writeRecovery(dataset.runId, successfulPaths, 'IN_PROGRESS'); } console.log(`SUCCESS ${name} (${items.length})`); }
  catch (error) { console.error(`FAILED ${name}: ${error.message}`); writeRecovery(dataset.runId, successfulPaths, 'FAILED', error); throw error; }
}
function isServerTimestampSentinel(value) { return value && value.constructor && value.constructor.name === 'ServerTimestampTransform'; }
function equalValue(actual, expected) {
  if (isServerTimestampSentinel(expected)) return Boolean(actual && typeof actual.toDate === 'function');
  if (Array.isArray(expected)) return Array.isArray(actual) && JSON.stringify(actual) === JSON.stringify(expected);
  if (expected && typeof expected === 'object') return Object.entries(expected).every(([key, value]) => equalValue(actual && actual[key], value));
  return actual === expected;
}
async function verify(items, runId) {
  const missing = []; const wrongMarker = []; const mismatched = [];
  for (const group of chunks(items, 100)) {
    const snapshots = await db.getAll(...group.map((o) => db.doc(o.path)));
    snapshots.forEach((snap, index) => {
      if (!snap.exists) { missing.push(snap.ref.path); return; }
      const actual = snap.data(); const expected = group[index].data;
      if (actual.syntheticRunId !== runId) wrongMarker.push(snap.ref.path);
      for (const [key, value] of Object.entries(expected)) if (!equalValue(actual[key], value)) mismatched.push(`${snap.ref.path}:${key}`);
    });
  }
  if (missing.length || wrongMarker.length || mismatched.length) fail(`Verify mislukt; ontbrekend=${missing.length}, verkeerde marker=${wrongMarker.length}, veldafwijkingen=${mismatched.length}: ${mismatched.slice(0, 10).join(', ')}`);
  return { documents: items.length, missing: 0, wrongMarker: 0, mismatchedFields: 0 };
}
async function captureProtectedBaseline() {
  const archive = await db.collection('season_archives').doc('2025-2026').collection('rankings').doc('global').collection('users').where('isFake', '==', true).get();
  const normalized = archive.docs.map((doc) => [doc.id, doc.data()]).sort((a, b) => a[0].localeCompare(b[0]));
  return { oldFakeCount: archive.size, oldFakeHash: crypto.createHash('sha256').update(JSON.stringify(normalized)).digest('hex') };
}
async function verifyGlobalTotals(dataset, protectedBaseline) {
  const errors = [];
  const fullIds = Array.from({ length: 100 }, (_, index) => `syn_2026_2027_${String(index + 1).padStart(3, '0')}`);
  const userSnapshots = await db.getAll(...fullIds.map((id) => db.doc(`users/${id}`)));
  const usernameSnapshots = await db.getAll(...dataset.players.map((player) => db.doc(`usernames/${normalize(player.username)}`)));
  if (userSnapshots.filter((snapshot) => snapshot.exists).length !== 100) errors.push('synthetic users totaal niet 100');
  if (usernameSnapshots.filter((snapshot) => snapshot.exists).length !== 50) errors.push('v2 username-indexen niet 50');
  for (const snapshot of userSnapshots) if (snapshot.exists) { const n = Number(snapshot.id.slice(-3)); const expectedRun = n <= 5 ? 'synthetic-2026-2027-pilot-v1' : n <= 50 ? 'synthetic-2026-2027-v1' : FULL_RUN_ID; if (snapshot.data().syntheticRunId !== expectedRun) errors.push(`${snapshot.ref.path}: marker wijkt af`); }
  for (let offset = 0; offset < fullIds.length; offset += 10) {
    const group = fullIds.slice(offset, offset + 10);
    const root = await db.collection('voorspellingen').where('gebruikerId', 'in', group).get();
    if (!root.empty) errors.push(`legacy root predictions gevonden: ${root.size}`);
  }
  const seasonPredictions = await db.collection('seasons').doc(SEASON).collection('predictions').where('isFake', '==', true).get();
  if (seasonPredictions.size !== 31518) errors.push(`predictions totaal=${seasonPredictions.size}`);
  const finals = await db.collection('eindstand_voorspellingen').where('isFake', '==', true).get();
  const syntheticFinals = finals.docs.filter((doc) => fullIds.includes(doc.data().gebruikerId));
  if (syntheticFinals.length !== 103) errors.push(`eindstanden totaal=${syntheticFinals.length}`);
  const pools = await db.collection('poules').where('syntheticRunId', '==', 'synthetic-2026-2027-v1').get();
  if (pools.size !== 6) errors.push(`poules totaal=${pools.size}`);
  let participants = 0; for (const pool of pools.docs) participants += (await pool.ref.collection('deelnemers').get()).size;
  if (participants !== 38) errors.push(`poule deelnemers totaal=${participants}`);
  let userPoolIndexes = 0; for (const id of fullIds) userPoolIndexes += (await db.doc(`users/${id}`).collection('poules').where('syntheticRunId', '==', 'synthetic-2026-2027-v1').get()).size;
  if (userPoolIndexes !== 38) errors.push(`user-poule-indexen totaal=${userPoolIndexes}`);
  const after = await captureProtectedBaseline();
  if (protectedBaseline.oldFakeCount !== 221 || after.oldFakeCount !== protectedBaseline.oldFakeCount || after.oldFakeHash !== protectedBaseline.oldFakeHash) errors.push('oude 221 fake-userstubs gewijzigd');
  if (errors.length) fail(`GLOBAL VERIFY mislukt: ${errors.join('; ')}`);
  return { users: 100, newUsernameIndexes: 50, predictions: seasonPredictions.size, finalStandings: syntheticFinals.length, pools: pools.size, poolParticipants: participants, userPoolIndexes, oldFakeStubs: after.oldFakeCount, rootPredictionsWritten: 0, authenticationWrites: 0 };
}
const MANIFEST_SCHEMA_VERSION = 2;
const MANIFEST_MAX_PATHS = 250;
const MANIFEST_SAFE_BYTES = 700 * 1024;
function serializedBytes(value) { return Buffer.byteLength(JSON.stringify(value), 'utf8'); }
function buildManifestChunks(ops, runId) {
  const typeOrder = ['users', 'usernames', 'predictions', 'finals', 'pools'];
  const result = [];
  let chunkIndex = 0;
  for (const documentType of typeOrder) {
    const paths = ops[documentType].map((item) => item.path).sort();
    let current = [];
    const flush = () => {
      if (!current.length) return;
      const chunkId = `chunk_${String(chunkIndex).padStart(4, '0')}`;
      const data = { runId, syntheticRunId: runId, chunkIndex, pathCount: current.length, documentType, paths: current };
      const estimatedBytes = serializedBytes(data);
      if (estimatedBytes > MANIFEST_SAFE_BYTES) fail(`Manifestchunk ${chunkId} is ${estimatedBytes} bytes; veilige grens ${MANIFEST_SAFE_BYTES}.`);
      result.push({ chunkId, path: `synthetic_runs/${runId}/manifest_chunks/${chunkId}`, data, estimatedBytes });
      chunkIndex += 1; current = [];
    };
    for (const documentPath of paths) {
      const candidate = [...current, documentPath];
      const estimate = serializedBytes({ runId, syntheticRunId: runId, chunkIndex, pathCount: candidate.length, documentType, paths: candidate });
      if (current.length && (candidate.length > MANIFEST_MAX_PATHS || estimate > MANIFEST_SAFE_BYTES)) flush();
      current.push(documentPath);
    }
    flush();
  }
  const registered = result.flatMap((chunk) => chunk.data.paths);
  const expected = Object.values(ops).flat().map((item) => item.path);
  const duplicates = registered.filter((item, index) => registered.indexOf(item) !== index);
  const missing = expected.filter((item) => !registered.includes(item));
  const unexpected = registered.filter((item) => !expected.includes(item));
  const pathCountSum = result.reduce((sum, chunk) => sum + chunk.data.pathCount, 0);
  const validation = { valid: duplicates.length === 0 && missing.length === 0 && unexpected.length === 0 && registered.length === expected.length && pathCountSum === expected.length && result.every((chunk) => chunk.data.paths.length === chunk.data.pathCount && chunk.data.pathCount <= MANIFEST_MAX_PATHS && chunk.estimatedBytes <= MANIFEST_SAFE_BYTES), duplicatePaths: [...new Set(duplicates)], missingPaths: missing, unexpectedPaths: unexpected, expectedPaths: expected.length, registeredPaths: registered.length, pathCountSum };
  return { chunks: result, validation, statistics: { chunkCount: result.length, smallestChunkPaths: Math.min(...result.map((chunk) => chunk.data.pathCount)), largestChunkPaths: Math.max(...result.map((chunk) => chunk.data.pathCount)), minEstimatedBytes: Math.min(...result.map((chunk) => chunk.estimatedBytes)), maxEstimatedBytes: Math.max(...result.map((chunk) => chunk.estimatedBytes)), safeByteLimit: MANIFEST_SAFE_BYTES, maxPathsPerChunk: MANIFEST_MAX_PATHS } };
}
async function verifyManifestChunks(manifestPlan) {
  const errors = [];
  for (const group of chunks(manifestPlan.chunks, 100)) {
    const snapshots = await db.getAll(...group.map((chunk) => db.doc(chunk.path)));
    snapshots.forEach((snapshot, index) => {
      const expected = group[index]; const data = snapshot.exists ? snapshot.data() : null;
      if (!data || data.runId !== expected.data.runId || data.syntheticRunId !== expected.data.syntheticRunId || data.chunkIndex !== expected.data.chunkIndex || data.pathCount !== expected.data.pathCount || data.documentType !== expected.data.documentType || JSON.stringify(data.paths) !== JSON.stringify(expected.data.paths)) errors.push(expected.path);
    });
  }
  if (errors.length) fail(`Manifestchunkverify mislukt: ${errors.slice(0, 10).join(', ')}`);
  return { verifiedChunks: manifestPlan.chunks.length, verifiedPaths: manifestPlan.validation.registeredPaths };
}
async function main() {
  if (PILOT !== null) fail('De pilot bestaat al; gebruik dit script zonder --pilot voor de inherited full-run.');
  const protectedBaseline = await captureProtectedBaseline();
  if (protectedBaseline.oldFakeCount !== 221) fail(`Oude fake-userstubcount=${protectedBaseline.oldFakeCount}, verwacht 221.`);
  const report = loadValidatedReport();
  const dataset = selectDataset(report);
  const pilotVerification = await verifyInheritedPilot(dataset);
  console.log('PILOT VERIFICATION');
  console.log(JSON.stringify(pilotVerification, null, 2));
  if (!pilotVerification.valid) fail(`STOP: inherited pilot wijkt af: ${pilotVerification.errors.join('; ')}`);
  const teams = await loadTeams();
  const fullOps = buildOperations(dataset, teams);
  const resume = await partitionExistingOperations(fullOps, dataset.runId);
  const ops = resume.remaining;
  const validation = await preflight(dataset, teams, ops);
  const manifestPlan = buildManifestChunks(fullOps, dataset.runId);
  if (!manifestPlan.validation.valid) fail(`Chunked manifest ongeldig: ${JSON.stringify(manifestPlan.validation)}`);
  const existingChunkPaths = [];
  for (const group of chunks(manifestPlan.chunks, 100)) for (const snapshot of await db.getAll(...group.map((chunk) => db.doc(chunk.path)))) if (snapshot.exists) existingChunkPaths.push(snapshot.ref.path);
  if (existingChunkPaths.length) { validation.errors.push(`Bestaande manifestchunkpaden: ${existingChunkPaths.join(", ")}`); validation.valid = false; }
  const planned = {
    alreadyCreatedAndVerified: resume.existingItems.length,
    remainingUsers: ops.users.length,
    remainingUsernameIndexes: ops.usernames.length,
    remainingPredictions: ops.predictions.length,
    remainingFinalStandings: ops.finals.length,
    poolDocuments: ops.pools.filter((item) => item.path.startsWith('poules/') && item.path.split('/').length === 2).length,
    poolParticipantDocuments: ops.pools.filter((item) => item.path.includes('/deelnemers/')).length,
    userPoolIndexDocuments: ops.pools.filter((item) => item.path.startsWith('users/')).length,
    poolAndMembershipWrites: ops.pools.length,
    manifestChunkWrites: manifestPlan.chunks.length,
    mainManifestWrites: 1,
    totalNewDocumentWrites: Object.values(ops).flat().length + manifestPlan.chunks.length + 1,
  };
  const datasetTotalsAfterApply = { newUsers: 50, totalSyntheticUsers: 100, newUsernameIndexes: 50, newPredictions: dataset.predictions.length, totalPredictions: 31518, newFinalStandings: dataset.finals.length, totalFinalStandings: 103, newPools: 0, priorManifest: 1, mainManifest: 1 };
  console.log('INHERITED FULL DRY-RUN PLAN');
  console.log(JSON.stringify({
    mode: APPLY ? 'APPLY' : 'DRY RUN', runId: dataset.runId,
    oldLegacyConfigHash: VALIDATED_CONFIG_HASH, effectiveDatasetConfigHash: dataset.configHash,
    predictionCoverage: dataset.report.predictionCoverage,
    hashFields: ['syntheticId', 'displayName', 'username', 'competitions', 'predictionProfile', 'isIdle', 'team strengths', 'final standings', 'match predictions', 'pool plan'],
    priorRunManifest: pilotVerification.manifestPath,
    priorDatasetUsers: pilotVerification.inheritedUsers,
    existingV1Users: 50,
    planned,
    datasetTotalsAfterApply,
    chunkedManifest: { ...manifestPlan.statistics, totalRegisteredPaths: manifestPlan.validation.registeredPaths, cleanupValidation: manifestPlan.validation },
    predictionStorage: { path: `seasons/${SEASON}/predictions`, dualWrite: false },
    poolsIncluded: [],
    collisionChecks: { priorReservationsUntouched: 50, inheritedIdentityMutations: 0, newUserCollisionScope: '051-100', displayNameCollisions: dataset.report.validation.identities.currentDisplayNameCollisions, usernameCollisions: dataset.report.validation.identities.currentUsernameCollisions, existingTargetPaths: validation.errors.filter((error) => error.startsWith('Doelpaden bestaan al:') || error.startsWith('Bestaande manifestchunkpaden:')) },
    validation,
  }, null, 2));
  if (!validation.valid) fail(validation.errors.join('\n'));
  if (!APPLY) { console.log('INHERITED FULL DRY RUN VOLTOOID — Firestore writes: 0; Authentication writes: 0.'); return; }
  const successful = [...resume.inheritedSuccessfulPaths];
  writeRecovery(dataset.runId, successful, 'RESUMING');
  await commitPhase('USERS', ops.users, dataset, successful); await commitPhase('USERNAMES', ops.usernames, dataset, successful); await commitPhase('PREDICTIONS', ops.predictions, dataset, successful); await commitPhase('FINAL_STANDINGS', ops.finals, dataset, successful); await commitPhase('POOLS', ops.pools, dataset, successful);
  const all = Object.values(fullOps).flat(); console.log('START VERIFY ALL NEW DATA'); const verification = await verify(all, dataset.runId); console.log('SUCCESS VERIFY ALL NEW DATA (' + verification.documents + ')');
  console.log('START GLOBAL TOTALS VERIFY'); const globalVerification = await verifyGlobalTotals(dataset, protectedBaseline); console.log('SUCCESS GLOBAL TOTALS VERIFY'); console.log(JSON.stringify(globalVerification, null, 2));
  console.log(`START MANIFEST CHUNKS (${manifestPlan.chunks.length})`);
  await commitPhase('MANIFEST_CHUNKS', manifestPlan.chunks.map((chunk) => ({ path: chunk.path, data: chunk.data })), dataset, successful);
  const chunkVerification = await verifyManifestChunks(manifestPlan);
  console.log(`SUCCESS MANIFEST CHUNK VERIFY (${chunkVerification.verifiedChunks} chunks, ${chunkVerification.verifiedPaths} paths)`);
  const manifestPath = `synthetic_runs/${dataset.runId}`;
  console.log('START MAIN MANIFEST (1)');
  await db.doc(manifestPath).create({
    runId: dataset.runId, seasonId: SEASON, status: 'verified', effectiveDatasetHash: dataset.configHash,
    priorRunId: PILOT_RUN_ID, createdAt: FieldValue.serverTimestamp(), verifiedAt: FieldValue.serverTimestamp(),
    counts: { ...datasetTotalsAfterApply, newDataDocuments: all.length, manifestChunks: manifestPlan.chunks.length },
    chunkCount: manifestPlan.chunks.length, schemaVersion: MANIFEST_SCHEMA_VERSION,
  });
  successful.push(manifestPath); writeRecovery(dataset.runId, successful, 'SUCCESS'); console.log('SUCCESS MAIN MANIFEST (1)');
  const manifest = await db.doc(manifestPath).get();
  if (!manifest.exists || manifest.data().status !== 'verified' || manifest.data().runId !== dataset.runId || manifest.data().effectiveDatasetHash !== dataset.configHash || manifest.data().chunkCount !== manifestPlan.chunks.length) fail('Hoofdmanifestverify mislukt.');
  console.log(`APPLY EN VERIFY VOLTOOID — ${all.length} data + ${manifestPlan.chunks.length} chunks + 1 hoofdmanifest; Authentication writes: 0.`);
}
main().catch((error) => { console.error('SYNTHETIC APPLY MISLUKT:', error); process.exitCode = 1; });
















