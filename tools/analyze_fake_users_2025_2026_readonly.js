/* eslint-disable no-console */
/**
 * READ-ONLY audit of archived fake users from 2025/2026.
 *
 * This file intentionally only imports Firebase Admin read APIs. It contains no
 * set/update/delete/createUser/batch/bulkWriter calls and never writes output to
 * Firestore or Authentication.
 */

const { applicationDefault, getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

const PROJECT_ID = "derde-divisie-app";
const OLD_SEASON = "2025-2026";
const CURRENT_SEASON = "2026-2027";
const IN_QUERY_LIMIT = 30;

if (getApps().length === 0) {
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
}

const db = getFirestore();
const auth = getAuth();

function chunks(values, size) {
  const result = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

function pick(data, names, fallback = "") {
  for (const name of names) {
    if (data[name] !== undefined && data[name] !== null) return data[name];
  }
  return fallback;
}

function uidFrom(data, documentId = "") {
  return String(pick(data, ["gebruikerId", "userId", "uid", "gebruikerID"], documentId));
}

function matchIdFrom(data, documentId = "") {
  return String(pick(data, ["wedstrijdId", "matchId", "wedstrijdID"], documentId));
}

function divisionFrom(data) {
  const raw = String(pick(data, ["divisie", "division", "competitie", "competition"], ""));
  const normalized = raw.trim().toUpperCase();
  if (["A", "DDA", "DERDE DIVISIE A"].includes(normalized)) return "A";
  if (["B", "DDB", "DERDE DIVISIE B"].includes(normalized)) return "B";
  return normalized;
}

function compactProfile(data) {
  if (!data) return null;
  const excluded = new Set([
    "email", "username", "usernameLower", "usernameKey", "displayName",
    "punten_A", "punten_B", "points", "totalen", "predictionsMade",
  ]);
  return Object.fromEntries(
    Object.entries(data)
      .filter(([key]) => !excluded.has(key))
      .map(([key, value]) => {
        if (value && typeof value.toDate === "function") return [key, value.toDate().toISOString()];
        if (value && typeof value === "object" && !Array.isArray(value)) {
          return [key, `[object: ${Object.keys(value).sort().join(", ")}]`];
        }
        return [key, value];
      }),
  );
}

async function getDocsByIds(collectionRef, ids) {
  const found = new Map();
  for (const group of chunks(ids, 100)) {
    const snapshots = await db.getAll(...group.map((id) => collectionRef.doc(id)));
    for (const snapshot of snapshots) {
      if (snapshot.exists) found.set(snapshot.id, snapshot.data());
    }
  }
  return found;
}

async function getAuthUsers(uids) {
  const found = new Map();
  for (const group of chunks(uids, 100)) {
    const result = await auth.getUsers(group.map((uid) => ({ uid })));
    for (const user of result.users) found.set(user.uid, user);
  }
  return found;
}

async function queryByUid(collectionRef, uids, fieldNames) {
  const docs = new Map();
  for (const field of fieldNames) {
    for (const group of chunks(uids, IN_QUERY_LIMIT)) {
      const snapshot = await collectionRef.where(field, "in", group).get();
      for (const doc of snapshot.docs) docs.set(doc.ref.path, { id: doc.id, data: doc.data() });
    }
  }
  return [...docs.values()];
}

function distribution(values) {
  const counts = new Map();
  for (const value of values) counts.set(String(value), (counts.get(String(value)) || 0) + 1);
  return Object.fromEntries([...counts.entries()].sort((a, b) => Number(a[0]) - Number(b[0])));
}

async function main() {
  console.log("READ-ONLY analyse fake gebruikers 2025/2026 -> status 2026/2027");
  console.log("Project:", PROJECT_ID);
  console.log("");

  const archiveRef = db.collection("season_archives").doc(OLD_SEASON);
  const archivedFakeSnapshot = await archiveRef
    .collection("rankings").doc("global").collection("users")
    .where("isFake", "==", true).get();
  const archived = archivedFakeSnapshot.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));
  const uids = archived.map((row) => row.uid);

  const [liveUsers, authUsers, currentMatchesSnapshot, oldResultsA, oldResultsB] = await Promise.all([
    getDocsByIds(db.collection("users"), uids),
    getAuthUsers(uids),
    db.collection("seasons").doc(CURRENT_SEASON).collection("matches").get(),
    archiveRef.collection("divisions").doc("A").collection("results").get(),
    archiveRef.collection("divisions").doc("B").collection("results").get(),
  ]);

  const currentMatchIds = new Set(currentMatchesSnapshot.docs.map((doc) => doc.id));
  const currentMatchDivision = new Map(
    currentMatchesSnapshot.docs.map((doc) => [doc.id, divisionFrom(doc.data())]),
  );

  const [seasonPredictionsSnapshot, rootPredictions, finalPredictions] = await Promise.all([
    db.collection("seasons").doc(CURRENT_SEASON).collection("predictions").get(),
    queryByUid(db.collection("voorspellingen"), uids, ["gebruikerId", "userId", "uid"]),
    queryByUid(db.collection("eindstand_voorspellingen"), uids, ["gebruikerId", "userId", "uid"]),
  ]);

  const uidSet = new Set(uids);
  const regularByUid = new Map(uids.map((uid) => [uid, new Map()]));
  const sourceCounts = { seasonCollection: 0, rootCurrentSeason: 0, rootExcludedOtherSeason: 0 };

  for (const doc of seasonPredictionsSnapshot.docs) {
    const data = doc.data();
    const uid = uidFrom(data);
    if (!uidSet.has(uid)) continue;
    const matchId = matchIdFrom(data, doc.id);
    regularByUid.get(uid).set(matchId, { source: "season", division: divisionFrom(data) || currentMatchDivision.get(matchId) });
    sourceCounts.seasonCollection += 1;
  }

  for (const doc of rootPredictions) {
    const data = doc.data;
    const uid = uidFrom(data);
    const matchId = matchIdFrom(data, doc.id);
    const explicitSeason = String(pick(data, ["seasonId", "season", "seizoen"], ""));
    const isCurrent = explicitSeason === CURRENT_SEASON || (!explicitSeason && currentMatchIds.has(matchId));
    if (!isCurrent) {
      sourceCounts.rootExcludedOtherSeason += 1;
      continue;
    }
    regularByUid.get(uid).set(matchId, { source: "root", division: divisionFrom(data) || currentMatchDivision.get(matchId) });
    sourceCounts.rootCurrentSeason += 1;
  }

  const finalsByUid = new Map(uids.map((uid) => [uid, []]));
  for (const doc of finalPredictions) {
    const data = doc.data;
    const explicitSeason = String(pick(data, ["seasonId", "season", "seizoen"], ""));
    if (explicitSeason !== CURRENT_SEASON) continue;
    const uid = uidFrom(data);
    finalsByUid.get(uid).push({ id: doc.id, division: divisionFrom(data), fields: Object.keys(data).sort() });
  }

  const rows = archived.map((old) => {
    const live = liveUsers.get(old.uid) || null;
    const authUser = authUsers.get(old.uid) || null;
    const regular = [...regularByUid.get(old.uid).entries()];
    const byDivision = distribution(regular.map(([, value]) => value.division || "onbekend"));
    const finals = finalsByUid.get(old.uid);
    return {
      uid: old.uid,
      oldDisplayName: String(pick(old, ["displayName", "username", "naam"], "")),
      oldEmail: String(pick(old, ["email"], "")),
      oldPredictionCount: Number(pick(old, ["aantalVoorspellingen"], 0)),
      currentUserDocument: Boolean(live),
      currentUsername: live ? String(pick(live, ["username", "displayName", "naam"], "")) : "",
      currentProfile: compactProfile(live),
      authExists: Boolean(authUser),
      authEmail: authUser ? authUser.email || "" : "",
      predictions2026_27: regular.length,
      predictions2026_27ByDivision: byDivision,
      finalStanding2026_27: finals.length,
      finalStanding2026_27Divisions: finals.map((item) => item.division || item.id),
    };
  }).sort((a, b) => a.oldDisplayName.localeCompare(b.oldDisplayName, "nl"));

  const totals = {
    oldFakeAccounts: rows.length,
    stillInUsers: rows.filter((row) => row.currentUserDocument).length,
    stillInAuthentication: rows.filter((row) => row.authExists).length,
    withPredictions2026_27: rows.filter((row) => row.predictions2026_27 > 0).length,
    withFinalStandingPrediction2026_27: rows.filter((row) => row.finalStanding2026_27 > 0).length,
    absentFromUsers: rows.filter((row) => !row.currentUserDocument).length,
    absentFromAuthentication: rows.filter((row) => !row.authExists).length,
    absentFromBothUsersAndAuthentication: rows.filter((row) => !row.currentUserDocument && !row.authExists).length,
  };

  const oldCountDistribution = distribution(rows.map((row) => row.oldPredictionCount));
  const oldCountVsLiveCompetitions = {};
  for (const row of rows) {
    const competitions = liveUsers.get(row.uid)?.competitions;
    const key = `${row.oldPredictionCount}|${Array.isArray(competitions) ? competitions.join("+") : "geen-huidig-userdoc"}`;
    oldCountVsLiveCompetitions[key] = (oldCountVsLiveCompetitions[key] || 0) + 1;
  }

  console.log("VOLLEDIG OVERZICHT");
  console.log("uid | oude displayName | oud emailadres | huidig user document | huidige username | auth bestaat | voorspellingen 2026/27 | eindstand 2026/27");
  for (const row of rows) {
    console.log([
      row.uid, row.oldDisplayName, row.oldEmail,
      row.currentUserDocument ? "ja" : "nee", row.currentUsername,
      row.authExists ? "ja" : "nee", row.predictions2026_27,
      row.finalStanding2026_27Divisions.length ? row.finalStanding2026_27Divisions.join("+") : "0",
    ].join(" | "));
  }

  console.log("\nTOTALEN");
  console.table(totals);
  console.log("\nPROFIELGEGEVENS EN DETAILS (JSON)");
  console.log(JSON.stringify(rows, null, 2));
  console.log("\n306/612 FEITEN");
  console.log(JSON.stringify({
    archivedPredictionCountDistribution: oldCountDistribution,
    archivedResultsPerDivision: { A: oldResultsA.size, B: oldResultsB.size },
    currentMatchesPerDivision: distribution(currentMatchesSnapshot.docs.map((doc) => divisionFrom(doc.data()) || "onbekend")),
    archivedCountVersusCurrentUserCompetitions: oldCountVsLiveCompetitions,
    explanation: "Het archief bevat 306 uitslagen in divisie A en 306 in divisie B. De fake-generator doorloopt per gekozen competitie 34 speelronden en kiest exact 9 wedstrijden per ronde. Dat is 34 x 9 = 306 per competitie; users met alleen A of alleen B krijgen 306, users met competitions [A,B] krijgen 612. De kruistabel hierboven toetst dit aan de daadwerkelijk nog aanwezige users.competitions-velden.",
  }, null, 2));
  console.log("\nBRONCONTROLE 2026/27");
  console.log(JSON.stringify({
    seasonPredictionDocumentsForTargetUids: sourceCounts.seasonCollection,
    rootPredictionDocumentsForTargetUidsCurrentSeason: sourceCounts.rootCurrentSeason,
    rootPredictionDocumentsExcludedAsOtherOrUnknownSeason: sourceCounts.rootExcludedOtherSeason,
    uniqueRegularPredictionsAfterDeduplication: rows.reduce((sum, row) => sum + row.predictions2026_27, 0),
    finalStandingDocumentsCurrentSeason: rows.reduce((sum, row) => sum + row.finalStanding2026_27, 0),
  }, null, 2));
  console.log("\nREAD-ONLY afgerond; er zijn geen Firebase-writes uitgevoerd.");
}

main().catch((error) => {
  console.error("Analyse mislukt:");
  console.error(error);
  process.exitCode = 1;
});
