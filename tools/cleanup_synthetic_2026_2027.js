/* eslint-disable no-console */
/** Chunk-manifest-bound cleanup. Default read-only; delete requires --apply and --run-id. */
const { applicationDefault, getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const PROJECT_ID = 'derde-divisie-app';
const APPLY = process.argv.includes('--apply');
const runArg = process.argv.find((arg) => arg.startsWith('--run-id='));
const runId = runArg && runArg.slice('--run-id='.length);
if (!runId) throw new Error('Gebruik --run-id=<exacte manifest-runId>.');
if (!getApps().length) initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();
function chunks(items, size = 200) { const out = []; for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size)); return out; }
async function deletePaths(paths) { for (const group of chunks(paths)) { const batch = db.batch(); for (const item of group) batch.delete(db.doc(item)); await batch.commit(); } }
async function main() {
  const activeProjectId = getApps()[0].options.projectId || '';
  if (activeProjectId !== PROJECT_ID) throw new Error(`Verkeerd project: ${activeProjectId}`);
  const manifestPath = `synthetic_runs/${runId}`; const manifestSnap = await db.doc(manifestPath).get();
  if (!manifestSnap.exists) throw new Error(`Manifest bestaat niet: ${manifestPath}`);
  const manifest = manifestSnap.data();
  if (manifest.runId !== runId) throw new Error('Hoofdmanifest runId wijkt af.');
  let paths = []; let chunkPaths = []; let manifestMode;
  const errors = [];
  if (manifest.schemaVersion === 2) {
    manifestMode = 'chunked-v2';
    const chunkSnap = await db.doc(manifestPath).collection('manifest_chunks').orderBy('chunkIndex').get();
    if (chunkSnap.size !== manifest.chunkCount) errors.push(`chunkCount verwacht=${manifest.chunkCount}, gevonden=${chunkSnap.size}`);
    chunkPaths = chunkSnap.docs.map((doc) => doc.ref.path);
    chunkSnap.docs.forEach((doc, index) => {
      const data = doc.data();
      if (data.runId !== runId || data.syntheticRunId !== runId) errors.push(`${doc.ref.path}: runId/marker wijkt af`);
      if (data.chunkIndex !== index) errors.push(`${doc.ref.path}: chunkIndex niet deterministisch/aansluitend`);
      if (!Array.isArray(data.paths) || data.paths.length !== data.pathCount) errors.push(`${doc.ref.path}: pathCount wijkt af`);
      paths.push(...(Array.isArray(data.paths) ? data.paths : []));
    });
    if (manifest.counts?.newDataDocuments !== paths.length) errors.push(`geregistreerde paden=${paths.length}, manifest count=${manifest.counts?.newDataDocuments}`);
  } else {
    manifestMode = 'legacy-v1';
    paths = (manifest.allDocumentPaths || []).filter((item) => item !== manifestPath);
    if (!Array.isArray(manifest.allDocumentPaths)) errors.push('legacy manifest mist allDocumentPaths');
  }
  const uniquePaths = [...new Set(paths)];
  if (uniquePaths.length !== paths.length) errors.push(`dubbele geregistreerde paden=${paths.length - uniquePaths.length}`);
  const existing = []; const absent = []; const blocked = [];
  for (const group of chunks(uniquePaths, 100)) {
    const snapshots = await db.getAll(...group.map((item) => db.doc(item)));
    for (const snapshot of snapshots) {
      if (!snapshot.exists) absent.push(snapshot.ref.path);
      else if (snapshot.data().syntheticRunId !== runId) blocked.push(snapshot.ref.path);
      else existing.push(snapshot.ref.path);
    }
  }
  if (blocked.length) errors.push(`${blocked.length} doelen hebben verkeerde syntheticRunId`);
  const validation = { valid: errors.length === 0, errors, noDuplicatePaths: uniquePaths.length === paths.length, registeredPathCount: paths.length, chunkCount: chunkPaths.length, existingMatchingMarker: existing.length, alreadyAbsent: absent.length, blockedWrongMarker: blocked };
  console.log(JSON.stringify({ mode: APPLY ? 'APPLY' : 'DRY RUN', projectId: activeProjectId, runId, manifestMode, manifestPath, validation }, null, 2));
  if (!validation.valid) throw new Error('Cleanupvalidatie mislukt; niets verwijderd.');
  if (!APPLY) { console.log('CLEANUP DRY RUN VOLTOOID — deletes: 0.'); return; }
  const dataPaths = existing.sort((a, b) => b.split('/').length - a.split('/').length);
  console.log(`START CLEANUP DATA (${dataPaths.length})`); await deletePaths(dataPaths); console.log(`SUCCESS CLEANUP DATA (${dataPaths.length})`);
  const remaining = [];
  for (const group of chunks(dataPaths, 100)) for (const snapshot of await db.getAll(...group.map((item) => db.doc(item)))) if (snapshot.exists) remaining.push(snapshot.ref.path);
  if (remaining.length) throw new Error(`Cleanupverify mislukt; ${remaining.length} datadocumenten bestaan nog. Manifest blijft behouden.`);
  if (chunkPaths.length) { console.log(`START CLEANUP MANIFEST CHUNKS (${chunkPaths.length})`); await deletePaths(chunkPaths); console.log(`SUCCESS CLEANUP MANIFEST CHUNKS (${chunkPaths.length})`); }
  console.log('START CLEANUP MAIN MANIFEST (1)'); await db.doc(manifestPath).delete(); console.log('SUCCESS CLEANUP MAIN MANIFEST (1)');
  if ((await db.doc(manifestPath).get()).exists) throw new Error('Hoofdmanifestdelete kon niet worden geverifieerd.');
  console.log(`CLEANUP VOLTOOID — ${dataPaths.length + chunkPaths.length + 1} documenten verwijderd.`);
}
main().catch((error) => { console.error('SYNTHETIC CLEANUP MISLUKT:', error); process.exitCode = 1; });
