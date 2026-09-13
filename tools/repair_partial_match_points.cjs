#!/usr/bin/env node

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore, Timestamp } = require('firebase-admin/firestore');

const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');
const matchArg = process.argv.find((value) => value.startsWith('--match='));
const seasonArg = process.argv.find((value) => value.startsWith('--season='));
const matchId = matchArg?.split('=')[1]?.trim();
const explicitSeason = seasonArg?.split('=')[1]?.trim() || null;

if (!matchId) {
  console.error('Gebruik: node tools/repair_partial_match_points.cjs --match=b_05_06 [--apply]');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

function firstString(data, keys) {
  for (const key of keys) {
    const value = String(data[key] ?? '').trim();
    if (value) return value;
  }
  return '';
}

function firstInt(data, keys) {
  for (const key of keys) {
    const value = data[key];
    if (value === undefined || value === null) continue;
    const parsed = Number.parseInt(String(value), 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function predictionUserId(data) {
  return firstString(data, ['gebruikerId', 'userId', 'uid']);
}

function predictionScores(data) {
  return {
    home: firstInt(data, ['scoreThuis', 'thuis', 'home', 'voorspellingThuis', 'homeGoals', 'goalsHome', 'homeScore', 'predHome']),
    away: firstInt(data, ['scoreUit', 'uit', 'away', 'voorspellingUit', 'awayGoals', 'goalsAway', 'awayScore', 'predAway']),
  };
}

function calculatePoints(predHome, predAway, realHome, realAway) {
  if (predHome === realHome && predAway === realAway) return 10;
  const realDraw = realHome === realAway;
  const predDraw = predHome === predAway;
  if (realDraw && predDraw) return 7;
  let points = 0;
  const winnerCorrect = !realDraw && !predDraw && Math.sign(realHome - realAway) === Math.sign(predHome - predAway);
  if (winnerCorrect) points += 5;
  if (predHome === realHome) points += 2;
  if (predAway === realAway) points += 2;
  return Math.min(points, 10);
}

async function activeSeasonId() {
  if (explicitSeason) return explicitSeason;
  const snap = await db.collection('system').doc('current_season').get();
  const data = snap.data() ?? {};
  return firstString(data, ['seasonId', 'id', 'currentSeason', 'season']) || '2026-2027';
}

async function allPredictionDocsForMatch(seasonId) {
  const byPath = new Map();
  const collections = [
    db.collection('seasons').doc(seasonId).collection('predictions'),
    db.collection('voorspellingen'),
  ];
  for (const collection of collections) {
    for (const field of ['wedstrijdId', 'matchId']) {
      const snap = await collection.where(field, '==', matchId).get();
      for (const doc of snap.docs) byPath.set(doc.ref.path, doc);
    }
  }
  return [...byPath.values()];
}

async function main() {
  const seasonId = await activeSeasonId();
  const matchRef = db.collection('seasons').doc(seasonId).collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) throw new Error(`Wedstrijd ${matchId} bestaat niet in ${seasonId}.`);
  const match = matchSnap.data() ?? {};
  const realHome = firstInt(match, ['homeScore', 'uitslagThuis', 'thuisScore']);
  const realAway = firstInt(match, ['awayScore', 'uitslagUit', 'uitScore']);
  const division = firstString(match, ['division', 'divisie']).toUpperCase() || matchId.charAt(0).toUpperCase();
  const userPointsField = division === 'A' ? 'punten_A' : 'punten_B';
  const resultKey = `${realHome}-${realAway}`;

  let deadline = null;
  for (const key of ['scheduledAt', 'timestamp', 'datum', 'date']) {
    if (match[key] instanceof Timestamp) {
      const d = match[key].toDate();
      deadline = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12, 0, 0, 0);
      break;
    }
  }

  const docs = await allPredictionDocsForMatch(seasonId);
  const selected = new Map();
  for (const doc of docs) {
    const data = doc.data();
    const userId = predictionUserId(data);
    if (!userId) continue;
    const ts = data.timestamp instanceof Timestamp ? data.timestamp : null;
    if (deadline && (!ts || ts.toDate() > deadline)) continue;
    const millis = ts?.toMillis() ?? 0;
    const current = selected.get(userId);
    if (!current || millis >= current.millis) selected.set(userId, { doc, millis });
  }

  const preview = [];
  let totalDelta = 0;
  let adopted = 0;
  let newlyProcessed = 0;
  let existingLedger = 0;

  for (const [userId, entry] of selected.entries()) {
    const prediction = entry.doc.data();
    const scores = predictionScores(prediction);
    const newPoints = calculatePoints(scores.home, scores.away, realHome, realAway);
    const ledgerId = `${division}_${userId}_${matchId}`;
    const ledgerRef = db.collection('seasons').doc(seasonId).collection('predictionContributions').doc(ledgerId);
    const [ledgerSnap, userSnap] = await Promise.all([
      ledgerRef.get(),
      db.collection('users').doc(userId).get(),
    ]);
    const ledger = ledgerSnap.data() ?? null;
    const predictionProcessed = prediction.verwerkt === true;
    const predictionResultKey = firstString(prediction, ['verwerktVoorUitslag']);
    const ledgerProcessed = ledger?.processed === true;

    let previousPoints = 0;
    let mode = 'new';
    if (ledgerProcessed) {
      previousPoints = firstInt(ledger, ['points']);
      mode = 'ledger';
      existingLedger += 1;
    } else if (predictionProcessed && predictionResultKey) {
      previousPoints = firstInt(prediction, ['punten']);
      mode = 'adopt';
      adopted += 1;
    } else {
      newlyProcessed += 1;
    }

    const delta = newPoints - previousPoints;
    totalDelta += delta;
    const user = userSnap.data() ?? {};
    const currentA = firstInt(user, ['punten_A']);
    const currentB = firstInt(user, ['punten_B']);
    const nextA = userPointsField === 'punten_A' ? currentA + delta : currentA;
    const nextB = userPointsField === 'punten_B' ? currentB + delta : currentB;
    const nextTotal = Math.max(nextA, nextB);

    preview.push({
      userId,
      label: firstString(user, ['displayName', 'gebruikersnaam', 'username', 'naam', 'name', 'email']) || userId,
      mode,
      predictionProcessed,
      predictionResultKey,
      ledgerProcessed,
      previousPoints,
      newPoints,
      delta,
      currentA,
      currentB,
      nextA,
      nextB,
      currentTotal: firstInt(user, ['totalen']),
      nextTotal,
      predictionPath: entry.doc.ref.path,
      ledgerPath: ledgerRef.path,
    });
  }

  preview.sort((a, b) => a.label.localeCompare(b.label));

  console.log(JSON.stringify({
    mode: apply ? 'APPLY' : 'DRY_RUN',
    seasonId,
    matchId,
    division,
    result: resultKey,
    sourceDocuments: docs.length,
    selectedUsers: preview.length,
    adoptedExistingPredictions: adopted,
    existingLedgers: existingLedger,
    newlyProcessedPredictions: newlyProcessed,
    totalPointsDelta: totalDelta,
    preview,
  }, null, 2));

  if (!apply) {
    console.error('\nDRY RUN: niets gewijzigd. Gebruik --apply pas nadat de preview is gecontroleerd.');
    return;
  }

  let processed = 0;
  for (const item of preview) {
    const predictionRef = db.doc(item.predictionPath);
    const ledgerRef = db.doc(item.ledgerPath);
    const userRef = db.collection('users').doc(item.userId);

    await db.runTransaction(async (transaction) => {
      const [predictionSnap, ledgerSnap, userSnap] = await Promise.all([
        transaction.get(predictionRef),
        transaction.get(ledgerRef),
        transaction.get(userRef),
      ]);
      const prediction = predictionSnap.data();
      if (!prediction) throw new Error(`Prediction ontbreekt: ${predictionRef.path}`);
      const ledger = ledgerSnap.data() ?? null;
      const scores = predictionScores(prediction);
      const newPoints = calculatePoints(scores.home, scores.away, realHome, realAway);
      const predictionProcessed = prediction.verwerkt === true;
      const predictionResultKey = firstString(prediction, ['verwerktVoorUitslag']);
      const ledgerProcessed = ledger?.processed === true;

      let previousPoints = 0;
      let adoptsExisting = false;
      if (ledgerProcessed) {
        previousPoints = firstInt(ledger, ['points']);
      } else if (predictionProcessed && predictionResultKey) {
        previousPoints = firstInt(prediction, ['punten']);
        adoptsExisting = true;
      }
      const delta = newPoints - previousPoints;

      const user = userSnap.data() ?? {};
      const currentA = firstInt(user, ['punten_A']);
      const currentB = firstInt(user, ['punten_B']);
      const nextA = userPointsField === 'punten_A' ? currentA + delta : currentA;
      const nextB = userPointsField === 'punten_B' ? currentB + delta : currentB;
      const nextTotal = Math.max(nextA, nextB);

      transaction.set(predictionRef, {
        punten: newPoints,
        verwerkt: true,
        verwerktVoorUitslag: resultKey,
      }, { merge: true });

      transaction.set(ledgerRef, {
        userId: item.userId,
        matchId,
        division,
        predictionPath: predictionRef.path,
        points: newPoints,
        resultKey,
        processed: true,
        updatedAt: FieldValue.serverTimestamp(),
        ...(ledgerSnap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
        ...(adoptsExisting ? { adoptedExistingContribution: true } : {}),
        repairedBy: 'repair_partial_match_points.cjs',
      }, { merge: true });

      transaction.set(userRef, {
        punten_A: nextA,
        punten_B: nextB,
        totalen: nextTotal,
      }, { merge: true });
    });
    processed += 1;
  }

  await matchRef.set({
    processed: true,
    verwerkt: true,
    processingStatus: 'processed',
    predictionProcessingComplete: true,
    predictionSourceDocuments: docs.length,
    predictionSelectedUsers: preview.length,
    predictionProcessedUsers: processed,
    processedResultKey: resultKey,
    processedAt: FieldValue.serverTimestamp(),
    processingError: FieldValue.delete(),
    processingFailedAt: FieldValue.delete(),
    repairedBy: 'repair_partial_match_points.cjs',
    repairedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.error(`\nHerstel voltooid voor ${matchId}: ${processed}/${preview.length} gebruikers, punten-delta ${totalDelta}.`);
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
