#!/usr/bin/env node

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { FieldPath, getFirestore, Timestamp } = require('firebase-admin/firestore');

const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');
const roundArg = process.argv.find((value) => value.startsWith('--round='));
const seasonArg = process.argv.find((value) => value.startsWith('--season='));
const requestedRound = Number(roundArg?.split('=')[1] ?? '5');
const explicitSeason = seasonArg?.split('=')[1]?.trim() || null;

if (!Number.isInteger(requestedRound) || requestedRound <= 0) {
  throw new Error('Gebruik --round=<positief geheel getal>.');
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

function int(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function firstInt(data, keys) {
  for (const key of keys) {
    if (data[key] === undefined || data[key] === null) continue;
    const parsed = Number.parseInt(String(data[key]), 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function firstString(data, keys) {
  for (const key of keys) {
    const value = String(data[key] ?? '').trim();
    if (value) return value;
  }
  return '';
}

function divisionCode(data) {
  const raw = firstString(data, ['division', 'divisie', 'competitie']).toUpperCase();
  if (/(^|\s)A($|\s)/.test(raw) || raw === 'DDA' || raw.endsWith(' A')) return 'A';
  if (/(^|\s)B($|\s)/.test(raw) || raw === 'DDB' || raw.endsWith(' B')) return 'B';
  return '';
}

function matchRound(data) {
  return firstInt(data, ['round', 'speelronde', 'ronde', 'wedstrijdRonde']) ?? 0;
}

function matchScores(data) {
  const home = firstInt(data, ['homeScore', 'uitslagThuis', 'thuisScore']);
  const away = firstInt(data, ['awayScore', 'uitslagUit', 'uitScore']);
  return { home, away };
}

function isFinished(data) {
  const status = String(data.status ?? '').trim().toLowerCase();
  const { home, away } = matchScores(data);
  return home !== null && away !== null && (status === 'finished' || data.resultConfirmed === true || data.processed === true || data.verwerkt === true);
}

function matchTimestamp(data) {
  for (const key of ['scheduledAt', 'timestamp', 'datum', 'date']) {
    const value = data[key];
    if (value instanceof Timestamp) return value;
  }
  return null;
}

function predictionUserId(data) {
  return firstString(data, ['gebruikerId', 'userId', 'uid']);
}

function predictionTimestamp(data) {
  return data.timestamp instanceof Timestamp ? data.timestamp : null;
}

function predictionScores(data) {
  return {
    home: firstInt(data, [
      'scoreThuis', 'thuis', 'home', 'voorspellingThuis', 'homeGoals',
      'goalsHome', 'homeScore', 'predHome',
    ]) ?? 0,
    away: firstInt(data, [
      'scoreUit', 'uit', 'away', 'voorspellingUit', 'awayGoals',
      'goalsAway', 'awayScore', 'predAway',
    ]) ?? 0,
  };
}

function calculatePoints(predHome, predAway, realHome, realAway) {
  if (predHome === realHome && predAway === realAway) return 10;
  const realDraw = realHome === realAway;
  const predDraw = predHome === predAway;
  if (realDraw && predDraw) return 7;

  let points = 0;
  const realDiff = realHome - realAway;
  const predDiff = predHome - predAway;
  const winnerCorrect = !realDraw && !predDraw && Math.sign(realDiff) === Math.sign(predDiff);
  if (winnerCorrect) points += 5;
  if (predHome === realHome) points += 2;
  if (predAway === realAway) points += 2;
  return Math.min(points, 10);
}

async function activeSeasonId() {
  if (explicitSeason) return explicitSeason;
  const snap = await db.collection('system').doc('current_season').get();
  const data = snap.data() ?? {};
  const id = firstString(data, ['seasonId', 'id', 'currentSeason', 'season']);
  if (id) return id;
  return '2026-2027';
}

async function queryPredictionDocs(collection, field, matchId) {
  const snap = await collection.where(field, '==', matchId).get();
  return snap.docs;
}

async function allPredictionDocsForMatch(seasonId, matchId) {
  const byPath = new Map();
  const seasonPredictions = db.collection('seasons').doc(seasonId).collection('predictions');
  const rootPredictions = db.collection('voorspellingen');

  for (const collection of [seasonPredictions, rootPredictions]) {
    for (const field of ['wedstrijdId', 'matchId']) {
      const docs = await queryPredictionDocs(collection, field, matchId);
      for (const doc of docs) byPath.set(doc.ref.path, doc);
    }
  }
  return [...byPath.values()];
}

function selectLatestPerUser(docs, deadline) {
  const selected = new Map();
  const skippedMissingTimestamp = [];
  const skippedAfterDeadline = [];

  for (const doc of docs) {
    const data = doc.data();
    const userId = predictionUserId(data);
    if (!userId) continue;
    const ts = predictionTimestamp(data);

    if (deadline && !ts) {
      skippedMissingTimestamp.push({ userId, path: doc.ref.path });
      continue;
    }
    if (deadline && ts.toDate() > deadline) {
      skippedAfterDeadline.push({ userId, path: doc.ref.path, timestamp: ts.toDate().toISOString() });
      continue;
    }

    const millis = ts?.toMillis() ?? 0;
    const current = selected.get(userId);
    if (!current || millis >= current.millis) {
      selected.set(userId, { doc, millis });
    }
  }

  return { selected, skippedMissingTimestamp, skippedAfterDeadline };
}

async function userLabels() {
  const snap = await db.collection('users').get();
  const users = new Map();
  for (const doc of snap.docs) {
    const data = doc.data();
    users.set(doc.id, {
      ref: doc.ref,
      storedA: int(data.punten_A),
      storedB: int(data.punten_B),
      storedTotal: int(data.totalen),
      label: firstString(data, ['displayName', 'gebruikersnaam', 'username', 'naam', 'name', 'email']) || doc.id,
    });
  }
  return users;
}

async function main() {
  const seasonId = await activeSeasonId();
  const matchesSnap = await db.collection('seasons').doc(seasonId).collection('matches').get();
  const matches = matchesSnap.docs
    .map((doc) => ({ id: doc.id, ref: doc.ref, data: doc.data() }))
    .filter(({ data }) => isFinished(data) && matchRound(data) <= requestedRound)
    .sort((a, b) => matchRound(a.data) - matchRound(b.data) || a.id.localeCompare(b.id));

  if (!matches.length) {
    throw new Error(`Geen afgeronde wedstrijden gevonden t/m speelronde ${requestedRound} in ${seasonId}.`);
  }

  const expected = new Map();
  const roundContribution = new Map();
  const diagnostics = [];

  for (const match of matches) {
    const division = divisionCode(match.data);
    const round = matchRound(match.data);
    const { home: realHome, away: realAway } = matchScores(match.data);
    if (!division || realHome === null || realAway === null) {
      diagnostics.push({ type: 'match_schema', matchId: match.id, division, round });
      continue;
    }

    const ts = matchTimestamp(match.data);
    let deadline = null;
    if (ts) {
      const d = ts.toDate();
      deadline = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12, 0, 0, 0);
    }

    const docs = await allPredictionDocsForMatch(seasonId, match.id);
    const selection = selectLatestPerUser(docs, deadline);

    if (selection.skippedMissingTimestamp.length) {
      diagnostics.push({
        type: 'missing_prediction_timestamp',
        matchId: match.id,
        round,
        users: selection.skippedMissingTimestamp,
      });
    }

    for (const [userId, entry] of selection.selected.entries()) {
      const scores = predictionScores(entry.doc.data());
      const points = calculatePoints(scores.home, scores.away, realHome, realAway);
      const current = expected.get(userId) ?? { A: 0, B: 0 };
      current[division] += points;
      expected.set(userId, current);

      if (round === requestedRound) {
        const roundCurrent = roundContribution.get(userId) ?? { A: 0, B: 0, matches: [] };
        roundCurrent[division] += points;
        roundCurrent.matches.push({
          matchId: match.id,
          division,
          prediction: `${scores.home}-${scores.away}`,
          result: `${realHome}-${realAway}`,
          points,
          path: entry.doc.ref.path,
        });
        roundContribution.set(userId, roundCurrent);
      }
    }
  }

  const users = await userLabels();
  const allUserIds = new Set([...users.keys(), ...expected.keys()]);
  const mismatches = [];

  for (const userId of allUserIds) {
    const user = users.get(userId);
    const exp = expected.get(userId) ?? { A: 0, B: 0 };
    const expectedTotal = Math.max(exp.A, exp.B);
    const storedA = user?.storedA ?? 0;
    const storedB = user?.storedB ?? 0;
    const storedTotal = user?.storedTotal ?? Math.max(storedA, storedB);
    if (storedA !== exp.A || storedB !== exp.B || storedTotal !== expectedTotal) {
      mismatches.push({
        userId,
        label: user?.label ?? userId,
        storedA,
        expectedA: exp.A,
        deltaA: exp.A - storedA,
        storedB,
        expectedB: exp.B,
        deltaB: exp.B - storedB,
        storedTotal,
        expectedTotal,
        round: roundContribution.get(userId) ?? { A: 0, B: 0, matches: [] },
      });
    }
  }

  mismatches.sort((a, b) => a.label.localeCompare(b.label));

  console.log(JSON.stringify({
    mode: apply ? 'APPLY' : 'DRY_RUN',
    seasonId,
    throughRound: requestedRound,
    finishedMatches: matches.length,
    usersWithExpectedPoints: expected.size,
    mismatchCount: mismatches.length,
    mismatches,
    diagnostics,
  }, null, 2));

  if (!apply) {
    console.error('\nDRY RUN: er is niets gewijzigd. Voeg --apply toe om uitsluitend de hierboven gevonden user-totalen exact te herstellen.');
    return;
  }

  if (diagnostics.some((item) => item.type === 'match_schema')) {
    throw new Error('Apply gestopt: minstens één wedstrijd heeft onvoldoende schema-informatie. Eerst oplossen en opnieuw dry-runnen.');
  }

  let repaired = 0;
  for (const item of mismatches) {
    const ref = users.get(item.userId)?.ref;
    if (!ref) {
      console.error(`SKIP ${item.userId}: users-document ontbreekt.`);
      continue;
    }
    await ref.set({
      punten_A: item.expectedA,
      punten_B: item.expectedB,
      totalen: item.expectedTotal,
      pointsReconciledAt: new Date(),
      pointsReconciledThroughRound: requestedRound,
      pointsReconciledSeason: seasonId,
    }, { merge: true });
    repaired += 1;
  }

  console.error(`\nHerstel voltooid: ${repaired} users-documenten bijgewerkt.`);
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
