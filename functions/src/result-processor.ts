/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */
import {Firestore, FieldValue, FieldPath, DocumentReference} from "firebase-admin/firestore";
import {ACTIVE_SEASON, Data, division, fingerprint, contribution, standings, selectLatest, uid, result, score, points, integer, eligible} from "./result-domain";

async function bounded<T>(items: T[], action: (item: T) => Promise<void>): Promise<void> {
  for (let i=0; i<items.length; i+=4) {
    const results=await Promise.allSettled(items.slice(i, i+4).map(action));
    const failed=results.find((r)=>r.status==="rejected");
    if (failed?.status==="rejected") throw failed.reason;
  }
}
const stamp = () => FieldValue.serverTimestamp();
class Superseded extends Error {}
class MaintenancePaused extends Error {}
async function checkMaintenance(tx: FirebaseFirestore.Transaction, db: Firestore): Promise<void> {
  if ((await tx.get(db.doc("system/result_processing_maintenance"))).data()?.enabled === true) throw new MaintenancePaused();
}
const pathFor = (id: string) => `seasons/${ACTIVE_SEASON}/matches/${id}`;
export async function predictionDocs(db: Firestore, matchId: string, collections: string[]): Promise<{path: string; data: Data}[]> {
  const found = new Map<string, Data>();
  await Promise.all(collections.flatMap((collection) => ["wedstrijdId", "matchId"].map(async (field) => {
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = db.collection(collection).where(field, "==", matchId).orderBy(FieldPath.documentId()).limit(250);
      if (last) query = query.startAfter(last);
      const page = await query.get();
      for (const doc of page.docs) found.set(doc.ref.path, doc.data());
      if (page.size < 250) break;
      last = page.docs[page.size-1];
    }
  })));
  return [...found].map(([path, data]) => ({path, data}));
}
export async function updateStandings(db: Firestore, matchRef: DocumentReference, expected: string, force = false): Promise<void> {
  await db.runTransaction(async (tx) => {
    await checkMaintenance(tx, db);
    const match = await tx.get(matchRef); const m = match.data();
    if (!m || fingerprint(m) !== expected) throw new Superseded();
    const div = division(m); const base = `seasons/${ACTIVE_SEASON}`;
    const aggregateRef = db.doc(`${base}/processingAggregates/${div}`); const aggregate = await tx.get(aggregateRef);
    let contributions: Data = {...(aggregate.data()?.contributions ?? {})};
    if (!aggregate.exists || force) {
      // Bootstrap under the same transaction: changes to the query cause retry.
      const source = await tx.get(db.collection(`${base}/matches`).where("division", "==", div));
      contributions = Object.fromEntries(source.docs.filter((d)=>d.id!=="_meta").map((d)=>[d.id, contribution(d.data())]));
    }
    const next = contribution(m);
    if (!force && aggregate.exists && JSON.stringify(contributions[matchRef.id] ?? null) === JSON.stringify(next)) return;
    contributions[matchRef.id] = next;
    tx.set(aggregateRef, {contributions, updatedAt: stamp()});
    for (let period=0; period<=3; period++) {
      for (const row of standings(div, contributions, period)) {
        const collection = period ? "periodStandings" : "standings";
        const id = period ? `${div}_P${period}_${row.teamId}` : `${div}_${row.teamId}`;
        tx.set(db.doc(`${base}/${collection}/${id}`), {...row, updatedAt: stamp()});
      }
    }
  }, {maxAttempts: 20});
}
async function applyPrediction(db: Firestore, matchRef: DocumentReference, expected: string,
  userId: string, selectedPath: string | null, ledgerRef: DocumentReference, pouleId?: string): Promise<void> {
  // Participant lookup supports legacy random participant IDs. Never invent a missing participant.
  let participantRef: DocumentReference | undefined;
  if (pouleId) {
    const direct = db.doc(`poules/${pouleId}/deelnemers/${userId}`);
    if ((await direct.get()).exists) participantRef = direct;
    else {
      const q = await db.collection(`poules/${pouleId}/deelnemers`).where("userId", "==", userId).limit(1).get();
      participantRef = q.docs[0]?.ref;
    }
    if (!participantRef) throw new Error(`Missing poule participant: ${pouleId}/${userId}`);
  }
  await db.runTransaction(async (tx) => {
    await checkMaintenance(tx, db);
    const match = await tx.get(matchRef); const m = match.data();
    if (!m || fingerprint(m) !== expected) throw new Superseded();
    const ledger = await tx.get(ledgerRef); const previous = ledger.data();
    const selectedRef = selectedPath ? db.doc(selectedPath) : null;
    const prediction = selectedRef ? await tx.get(selectedRef) : null; const p = prediction?.data();
    const oldPath = previous?.predictionPath;
    const oldRef = oldPath && oldPath !== selectedPath ? db.doc(oldPath) : null;
    const oldPrediction = oldRef ? await tx.get(oldRef) : null;
    const userRef = participantRef ?? db.doc(`users/${userId}`); const user = await tx.get(userRef);
    if (!user.exists) throw new Error(`Missing user: ${userId}`);
    if (selectedRef && !p) throw new Error("Prediction changed while processing; retry required");
    const r = result(m); const processed = !!r && !!p && eligible(p, m);
    const next = processed && p && r ? points(score(p, true), score(p, false), r[0], r[1]) : 0;
    // Adopt legacy contributions once. An existing zero ledger remains authoritative on retry.
    const old = previous ? integer(previous.points) : p?.verwerkt === true ? integer(p.punten) : 0;
    const delta = next-old; const div = division(m); const userData = user.data() ?? {};
    if (previous?.inputKey === expected && previous.predictionPath === selectedPath && previous.points === next &&
      (!p || (p.punten === next && p.verwerkt === processed)) &&
      (pouleId || userData.totalen === Math.max(integer(userData.punten_A), integer(userData.punten_B)))) return;
    if (delta) {
      if (pouleId) tx.update(userRef, {punten: integer(userData.punten)+delta});
      else {
        const a = integer(userData.punten_A)+(div==="A" ? delta : 0);
        const b = integer(userData.punten_B)+(div==="B" ? delta : 0);
        tx.update(userRef, {punten_A: a, punten_B: b, totalen: Math.max(a, b)});
      }
    } else if (!pouleId && userData.totalen !== Math.max(integer(userData.punten_A), integer(userData.punten_B))) {
      tx.update(userRef, {totalen: Math.max(integer(userData.punten_A), integer(userData.punten_B))});
    }
    const resultKey = processed && r ? `${r[0]}-${r[1]}` : "";
    if (selectedRef) tx.update(selectedRef, {punten: next, verwerkt: processed, verwerktVoorUitslag: resultKey});
    if (oldRef && oldPrediction?.exists) tx.update(oldRef, {punten: 0, verwerkt: false, verwerktVoorUitslag: ""});
    tx.set(ledgerRef, {userId, matchId: matchRef.id, division: div, predictionPath: selectedPath,
      ...(pouleId ? {pouleId} : {}), points: next, processed, resultKey, inputKey: expected, updatedAt: stamp()});
  }, {maxAttempts: 20});
}
export async function processMatch(db: Firestore, matchId: string,
  hooks: {afterGeneral?: () => Promise<void>} = {}): Promise<void> {
  const matchRef = db.doc(pathFor(matchId));
  const initial = await matchRef.get(); const m = initial.data(); if (!m) return;
  let expected: string;
  try {
    expected=fingerprint(m);
  } catch (error) {
    if (m.processingStatus==="failed" && m.processingError===String(error)) throw error;
    await db.runTransaction(async (tx)=>{
      await checkMaintenance(tx, db); const current=await tx.get(matchRef); if (JSON.stringify(current.data())===JSON.stringify(m))tx.update(matchRef, {processed: false, verwerkt: false, processingStatus: "failed", predictionProcessingComplete: false, processingError: String(error)});
    }); throw error;
  }
  if (m.processingStatus === "processed" && m.processedInputKey === expected) return;
  const base = `seasons/${ACTIVE_SEASON}`; const div = division(m);
  try {
    await db.runTransaction(async (tx) => {
      await checkMaintenance(tx, db);
      const latest = await tx.get(matchRef);
      if (!latest.exists || fingerprint(latest.data() ?? {}) !== expected) throw new Superseded();
      tx.update(matchRef, {processed: false, verwerkt: false, processingStatus: "processing", predictionProcessingComplete: false,
        processingError: FieldValue.delete(), processingAttempts: FieldValue.increment(1), processingInputKey: expected});
    });
    await updateStandings(db, matchRef, expected);
    const [generalDocs, pouleDocs, generalLedgers, pouleLedgers] = await Promise.all([
      predictionDocs(db, matchId, [`${base}/predictions`, "voorspellingen"]),
      predictionDocs(db, matchId, ["poule_predictions", "poule_voorspellingen", "predictions"]),
      db.collection(`${base}/predictionContributions`).where("matchId", "==", matchId).get(),
      db.collection(`${base}/pouleContributions`).where("matchId", "==", matchId).get(),
    ]);
    const general = selectLatest(generalDocs, m); const poules = selectLatest(pouleDocs, m, true);
    // Preserve a rollback target even if a prediction was deleted or became ineligible.
    for (const doc of generalLedgers.docs) if (!general.has(doc.data().userId)) general.set(doc.data().userId, {path: "", data: doc.data()});
    for (const doc of generalDocs) if ((!doc.data.seasonId || doc.data.seasonId===ACTIVE_SEASON) && !general.has(uid(doc.data)) && doc.data.verwerkt === true) general.set(uid(doc.data), doc);
    await bounded([...general], async ([user, doc]) => {
      if (!user) return;
      await applyPrediction(db, matchRef, expected, user, doc.path || null,
        db.doc(`${base}/predictionContributions/${div}__${user}__${matchId}`));
    });
    await hooks.afterGeneral?.();
    for (const doc of pouleLedgers.docs) {
      const d=doc.data(); const key=`${d.pouleId}__${d.userId}`;
      if (!poules.has(key)) poules.set(key, {path: "", data: d});
    }
    for (const doc of pouleDocs) {
      const key=`${doc.data.pouleId ?? doc.data.poule ?? ""}__${uid(doc.data)}`;
      if ((!doc.data.seasonId || doc.data.seasonId===ACTIVE_SEASON) && !poules.has(key) && doc.data.verwerkt===true) poules.set(key, doc);
    }
    await bounded([...poules.values()], async (doc) => {
      const user=uid(doc.data); const poule=String(doc.data.pouleId ?? doc.data.poule ?? "");
      if (!user || !poule) throw new Error("Invalid poule prediction owner");
      const id = `${poule}__${user}__${matchId}`;
      await applyPrediction(db, matchRef, expected, user, doc.path || null, db.doc(`${base}/pouleContributions/${id}`), poule);
    });
    await db.runTransaction(async (tx) => {
      await checkMaintenance(tx, db);
      const latest=await tx.get(matchRef);
      if (!latest.exists || fingerprint(latest.data() ?? {}) !== expected) throw new Superseded();
      tx.update(matchRef, {processed: true, verwerkt: true, processingStatus: "processed", predictionProcessingComplete: true,
        processedInputKey: expected, processedResultKey: result(m)?.join("-") ?? "", processedAt: stamp(),
        predictionSelectedUsers: general.size, predictionProcessedUsers: general.size, pouleProcessedUsers: poules.size,
        processingError: FieldValue.delete()});
    });
  } catch (error) {
    if (error instanceof MaintenancePaused) throw error;
    if (error instanceof Superseded) return; // The newer write has its own durable event.
    await db.runTransaction(async (tx) => {
      await checkMaintenance(tx, db);
      const latest=await tx.get(matchRef);
      if (latest.exists && fingerprint(latest.data() ?? {}) === expected) {
        tx.update(matchRef, {
          processed: false, verwerkt: false, processingStatus: "failed", predictionProcessingComplete: false,
          processingError: String(error), processingFailedAt: stamp(),
        });
      }
    });
    throw error; // Firebase retries transient failures; ledger deltas make restart safe.
  }
}
