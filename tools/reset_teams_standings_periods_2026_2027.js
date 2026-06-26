/* eslint-disable no-console */

const { initializeApp, applicationDefault, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const SEASON_ID = "2026-2027";
const DRY_RUN = false;

if (!getApps().length) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

/**
 * Vul hier de definitieve 36 teams in.
 *
 * Let op:
 * 1. teamId moet uniek zijn
 * 2. division moet A of B zijn
 * 3. name is de officiële naam die de app moet tonen
 *
 * Voorbeeld:
 * { teamId: "goes", name: "GOES", division: "A" }
 */
const CORRECT_TEAMS = [
  { teamId: "acv", name: "ACV", division: "A" },
  { teamId: "ado_20", name: "ADO '20", division: "A" },
  { teamId: "blauw_geel_38", name: "Blauw Geel '38", division: "A" },
  { teamId: "dvs_33_ermelo", name: "DVS '33 Ermelo", division: "A" },
  { teamId: "evv_echt", name: "EVV Echt", division: "A" },
  { teamId: "excelsior_31", name: "Excelsior '31", division: "A" },
  { teamId: "excelsior_maassluis", name: "Excelsior Maassluis", division: "A" },
  { teamId: "fc_lisse", name: "FC Lisse", division: "A" },
  { teamId: "fc_rijnvogels", name: "FC Rijnvogels", division: "A" },
  { teamId: "goes", name: "GOES", division: "A" },
  { teamId: "harkemase_boys", name: "Harkemase Boys", division: "A" },
  { teamId: "hvv_hollandia", name: "HVV Hollandia", division: "A" },
  { teamId: "rbc", name: "RBC", division: "A" },
  { teamId: "rksv_groene_ster", name: "RKSV Groene Ster", division: "A" },
  { teamId: "sc_genemuiden", name: "SC Genemuiden", division: "A" },
  { teamId: "sportlust_46", name: "Sportlust '46", division: "A" },
  { teamId: "sv_poortugaal", name: "SV Poortugaal", division: "A" },
  { teamId: "sv_tec", name: "SV TEC", division: "A" },

  { teamId: "svzw", name: "SVZW", division: "B" },
  { teamId: "togb", name: "TOGB", division: "B" },
  { teamId: "udi_19", name: "UDI '19", division: "B" },
  { teamId: "usv_hercules", name: "USV Hercules", division: "B" },
  { teamId: "vpv_purmersteijn", name: "VPV Purmersteijn", division: "B" },
  { teamId: "vv_achilles_veen", name: "VV Achilles Veen", division: "B" },
  { teamId: "vv_dongen", name: "VV Dongen", division: "B" },
  { teamId: "vv_dovo", name: "VV DOVO", division: "B" },
  { teamId: "vv_eemdijk", name: "VV Eemdijk", division: "B" },
  { teamId: "vv_gemert", name: "VV Gemert", division: "B" },
  { teamId: "vv_hoogeveen", name: "VV Hoogeveen", division: "B" },
  { teamId: "vv_noordwijk", name: "VV Noordwijk", division: "B" },
  { teamId: "vv_scherpenzeel", name: "VV Scherpenzeel", division: "B" },
  { teamId: "vv_sparta_nijkerk", name: "VV Sparta Nijkerk", division: "B" },
  { teamId: "vv_staphorst", name: "VV Staphorst", division: "B" },
  { teamId: "vv_una", name: "VV UNA", division: "B" },
  { teamId: "vv_zwaluwen", name: "VV Zwaluwen", division: "B" },
  { teamId: "vvsb", name: "VVSB", division: "B" },
];

function validateTeams(teams) {
  if (!Array.isArray(teams) || teams.length !== 36) {
    throw new Error(`CORRECT_TEAMS moet exact 36 teams bevatten. Huidig aantal: ${teams.length}`);
  }

  const seen = new Set();
  const counts = { A: 0, B: 0 };

  for (const team of teams) {
    if (!team.teamId || typeof team.teamId !== "string") {
      throw new Error(`Ongeldige teamId: ${JSON.stringify(team)}`);
    }

    if (!team.name || typeof team.name !== "string") {
      throw new Error(`Ongeldige name: ${JSON.stringify(team)}`);
    }

    if (!["A", "B"].includes(team.division)) {
      throw new Error(`Ongeldige division bij ${team.teamId}: ${team.division}`);
    }

    if (seen.has(team.teamId)) {
      throw new Error(`Dubbele teamId gevonden: ${team.teamId}`);
    }

    seen.add(team.teamId);
    counts[team.division] += 1;
  }

  if (counts.A !== 18 || counts.B !== 18) {
    throw new Error(`Verdeling moet A=18 en B=18 zijn. Huidig: A=${counts.A}, B=${counts.B}`);
  }
}

function standingPayload(team) {
  return {
    teamId: team.teamId,
    teamName: team.name,
    name: team.name,
    division: team.division,

    played: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    goalsFor: 0,
    goalsAgainst: 0,
    goalDifference: 0,
    points: 0,

    gespeeld: 0,
    gewonnen: 0,
    gelijk: 0,
    verloren: 0,
    doelpuntenVoor: 0,
    doelpuntenTegen: 0,
    doelsaldo: 0,
    punten: 0,

    updatedAt: FieldValue.serverTimestamp(),
  };
}

function teamPayload(team) {
  return {
    teamId: team.teamId,
    name: team.name,
    teamName: team.name,
    division: team.division,
    active: true,
    seasonId: SEASON_ID,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function periodStandingPayload(team, period) {
  return {
    teamId: team.teamId,
    teamName: team.name,
    name: team.name,
    division: team.division,
    period,

    played: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    goalsFor: 0,
    goalsAgainst: 0,
    goalDifference: 0,
    points: 0,

    gespeeld: 0,
    gewonnen: 0,
    gelijk: 0,
    verloren: 0,
    doelpuntenVoor: 0,
    doelpuntenTegen: 0,
    doelsaldo: 0,
    punten: 0,

    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function getDocsMap(collectionRef) {
  const snap = await collectionRef.get();
  return snap.docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
  }));
}

async function deleteCollectionInBatches(collectionRef, label) {
  const snap = await collectionRef.get();

  if (snap.empty) {
    console.log(`${label}: geen documenten om te verwijderen.`);
    return;
  }

  console.log(`${label}: ${snap.size} documenten verwijderen.`);

  if (DRY_RUN) {
    return;
  }

  let batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    count += 1;

    if (count % 450 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }

  await batch.commit();
}

async function writeTeams(teamsRef) {
  console.log(`teams: ${CORRECT_TEAMS.length} documenten schrijven.`);

  if (DRY_RUN) {
    return;
  }

  let batch = db.batch();
  let count = 0;

  for (const team of CORRECT_TEAMS) {
    batch.set(teamsRef.doc(team.teamId), teamPayload(team), { merge: false });
    count += 1;

    if (count % 450 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }

  await batch.commit();
}

async function writeStandings(standingsRef) {
  console.log(`standings: ${CORRECT_TEAMS.length} documenten schrijven.`);

  if (DRY_RUN) {
    return;
  }

  let batch = db.batch();
  let count = 0;

  for (const team of CORRECT_TEAMS) {
    batch.set(standingsRef.doc(team.teamId), standingPayload(team), { merge: false });
    count += 1;

    if (count % 450 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }

  await batch.commit();
}

async function writePeriodStandings(periodStandingsRef) {
  const periods = [1, 2, 3];
  const total = CORRECT_TEAMS.length * periods.length;

  console.log(`periodStandings: ${total} documenten schrijven.`);

  if (DRY_RUN) {
    return;
  }

  let batch = db.batch();
  let count = 0;

  for (const period of periods) {
    for (const team of CORRECT_TEAMS) {
      const docId = `p${period}_${team.teamId}`;
      batch.set(periodStandingsRef.doc(docId), periodStandingPayload(team, period), { merge: false });
      count += 1;

      if (count % 450 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
  }

  await batch.commit();
}

function printTeamTable(title, docs) {
  console.log(`\n${title}`);

  const rows = docs.map((doc) => ({
    docId: doc.id,
    teamId: doc.data.teamId || "",
    name: doc.data.name || doc.data.teamName || "",
    division: doc.data.division || doc.data.divisie || "",
  }));

  console.table(rows);
}

function printCorrectTeams() {
  console.log("\nNieuwe CORRECT_TEAMS:");
  console.table(
    CORRECT_TEAMS.map((team) => ({
      teamId: team.teamId,
      name: team.name,
      division: team.division,
    }))
  );
}

async function main() {
  validateTeams(CORRECT_TEAMS);

  const seasonRef = db.collection("seasons").doc(SEASON_ID);
  const teamsRef = seasonRef.collection("teams");
  const standingsRef = seasonRef.collection("standings");
  const periodStandingsRef = seasonRef.collection("periodStandings");

  console.log(`Reset teams, standings en periodStandings voor seizoen ${SEASON_ID}`);
  console.log(`DRY_RUN = ${DRY_RUN}`);

  const seasonSnap = await seasonRef.get();

  if (!seasonSnap.exists) {
    throw new Error(`Seizoendocument bestaat niet: seasons/${SEASON_ID}`);
  }

  const currentTeams = await getDocsMap(teamsRef);
  const currentStandings = await getDocsMap(standingsRef);
  const currentPeriodStandings = await getDocsMap(periodStandingsRef);

  printTeamTable("Huidige teams:", currentTeams);
  printTeamTable("Huidige standings:", currentStandings);
  console.log(`\nHuidige periodStandings: ${currentPeriodStandings.length} documenten`);

  printCorrectTeams();

  console.log("\nGeplande actie:");
  console.log(`teams verwijderen: ${currentTeams.length}`);
  console.log(`standings verwijderen: ${currentStandings.length}`);
  console.log(`periodStandings verwijderen: ${currentPeriodStandings.length}`);
  console.log(`teams schrijven: ${CORRECT_TEAMS.length}`);
  console.log(`standings schrijven: ${CORRECT_TEAMS.length}`);
  console.log(`periodStandings schrijven: ${CORRECT_TEAMS.length * 3}`);

  if (DRY_RUN) {
    console.log("\nDRY_RUN = true, er is niets geschreven of verwijderd.");
    console.log("Controleer de tabellen hierboven. Zet daarna DRY_RUN op false als dit exact klopt.");
    return;
  }

  await deleteCollectionInBatches(periodStandingsRef, "periodStandings");
  await deleteCollectionInBatches(standingsRef, "standings");
  await deleteCollectionInBatches(teamsRef, "teams");

  await writeTeams(teamsRef);
  await writeStandings(standingsRef);
  await writePeriodStandings(periodStandingsRef);

  await seasonRef.set(
    {
      updatedAt: FieldValue.serverTimestamp(),
      teamsResetAt: FieldValue.serverTimestamp(),
      teamsResetSource: "reset_teams_standings_periods_2026_2027.js",
    },
    { merge: true }
  );

  console.log("\nReset afgerond.");
}

main().catch((error) => {
  console.error("\nReset mislukt:");
  console.error(error);
  process.exitCode = 1;
});