#!/usr/bin/env node

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const matchArg = process.argv.find((value) => value.startsWith('--match='));
const seasonArg = process.argv.find((value) => value.startsWith('--season='));
const matchId = matchArg?.split('=')[1]?.trim() || 'b_05_05';
const explicitSeason = seasonArg?.split('=')[1]?.trim() || null;

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
    home: firstInt(data, [
      'scoreThuis', 'thuis', 'home', 'voorspellingThuis', 'homeGoals',
      'goalsHome', 'homeScore', 'predHome',
    ]),
    away: firstInt(data, [
      'scoreUit', 'uit', 'away', 'voorspellingUit', 'awayGoals',
      'goalsAway', 'awayScore', 'predAway',
    ]),
  };
}

function calculatePoints(predHome, predAway, realHome, realAway) {
  if (predHome === realHome && predAway === realAway) return 10;
  const realDraw = realHome === realAway;
  const predDraw = predHome === predAway;
  if (realDraw && predDraw) return 7;

  let points = 0;
  const winnerCorrect = !realDraw && !predDraw &&
      Math.sign(realHome - realAway) === Math.sign(predHome - predAway);
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
  const matchSnap = await db.collection('seasons').doc(seasonId).collection('matches').doc(matchId).get();
  if (!matchSnap.exists) throw new Error(`Wedstrijd ${matchId} bestaat niet in ${seasonId}.`);
  const match = matchSnap.data() ?? {};
  const realHome = firstInt(match, ['homeScore', 'uitslagThuis', 'thuisScore']);
  const realAway = firstInt(match, ['awayScore', 'uitslagUit', 'uitScore']);
  const division = firstString(match, ['division', 'divisie']).toUpperCase() || matchId.charAt(0).toUpperCase();

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

  const rows = [];
  const stateCounts = {};
  for (const [userId, entry] of selected.entries()) {
    const prediction = entry.doc.data();
    const scores = predictionScores(prediction);
    const expectedPoints = calculatePoints(scores.home, scores.away, realHome, realAway);
    const ledgerId = `${division}_${userId}_${matchId}`;
    const [ledgerSnap, userSnap] = await Promise.all([
      db.collection('seasons').doc(seasonId).collection('predictionContributions').doc(ledgerId).get(),
      db.collection('users').doc(userId).get(),
    ]);
    const ledger = ledgerSnap.data() ?? null;
    const user = userSnap.data() ?? {};
    const label = firstString(user, ['displayName', 'gebruikersnaam', 'username', 'naam', 'name', 'email']) || userId;
    const predictionProcessed = prediction.verwerkt === true;
    const ledgerProcessed = ledger?.processed === true;
    const key = `prediction=${predictionProcessed}|ledger=${ledgerProcessed}`;
    stateCounts[key] = (stateCounts[key] ?? 0) + 1;

    rows.push({
      userId,
      label,
      synthetic: userId.startsWith('syn_'),
      predictionPath: entry.doc.ref.path,
      prediction: `${scores.home}-${scores.away}`,
      result: `${realHome}-${realAway}`,
      expectedPoints,
      predictionPoints: firstInt(prediction, ['punten']),
      predictionProcessed,
      predictionResultKey: firstString(prediction, ['verwerktVoorUitslag']),
      ledgerExists: ledgerSnap.exists,
      ledgerProcessed,
      ledgerPoints: ledger ? firstInt(ledger, ['points']) : null,
      ledgerResultKey: ledger ? firstString(ledger, ['resultKey']) : '',
      storedA: firstInt(user, ['punten_A']),
      storedB: firstInt(user, ['punten_B']),
      storedTotal: firstInt(user, ['totalen']),
    });
  }

  rows.sort((a, b) => a.label.localeCompare(b.label));
  console.log(JSON.stringify({
    mode: 'READ_ONLY',
    seasonId,
    matchId,
    division,
    result: `${realHome}-${realAway}`,
    selectedUsers: rows.length,
    stateCounts,
    rows,
  }, null, 2));
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
