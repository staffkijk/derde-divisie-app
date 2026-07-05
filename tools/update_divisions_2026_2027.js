/* eslint-disable no-console */

const {
  initializeApp,
  getApps,
  applicationDefault,
} = require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

const DRY_RUN = false;

const SEASON_ID = "2026-2027";
const SEASON_LABEL = "2026/2027";

const SEASON_REF = db.collection("seasons").doc(SEASON_ID);

const DIVISION_A_TEAMS = [
  "ACV",
  "ADO '20",
  "DOVO",
  "DVS'33 Ermelo",
  "Eemdijk",
  "Excelsior'31",
  "Harkemase Boys",
  "Hercules",
  "Hollandia",
  "Hoogeveen",
  "SC Genemuiden",
  "Sparta Nijkerk",
  "Sportlust'46",
  "Staphorst",
  "SVZW",
  "TEC",
  "Purmersteijn",
  "Scherpenzeel",
];

const DIVISION_B_TEAMS = [
  "Achilles Veen",
  "Blauw Geel'38/Jumbo",
  "Dongen",
  "EVV Echt",
  "Excelsior Maassluis",
  "FC Lisse",
  "Gemert",
  "Goes",
  "Groene Ster",
  "Noordwijk",
  "RBC",
  "Rijnvogels",
  "sv Poortugaal",
  "TOGB",
  "UDI'19",
  "UNA",
  "VVSB",
  "Zwaluwen",
];

const EXISTING_NAME_TO_OFFICIAL_NAME = {
  "blauw geel 38": "Blauw Geel'38/Jumbo",
  "blauw geel 38 jumbo": "Blauw Geel'38/Jumbo",

  "fc rijnvogels": "Rijnvogels",
  "rijnvogels": "Rijnvogels",

  "hvv hollandia": "Hollandia",
  "hollandia": "Hollandia",

  "rksv groene ster": "Groene Ster",
  "groene ster": "Groene Ster",

  "sv tec": "TEC",
  "tec": "TEC",

  "usv hercules": "Hercules",
  "hercules": "Hercules",

  "vpv purmersteijn": "Purmersteijn",
  "purmersteijn": "Purmersteijn",

  "vv achilles veen": "Achilles Veen",
  "achilles veen": "Achilles Veen",

  "vv dongen": "Dongen",
  "dongen": "Dongen",

  "vv dovo": "DOVO",
  "dovo": "DOVO",

  "vv eemdijk": "Eemdijk",
  "eemdijk": "Eemdijk",

  "vv gemert": "Gemert",
  "gemert": "Gemert",

  "vv hoogeveen": "Hoogeveen",
  "hoogeveen": "Hoogeveen",

  "vv noordwijk": "Noordwijk",
  "noordwijk": "Noordwijk",

  "vv scherpenzeel": "Scherpenzeel",
  "scherpenzeel": "Scherpenzeel",

  "vv sparta nijkerk": "Sparta Nijkerk",
  "sparta nijkerk": "Sparta Nijkerk",

  "vv staphorst": "Staphorst",
  "staphorst": "Staphorst",

  "vv una": "UNA",
  "una": "UNA",

  "vv zwaluwen": "Zwaluwen",
  "zwaluwen": "Zwaluwen",

  "goes": "Goes",
  "vv goes": "Goes",

  "sv poortugaal": "sv Poortugaal",
  "poortugaal": "sv Poortugaal",
};

