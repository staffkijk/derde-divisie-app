/* eslint-disable no-console */

const { initializeApp, getApps, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { clubIdForName } = require("./club_ids");

const PROJECT_ID = "derde-divisie-app";
const SEASON_ID = "2026-2027";
const DRY_RUN = false;

/**
 * BELANGRIJK
 *
 * De officiële indeling A/B is nog niet definitief verwerkt.
 * Daarom importeren we de 36 teams voorlopig alfabetisch verdeeld:
 *
 * eerste 18 teams  -> Derde Divisie A
 * laatste 18 teams -> Derde Divisie B
 *
 * Zodra de definitieve indeling bekend is, passen we alleen het veld division aan.
 */

const TEAMS = [
  "ACV",
  "ADO '20",
  "Blauw Geel '38",
  "DVS '33 Ermelo",
  "EVV Echt",
  "Excelsior '31",
  "Excelsior Maassluis",
  "FC Lisse",
  "FC Rijnvogels",
  "Harkemase Boys",
  "HVV Hollandia",
  "VPV Purmersteijn",
  "RBC",
  "RKSV Groene Ster",
  "SC Genemuiden",
  "Sportlust '46",
  "SV Poortugaal",
  "SV TEC",
  "SVZW",
  "TOGB",
  "UDI '19",
  "USV Hercules",
  "VV Achilles Veen",
  "VV Dongen",
  "VV DOVO",
  "VV Eemdijk",
  "VV Gemert",
  "GOES",
  "VV Hoogeveen",
  "VV Noordwijk",
  "VV Scherpenzeel",
  "VV Sparta Nijkerk",
  "VV Staphorst",
  "VV UNA",
  "VV Zwaluwen",
  "VVSB",
];

if (!getApps().length) {
  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });
}

const db = getFirestore();

function slugifyTeamName(name) {
  return name
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/['’]/g, "")
    .replace(/&/g, "en")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function logoAssetForTeam(name) {
  const compact = name
    .replace(/['’]/g, "")
    .replace(/&/g, "en")
    .replace(/[^A-Za-z0-9]/g, "");

  return `assets/images/logo_${compact}.png`;
}

function buildTeamRows() {
  const cleanedTeams = TEAMS
    .map((name) => String(name || "").trim())
    .filter(Boolean);

  const uniqueNames = new Set(cleanedTeams);

  if (cleanedTeams.length !== uniqueNames.size) {
    throw new Error("De TEAMS-lijst bevat dubbele teamnamen.");
  }

  if (cleanedTeams.length !== 36) {
    throw new Error(
      `De TEAMS-lijst bevat ${cleanedTeams.length} teams. Verwacht: 36 teams.`
    );
  }

  const sortedTeams = [...cleanedTeams].sort((a, b) =>
    a.localeCompare(b, "nl", { sensitivity: "base" })
  );

  return sortedTeams.map((name, index) => {
    const division = index < 18 ? "A" : "B";
    const teamId = slugifyTeamName(name);

    return {
      teamId,
      clubId: clubIdForName(name),
      name,
      displayName: name,
      searchName: name.toLowerCase(),
      division,
      divisionLabel: `Derde Divisie ${division}`,
      seasonId: SEASON_ID,
      sortIndex: index + 1,
      logoAsset: logoAssetForTeam(name),
      isActive: true,
      source: "import_teams_2026_2027.js",
      importStatus: "provisional",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
  });
}

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

async function main() {
  console.log(`Import teams seizoen ${SEASON_ID}`);
  console.log(`Firebase project: ${PROJECT_ID}`);
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  await assertSeasonIsReady();

  const teamRows = buildTeamRows();

  const teamsCollectionRef = db
    .collection("seasons")
    .doc(SEASON_ID)
    .collection("teams");

  const currentTeamsCount = await countCollection(teamsCollectionRef);

  console.log("Huidige staat:");
  console.log(`seasons/${SEASON_ID}/teams documenten: ${currentTeamsCount}`);
  console.log("");

  if (currentTeamsCount > 1) {
    throw new Error(
      `Er staan al ${currentTeamsCount} documenten in teams. Verwacht nu alleen _meta. Import afgebroken.`
    );
  }

  console.log("Teams die geïmporteerd worden:");
  console.table(
    teamRows.map((team) => ({
      teamId: team.teamId,
      name: team.name,
      division: team.division,
      logoAsset: team.logoAsset,
    }))
  );

  const countA = teamRows.filter((team) => team.division === "A").length;
  const countB = teamRows.filter((team) => team.division === "B").length;

  console.log("");
  console.log("Controle verdeling:");
  console.table({
    A: countA,
    B: countB,
    totaal: teamRows.length,
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

  for (const team of teamRows) {
    const teamRef = teamsCollectionRef.doc(team.teamId);
    batch.set(teamRef, team, { merge: false });
  }

  const metaRef = teamsCollectionRef.doc("_meta");
  batch.set(
    metaRef,
    {
      seasonId: SEASON_ID,
      type: "teams_meta",
      teamsImported: teamRows.length,
      teamsA: countA,
      teamsB: countB,
      importStatus: "provisional",
      note: "Teams voorlopig alfabetisch verdeeld. Definitieve indeling later verwerken via update-script.",
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();

  const newTeamsCount = await countCollection(teamsCollectionRef);

  console.log("");
  console.log("Staat achteraf:");
  console.log(`seasons/${SEASON_ID}/teams documenten: ${newTeamsCount}`);
  console.log("");
  console.log("Import teams klaar.");
}

main().catch((error) => {
  console.error("");
  console.error("Import mislukt:");
  console.error(error);
  process.exit(1);
});
