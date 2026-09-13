#!/usr/bin/env node

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const seasonArg = process.argv.find((value) => value.startsWith('--season='));
const explicitSeason = seasonArg?.split('=')[1]?.trim() || null;

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
  return null;
}

async function activeSeasonId() {
  if (explicitSeason) return explicitSeason;
  const snap = await db.collection('system').doc('current_season').get();
  const data = snap.data() ?? {};
  return firstString(data, ['seasonId', 'id', 'currentSeason', 'season']) || '2026-2027';
}

function snapshotProblem(doc, data, homeScore, awayScore, reason) {
  return {
    reason,
    matchId: doc.id,
    division: firstString(data, ['division', 'divisie', 'competitie']),
    round: firstInt(data, ['round', 'speelronde', 'ronde']),
    result: `${homeScore}-${awayScore}`,
    processed: data.processed === true,
    verwerkt: data.verwerkt === true,
    processingStatus: firstString(data, ['processingStatus']),
    predictionProcessingComplete: data.predictionProcessingComplete ?? null,
    predictionSelectedUsers: firstInt(data, ['predictionSelectedUsers']),
    predictionProcessedUsers: firstInt(data, ['predictionProcessedUsers']),
    processingAttempts: firstInt(data, ['processingAttempts']),
    processingError: firstString(data, ['processingError']),
  };
}

async function main() {
  const seasonId = await activeSeasonId();
  const snap = await db.collection('seasons').doc(seasonId).collection('matches').get();
  const problems = [];
  const legacyProcessed = [];
  let finishedMatches = 0;
  let verifiedProcessed = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const homeScore = firstInt(data, ['homeScore', 'uitslagThuis', 'thuisScore']);
    const awayScore = firstInt(data, ['awayScore', 'uitslagUit', 'uitScore']);
    const status = firstString(data, ['status']).toLowerCase();
    const resultConfirmed = data.resultConfirmed === true;
    const looksFinished = homeScore !== null && awayScore !== null &&
      (status === 'finished' || resultConfirmed);
    if (!looksFinished) continue;
    finishedMatches += 1;

    const processed = data.processed === true && data.verwerkt === true;
    const processingStatus = firstString(data, ['processingStatus']);
    const complete = data.predictionProcessingComplete;
    const selectedUsers = firstInt(data, ['predictionSelectedUsers']);
    const processedUsers = firstInt(data, ['predictionProcessedUsers']);

    // New processing contract: explicit success plus equal selected/processed counts.
    if (
      processed &&
      processingStatus === 'processed' &&
      complete === true &&
      selectedUsers !== null &&
      processedUsers !== null &&
      selectedUsers === processedUsers
    ) {
      verifiedProcessed += 1;
      continue;
    }

    // Historical matches were processed before these diagnostic fields existed.
    // They are not automatically errors just because the new metadata is absent.
    if (
      processed &&
      !processingStatus &&
      complete === undefined &&
      selectedUsers === null &&
      processedUsers === null
    ) {
      legacyProcessed.push({
        matchId: doc.id,
        division: firstString(data, ['division', 'divisie', 'competitie']),
        round: firstInt(data, ['round', 'speelronde', 'ronde']),
        result: `${homeScore}-${awayScore}`,
      });
      continue;
    }

    let reason = 'incomplete_processing_metadata';
    if (!processed) reason = 'not_processed';
    if (processingStatus === 'processing') reason = 'stuck_processing';
    if (processingStatus === 'failed') reason = 'processing_failed';
    if (complete === false) reason = 'prediction_processing_incomplete';
    if (
      selectedUsers !== null &&
      processedUsers !== null &&
      selectedUsers !== processedUsers
    ) {
      reason = 'selected_processed_mismatch';
    }

    problems.push(snapshotProblem(doc, data, homeScore, awayScore, reason));
  }

  const sortMatches = (a, b) =>
    String(a.division).localeCompare(String(b.division)) ||
    (a.round ?? 0) - (b.round ?? 0) ||
    a.matchId.localeCompare(b.matchId);
  problems.sort(sortMatches);
  legacyProcessed.sort(sortMatches);

  console.log(JSON.stringify({
    mode: 'READ_ONLY',
    seasonId,
    checkedMatches: snap.size,
    finishedMatches,
    verifiedProcessed,
    legacyProcessedCount: legacyProcessed.length,
    problemCount: problems.length,
    problems,
    legacyProcessed,
  }, null, 2));

  if (problems.length) {
    process.exitCode = 2;
  }
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
