/* eslint-disable no-console */

const { initializeApp, getApps, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const PROJECT_ID = "derde-divisie-app";
const SEASON_ID = "2026-2027";
const DRY_RUN = false;

if (!getApps().length) {
  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });
}

const db = getFirestore();

async function countCollection(collectionRef) {
  const snap = await collectionRef.count().get();
  return snap.data().count || 0;
}

async function readDoc(path) {
  const snap = await db.doc(path).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function assertSeasonIsReady() {
  const seasonPath = `seasons/${SEASON_ID}`;
  const seasonData = await readDoc(seasonPath);

  if (!seasonData) {
    throw new Error(`${seasonPath} bestaat niet. Draai eerst setup_season_2026_2027.js.`);
  }

  const currentSeasonData = await readDoc("system/current_season");

  if (!currentSeasonData) {
    throw new Error("system/current_season bestaat niet.");
  }

  if (currentSeasonData.seasonId !== SEASON_ID) {
    throw new Error(
      `system/current_season wijst naar ${currentSeasonData.seasonId}, niet naar ${SEASON_ID}.`
    );
  }
}

async function getTeams() {
  const teamsSnap = await db
    .collection("seasons")
    .doc(SEASON_ID)
    .collection("teams")
    .get();

  const teams = [];

  for (const doc of teamsSnap.docs) {
    if (doc.id === "_meta") continue;

    const data = doc.data();

    teams.push({
      teamId: doc.id,
      name: data.name || data.displayName || doc.id,
      displayName: data.displayName || data.name || doc.id,
      division: data.division,
      divisionLabel: data.divisionLabel || `Derde Divisie ${data.division}`,
      logoAsset: data.logoAsset || null,
      sortIndex: data.sortIndex || 999,
    });
  }

  teams.sort((a, b) => {
    if (a.division !== b.division) {
      return String(a.division).localeCompare(String(b.division), "nl");
    }

    return String(a.displayName).localeCompare(String(b.displayName), "nl", {
      sensitivity: "base",
    });
  });

  return teams;
}

function validateTeams(teams) {
  if (teams.length !== 36) {
    throw new Error(
      `Er zijn ${teams.length} teams gevonden. Verwacht: 36 teams.`
    );
  }

  const teamsA = teams.filter((team) => team.division === "A");
  const teamsB = teams.filter((team) => team.division === "B");

  if (teamsA.length !== 18 || teamsB.length !== 18) {
    throw new Error(
      `Ongeldige verdeling. A=${teamsA.length}, B=${teamsB.length}. Verwacht: A=18 en B=18.`
    );
  }

  const missingDivision = teams.filter((team) => !team.division);

  if (missingDivision.length > 0) {
    throw new Error(
      `Teams zonder division gevonden: ${missingDivision
        .map((team) => team.displayName)
        .join(", ")}`
    );
  }
}

function buildStandingRow(team) {
  return {
    seasonId: SEASON_ID,

    teamId: team.teamId,
    teamName: team.displayName,
    name: team.displayName,
    displayName: team.displayName,

    division: team.division,
    divisionLabel: team.divisionLabel,
    logoAsset: team.logoAsset,

    played: 0,
    won: 0,
    drawn: 0,
    lost: 0,

    goalsFor: 0,
    goalsAgainst: 0,
    goalDifference: 0,

    points: 0,

    // Alternatieve veldnamen voor compatibiliteit met bestaande schermen.
    gespeeld: 0,
    gewonnen: 0,
    gelijk: 0,
    verloren: 0,
    doelpuntenVoor: 0,
    doelpuntenTegen: 0,
    doelsaldo: 0,
    punten: 0,

    rank: null,
    previousRank: null,

    isActive: true,
    isFinal: false,
    source: "init_standings_2026_2027.js",
    structureVersion: 1,

    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function main() {
  console.log(`Initialiseren standen seizoen ${SEASON_ID}`);
  console.log(`Firebase project: ${PROJECT_ID}`);
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  await assertSeasonIsReady();

  const teamsCollectionRef = db
    .collection("seasons")
    .doc(SEASON_ID)
    .collection("teams");

  const standingsCollectionRef = db
    .collection("seasons")
    .doc(SEASON_ID)
    .collection("standings");

  const teamsCount = await countCollection(teamsCollectionRef);
  const standingsCount = await countCollection(standingsCollectionRef);

  console.log("Huidige staat:");
  console.table({
    [`seasons/${SEASON_ID}/teams`]: teamsCount,
    [`seasons/${SEASON_ID}/standings`]: standingsCount,
  });

  if (teamsCount !== 37) {
    throw new Error(
      `Teamscollectie bevat ${teamsCount} documenten. Verwacht: 37 documenten, dus 36 teams plus _meta.`
    );
  }

  if (standingsCount > 1) {
    throw new Error(
      `Standings bevat al ${standingsCount} documenten. Verwacht nu alleen _meta. Initialisatie afgebroken.`
    );
  }

  const teams = await getTeams();
  validateTeams(teams);

  const standingRows = teams.map(buildStandingRow);

  console.log("");
  console.log("Standings die aangemaakt worden:");
  console.table(
    standingRows.map((row) => ({
      teamId: row.teamId,
      teamName: row.teamName,
      division: row.division,
      played: row.played,
      points: row.points,
      goalDifference: row.goalDifference,
    }))
  );

  const countA = standingRows.filter((row) => row.division === "A").length;
  const countB = standingRows.filter((row) => row.division === "B").length;

  console.log("");
  console.log("Controle verdeling:");
  console.table({
    A: countA,
    B: countB,
    totaal: standingRows.length,
  });

  if (DRY_RUN) {
    console.log("");
    console.log("DRY_RUN = true, er is niets geschreven.");
    console.log("Controleer bovenstaande tabel. Zet daarna DRY_RUN op false.");
    return;
  }

  console.log("");
  console.log("Schrijven gestart...");

  const batch = db.batch();

  for (const standing of standingRows) {
    const standingRef = standingsCollectionRef.doc(standing.teamId);
    batch.set(standingRef, standing, { merge: false });
  }

  const metaRef = standingsCollectionRef.doc("_meta");

  batch.set(
    metaRef,
    {
      seasonId: SEASON_ID,
      type: "standings_meta",
      standingsInitialized: standingRows.length,
      teamsA: countA,
      teamsB: countB,
      note: "Beginstand seizoen 2026/2027 aangemaakt op basis van teamscollectie.",
      source: "init_standings_2026_2027.js",
      structureVersion: 1,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();

  const newStandingsCount = await countCollection(standingsCollectionRef);

  console.log("");
  console.log("Staat achteraf:");
  console.table({
    [`seasons/${SEASON_ID}/standings`]: newStandingsCount,
  });

  if (newStandingsCount !== 37) {
    throw new Error(
      `Na initialisatie bevat standings ${newStandingsCount} documenten. Verwacht: 37.`
    );
  }

  console.log("");
  console.log("Initialisatie standings klaar.");
}

main().catch((error) => {
  console.error("");
  console.error("Initialisatie standings mislukt:");
  console.error(error);
  process.exit(1);
});