/* eslint-disable no-console */

const { initializeApp, applicationDefault, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

if (!getApps().length) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

const SEASON_ID = "2026-2027";
const DRY_RUN = false;

const ZERO_FIELDS = {
  played: 0,
  wins: 0,
  draws: 0,
  losses: 0,
  goalsFor: 0,
  goalsAgainst: 0,
  goalDifference: 0,
  points: 0,
};

async function main() {
  console.log(`Standings nulvelden herstellen seizoen ${SEASON_ID}`);
  console.log("Firebase project: derde-divisie-app");
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  const standingsRef = db
    .collection("seasons")
    .doc(SEASON_ID)
    .collection("standings");

  const snap = await standingsRef.get();

  console.log(`Aantal standings gevonden: ${snap.size}`);
  console.log("");

  const rows = [];

  for (const doc of snap.docs) {
    const data = doc.data();

    const before = {
      played: data.played,
      wins: data.wins,
      draws: data.draws,
      losses: data.losses,
      goalsFor: data.goalsFor,
      goalsAgainst: data.goalsAgainst,
      goalDifference: data.goalDifference,
      points: data.points,
    };

    const update = {
      ...ZERO_FIELDS,
      updatedAt: FieldValue.serverTimestamp(),
    };

    rows.push({
      docId: doc.id,
      teamName: data.teamName || data.name || "",
      division: data.division || "",
      played: before.played ?? "",
      wins: before.wins ?? "",
      draws: before.draws ?? "",
      losses: before.losses ?? "",
      goalsFor: before.goalsFor ?? "",
      goalsAgainst: before.goalsAgainst ?? "",
      goalDifference: before.goalDifference ?? "",
      points: before.points ?? "",
    });

    if (!DRY_RUN) {
      await doc.ref.set(update, { merge: true });
    }
  }

  console.log("Huidige waarden vooraf:");
  console.table(rows);

  console.log("");

  if (DRY_RUN) {
    console.log("DRY_RUN = true, er is niets geschreven.");
  } else {
    console.log("Alle standings zijn aangevuld met numerieke nulvelden.");
  }

  console.log("");
  console.log("Klaar.");
}

main().catch((error) => {
  console.error("Herstel mislukt:");
  console.error(error);
  process.exit(1);
});