/* eslint-disable no-console */

const { initializeApp, getApps, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

/**
 * Eerst true laten staan.
 * Daarna pas op false zetten als de dry-run klopt.
 */
const DRY_RUN = false;

const SEASON_ID = "2026-2027";
const SEASON_LABEL = "2026/2027";

const SEASON_REF = db.collection("seasons").doc(SEASON_ID);

const SUBCOLLECTIONS_TO_PREPARE = [
  "teams",
  "matches",
  "standings",
  "periodStandings",
  "predictions",
  "poules",
  "settings",
];

async function docExists(ref) {
  const snap = await ref.get();
  return snap.exists;
}

async function countCollection(collectionRef) {
  const snap = await collectionRef.count().get();
  return snap.data().count || 0;
}

async function inspectCurrentState() {
  const seasonExists = await docExists(SEASON_REF);

  const topLevelCounts = {
    seasons: await countCollection(db.collection("seasons")),
    matches: await countCollection(db.collection("matches")),
    standen: await countCollection(db.collection("standen")),
    poules: await countCollection(db.collection("poules")),
    voorspellingen: await countCollection(db.collection("voorspellingen")),
    season_archives: await countCollection(db.collection("season_archives")),
    standings_archive: await countCollection(db.collection("standings_archive")),
    users: await countCollection(db.collection("users")),
    usernames: await countCollection(db.collection("usernames")),
  };

  const seasonSubcollectionCounts = {};

  for (const subcollectionName of SUBCOLLECTIONS_TO_PREPARE) {
    seasonSubcollectionCounts[subcollectionName] = await countCollection(
      SEASON_REF.collection(subcollectionName)
    );
  }

  return {
    seasonExists,
    topLevelCounts,
    seasonSubcollectionCounts,
  };
}

function buildSeasonMetadata() {
  return {
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,
    status: "preparation",
    isCurrentSeason: true,
    isArchived: false,
    isFinal: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    note:
      "Basisstructuur voor seizoen 2026/2027. Er zijn nog geen teams, wedstrijden, standen, voorspellingen of poules geïmporteerd.",
    structureVersion: 1,
    divisions: {
      A: {
        label: "Derde Divisie A",
        expectedTeams: 18,
        expectedMatches: 306,
      },
      B: {
        label: "Derde Divisie B",
        expectedTeams: 18,
        expectedMatches: 306,
      },
    },
    predictionRules: {
      exactScore: 10,
      correctWinner: 5,
      correctDraw: 7,
      correctHomeGoals: 2,
      correctAwayGoals: 2,
      defaultDeadline: "zaterdag 12:00",
    },
  };
}

function buildCurrentSeasonDoc() {
  return {
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,
    status: "preparation",
    source: "setup_season_2026_2027.js",
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function buildSubcollectionMeta(subcollectionName) {
  const descriptions = {
    teams: "Teams per divisie voor seizoen 2026/2027.",
    matches: "Wedstrijden en uitslagen per divisie en speelronde voor seizoen 2026/2027.",
    standings: "Actuele standen per divisie voor seizoen 2026/2027.",
    periodStandings: "Periodestanden per divisie en periode voor seizoen 2026/2027.",
    predictions: "Algemene gebruikersvoorspellingen voor seizoen 2026/2027.",
    poules: "Poules voor seizoen 2026/2027.",
    settings: "Seizoensinstellingen, deadlines en configuratie voor seizoen 2026/2027.",
  };

  return {
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,
    collection: subcollectionName,
    description: descriptions[subcollectionName] || "",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    isMetaDocument: true,
  };
}

async function writeSetup() {
  const batch = db.batch();

  batch.set(SEASON_REF, buildSeasonMetadata(), { merge: true });

  batch.set(
    db.collection("system").doc("current_season"),
    buildCurrentSeasonDoc(),
    { merge: true }
  );

  batch.set(
    db.collection("maintenance").doc("setup_season_2026_2027"),
    {
      type: "setup_season_2026_2027",
      dryRun: false,
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      createdAt: FieldValue.serverTimestamp(),
      note:
        "Basisstructuur seizoen 2026/2027 aangemaakt. Geen live archieven, users, usernames, x_posts of historische standen verwijderd.",
      subcollectionsPrepared: SUBCOLLECTIONS_TO_PREPARE,
    },
    { merge: true }
  );

  for (const subcollectionName of SUBCOLLECTIONS_TO_PREPARE) {
    batch.set(
      SEASON_REF.collection(subcollectionName).doc("_meta"),
      buildSubcollectionMeta(subcollectionName),
      { merge: true }
    );
  }

  await batch.commit();
}

async function printSeasonPreview() {
  console.log("");
  console.log("Structuur die wordt aangemaakt:");
  console.log("");
  console.log(`seasons/${SEASON_ID}`);
  for (const subcollectionName of SUBCOLLECTIONS_TO_PREPARE) {
    console.log(`seasons/${SEASON_ID}/${subcollectionName}/_meta`);
  }
  console.log("system/current_season");
  console.log("maintenance/setup_season_2026_2027");
}

async function main() {
  console.log("Setup seizoen 2026/2027");
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  const before = await inspectCurrentState();

  console.log("Huidige staat vooraf:");
  console.log("");
  console.log("Bestaat seasons/2026-2027 al?");
  console.log(before.seasonExists ? "JA" : "NEE");

  console.log("");
  console.log("Top-level aantallen:");
  console.table(before.topLevelCounts);

  console.log("");
  console.log("Subcollecties onder seasons/2026-2027 vooraf:");
  console.table(before.seasonSubcollectionCounts);

  await printSeasonPreview();

  console.log("");
  console.log("Belangrijk:");
  console.log("- users wordt NIET aangepast");
  console.log("- usernames wordt NIET aangepast");
  console.log("- season_archives wordt NIET aangepast");
  console.log("- standings_archive wordt NIET aangepast");
  console.log("- x_posts wordt NIET aangepast");
  console.log("- oude live collecties blijven leeg");
  console.log("- er worden nog geen teams of wedstrijden geïmporteerd");

  if (DRY_RUN) {
    console.log("");
    console.log("DRY_RUN staat op true.");
    console.log("Er is niets geschreven.");
    console.log("");
    console.log("Als dit klopt, zet dan in dit bestand:");
    console.log("const DRY_RUN = false;");
    console.log("");
    console.log("Daarna opnieuw uitvoeren:");
    console.log("node tools/setup_season_2026_2027.js");
    return;
  }

  console.log("");
  console.log("Schrijven gestart...");

  await writeSetup();

  const after = await inspectCurrentState();

  console.log("");
  console.log("Staat achteraf:");
  console.log("");
  console.log("Bestaat seasons/2026-2027 nu?");
  console.log(after.seasonExists ? "JA" : "NEE");

  console.log("");
  console.log("Top-level aantallen:");
  console.table(after.topLevelCounts);

  console.log("");
  console.log("Subcollecties onder seasons/2026-2027 achteraf:");
  console.table(after.seasonSubcollectionCounts);

  console.log("");
  console.log("Setup seizoen 2026/2027 klaar.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Setup seizoen 2026/2027 mislukt:");
    console.error(error);
    process.exit(1);
  });