function normalizeForMatch(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[’`]/g, "'")
    .replace(/['./_-]/g, " ")
    .replace(/\s+/g, " ");
}

function officialNameForMatch(value) {
  const key = normalizeForMatch(value);
  return EXISTING_NAME_TO_OFFICIAL_NAME[key] || String(value || "").trim();
}

function officialMatchKey(value) {
  return normalizeForMatch(officialNameForMatch(value));
}

function slugify(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[’`]/g, "")
    .replace(/'/g, "")
    .replace(/&/g, "en")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function logoKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[’`]/g, "")
    .replace(/'/g, "")
    .replace(/[^a-z0-9]/g, "");
}

function buildTeamDoc(teamName, division, sortOrder) {
  const slug = slugify(teamName);

  return {
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,

    name: teamName,
    displayName: teamName,
    searchName: normalizeForMatch(teamName),
    slug,
    logoKey: logoKey(teamName),

    division,
    divisionLabel: `Derde Divisie ${division}`,
    sortOrder,
    isActive: true,

    source: "KNVB competitieprogramma 2026/2027",
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function buildStandingDoc(teamName, division, sortOrder) {
  const slug = slugify(teamName);

  return {
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,

    teamName,
    displayName: teamName,
    searchName: normalizeForMatch(teamName),
    teamSlug: slug,
    logoKey: logoKey(teamName),

    division,
    divisionLabel: `Derde Divisie ${division}`,
    sortOrder,

    played: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    goalsFor: 0,
    goalsAgainst: 0,
    goalDifference: 0,
    points: 0,

    isActive: true,
    source: "update_divisions_2026_2027.js",
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function buildPeriodStandingDoc(teamName, division, period, sortOrder) {
  const slug = slugify(teamName);

  return {
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,

    teamName,
    displayName: teamName,
    searchName: normalizeForMatch(teamName),
    teamSlug: slug,
    logoKey: logoKey(teamName),

    division,
    divisionLabel: `Derde Divisie ${division}`,
    period,
    sortOrder,

    played: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    goalsFor: 0,
    goalsAgainst: 0,
    goalDifference: 0,
    points: 0,

    isActive: true,
    source: "update_divisions_2026_2027.js",
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function buildOfficialTeams() {
  const rows = [];

  DIVISION_A_TEAMS.forEach((teamName, index) => {
    rows.push({
      teamName,
      division: "A",
      sortOrder: index + 1,
    });
  });

  DIVISION_B_TEAMS.forEach((teamName, index) => {
    rows.push({
      teamName,
      division: "B",
      sortOrder: index + 1,
    });
  });

  return rows;
}

async function getExistingTeamDocs() {
  const snap = await SEASON_REF.collection("teams").get();
  const docs = [];

  snap.forEach((doc) => {
    if (doc.id === "_meta") return;

    const data = doc.data() || {};
    const candidateName =
      data.displayName ||
      data.name ||
      data.teamName ||
      data.searchName ||
      doc.id;

    docs.push({
      id: doc.id,
      ref: doc.ref,
      data,
      originalName: candidateName,
      matchKey: officialMatchKey(candidateName),
    });
  });

  return docs;
}

function validateOfficialTeams(officialTeams) {
  const divisionA = officialTeams.filter((row) => row.division === "A");
  const divisionB = officialTeams.filter((row) => row.division === "B");

  if (divisionA.length !== 18) {
    throw new Error(`Derde Divisie A heeft ${divisionA.length} teams in plaats van 18.`);
  }

  if (divisionB.length !== 18) {
    throw new Error(`Derde Divisie B heeft ${divisionB.length} teams in plaats van 18.`);
  }

  const keys = new Set();

  for (const row of officialTeams) {
    const key = officialMatchKey(row.teamName);

    if (keys.has(key)) {
      throw new Error(`Dubbele teamnaam gevonden: ${row.teamName}`);
    }

    keys.add(key);
  }
}

async function updateDivisions() {
  const officialTeams = buildOfficialTeams();
  validateOfficialTeams(officialTeams);

  const existingDocs = await getExistingTeamDocs();
  const existingByMatchKey = new Map();

  for (const item of existingDocs) {
    existingByMatchKey.set(item.matchKey, item);
  }

  const batch = db.batch();
  const officialKeys = new Set();
  const matchedExistingDocs = [];

  for (const row of officialTeams) {
    const displayName = row.teamName;
    const matchKey = officialMatchKey(displayName);
    const slug = slugify(displayName);

    officialKeys.add(matchKey);

    const existing = existingByMatchKey.get(matchKey);
    const teamRef = existing
      ? existing.ref
      : SEASON_REF.collection("teams").doc(slug);

    if (existing) {
      matchedExistingDocs.push({
        id: existing.id,
        oldName: existing.originalName,
        newName: displayName,
      });
    }

    batch.set(
      teamRef,
      buildTeamDoc(displayName, row.division, row.sortOrder),
      { merge: true }
    );

    batch.set(
      SEASON_REF.collection("standings").doc(slug),
      buildStandingDoc(displayName, row.division, row.sortOrder),
      { merge: true }
    );

    for (const period of [1, 2, 3]) {
      batch.set(
        SEASON_REF.collection("periodStandings").doc(`${slug}_p${period}`),
        buildPeriodStandingDoc(displayName, row.division, period, row.sortOrder),
        { merge: true }
      );
    }
  }

  batch.set(
    SEASON_REF,
    {
      status: "scheduled",
      isCurrentSeason: true,
      isArchived: false,
      isFinal: false,
      updatedAt: FieldValue.serverTimestamp(),
      teamsUpdatedAt: FieldValue.serverTimestamp(),
      source: "KNVB competitieprogramma 2026/2027",
      divisions: {
        A: {
          label: "Derde Divisie A",
          expectedTeams: 18,
          expectedMatches: 306,
          teams: DIVISION_A_TEAMS,
        },
        B: {
          label: "Derde Divisie B",
          expectedTeams: 18,
          expectedMatches: 306,
          teams: DIVISION_B_TEAMS,
        },
      },
    },
    { merge: true }
  );

  batch.set(
    db.collection("maintenance").doc("update_divisions_2026_2027"),
    {
      type: "update_divisions_2026_2027",
      dryRun: false,
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      updatedAt: FieldValue.serverTimestamp(),
      officialTeamCount: officialTeams.length,
      divisionACount: DIVISION_A_TEAMS.length,
      divisionBCount: DIVISION_B_TEAMS.length,
      source: "KNVB competitieprogramma 2026/2027",
      note: "Definitieve indeling Derde Divisie A en B 2026/2027 verwerkt.",
    },
    { merge: true }
  );

  const staleExistingTeams = existingDocs.filter(
    (item) => !officialKeys.has(item.matchKey)
  );

  return {
    officialTeams,
    existingDocs,
    matchedExistingDocs,
    staleExistingTeams,
    batch,
  };
}

function printPreview(result) {
  console.log("");
  console.log("Derde Divisie A:");
  DIVISION_A_TEAMS.forEach((teamName, index) => {
    console.log(`${String(index + 1).padStart(2, "0")}. ${teamName}`);
  });

  console.log("");
  console.log("Derde Divisie B:");
  DIVISION_B_TEAMS.forEach((teamName, index) => {
    console.log(`${String(index + 1).padStart(2, "0")}. ${teamName}`);
  });

  console.log("");
  console.log("Aantallen:");
  console.table({
    officialTeams: result.officialTeams.length,
    divisionA: DIVISION_A_TEAMS.length,
    divisionB: DIVISION_B_TEAMS.length,
    existingTeamDocs: result.existingDocs.length,
    matchedExistingDocs: result.matchedExistingDocs.length,
    staleExistingTeams: result.staleExistingTeams.length,
  });

  console.log("");
  console.log("Bestaande teamdocs die worden bijgewerkt:");
  result.matchedExistingDocs.forEach((item) => {
    if (item.oldName !== item.newName) {
      console.log(`${item.id}: ${item.oldName} wordt ${item.newName}`);
    }
  });

  if (result.staleExistingTeams.length > 0) {
    console.log("");
    console.log("Let op: bestaande teamdocs die niet in de officiële indeling staan:");
    result.staleExistingTeams.forEach((item) => {
      const name =
        item.data.displayName ||
        item.data.name ||
        item.data.teamName ||
        item.id;

      console.log(`${item.id}: ${name}`);
    });

    console.log("");
    console.log("Deze worden niet verwijderd door dit script.");
  }
}

async function main() {
  console.log("");
  console.log("Update definitieve indeling seizoen 2026/2027");
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  const seasonSnap = await SEASON_REF.get();

  if (!seasonSnap.exists) {
    throw new Error(
      `seasons/${SEASON_ID} bestaat nog niet. Draai eerst setup_season_2026_2027.js.`
    );
  }

  const result = await updateDivisions();

  printPreview(result);

  if (DRY_RUN) {
    console.log("");
    console.log("DRY_RUN staat op true.");
    console.log("Er is niets geschreven.");
    console.log("");
    console.log("Als de preview klopt, zet dan bovenin:");
    console.log("const DRY_RUN = false;");
    console.log("");
    console.log("Daarna opnieuw uitvoeren:");
    console.log("node tools/update_divisions_2026_2027.js");
    return;
  }

  console.log("");
  console.log("Schrijven gestart...");

  await result.batch.commit();

  console.log("");
  console.log("Indeling 2026/2027 bijgewerkt.");
  console.log("");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("");
    console.error("Update indeling 2026/2027 mislukt:");
    console.error(error);
    process.exit(1);
  });