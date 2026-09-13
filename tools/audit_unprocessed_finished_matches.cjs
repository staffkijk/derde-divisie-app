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

async function main() {
  const seasonId = await activeSeasonId();
  const snap = await db.collection('seasons').doc(seasonId).collection('matches').get();
  const problems = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const homeScore = firstInt(data, ['homeScore', 'uitslagThuis', 'thuisScore']);
    const awayScore = firstInt(data, ['awayScore', 'uitslagUit', 'uitScore']);
    const status = firstString(data, ['status']).toLowerCase();
    const resultConfirmed = data.resultConfirmed === true;
    const looksFinished = homeScore !== null && awayScore !== null &&
      (status === 'finished' || resultConfirmed);
    if (!looksFinished) continue;

    const processed = data.processed === true && data.verwerkt === true;
    const processingStatus = firstString(data, ['processingStatus']);
    const complete = data.predictionProcessingComplete;

    if (processed && processingStatus === 'processed' && complete !== false) {
      continue;
    }

    problems.push({
      matchId: doc.id,
      division: firstString(data, ['division', 'divisie', 'competitie']),
      round: firstInt(data, ['round', 'speelronde', 'ronde']),
      result: `${homeScore}-${awayScore}`,
      processed: data.processed === true,
      verwerkt: data.verwerkt === true,
      processingStatus,
      predictionProcessingComplete: complete ?? null,
      predictionSelectedUsers: firstInt(data, ['predictionSelectedUsers']),
      predictionProcessedUsers: firstInt(data, ['predictionProcessedUsers']),
      processingAttempts: firstInt(data, ['processingAttempts']),
      processingError: firstString(data, ['processingError']),
    });
  }

  problems.sort((a, b) =>
    String(a.division).localeCompare(String(b.division)) ||
    (a.round ?? 0) - (b.round ?? 0) ||
    a.matchId.localeCompare(b.matchId));

  console.log(JSON.stringify({
    mode: 'READ_ONLY',
    seasonId,
    checkedMatches: snap.size,
    problemCount: problems.length,
    problems,
  }, null, 2));

  if (problems.length) {
    process.exitCode = 2;
  }
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
