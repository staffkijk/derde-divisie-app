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

// Eerst draaien met true.
// Als de tabel klopt, daarna op false zetten.
const DRY_RUN = false;

const PERIODS = [
  {
    period: 1,
    label: "Periode 1",
  },
  {
    period: 2,
    label: "Periode 2",
  },
  {
    period: 3,
    label: "Periode 3",
  },
];

function createPeriodStandingDocId(teamId, period) {
  return `p${period}_${teamId}`;
}

async function countCollection(path) {
  const snap = await db.collection(path).count().get();
  return snap.data().count || 0;
}

async function getTeams() {
  const snap = await db
    .collection("seasons")
    .doc(SEASON_ID)
    .collection("teams")
    .get();

  return snap.docs
    .map((doc) => {
      const data = doc.data();

      return {
        docId: doc.id,
        teamId: data.teamId || doc.id,
        teamName: data.teamName || data.name || "",
        name: data.name || data.teamName || "",
        division: data.division || "",
      };
    })
    .sort((a, b) => {
      const divisionCompare = String(a.division).localeCompare(String(b.division));
      if (divisionCompare !== 0) return divisionCompare;

      return String(a.name || a.teamName).localeCompare(String(b.name || b.teamName));
    });
}

function validateTeams(teams) {
  const errors = [];

  if (teams.length !== 36) {
    errors.push(`Er zijn ${teams.length} teams gevonden. Verwacht: 36.`);
  }

  const divisionCounts = teams.reduce(
    (acc, team) => {
      if (team.division === "A") acc.A += 1;
      else if (team.division === "B") acc.B += 1;
      else acc.onbekend += 1;

      acc.totaal += 1;
      return acc;
    },
    { A: 0, B: 0, onbekend: 0, totaal: 0 }
  );

  if (divisionCounts.A !== 18) {
    errors.push(`Divisie A bevat ${divisionCounts.A} teams. Verwacht: 18.`);
  }

  if (divisionCounts.B !== 18) {
    errors.push(`Divisie B bevat ${divisionCounts.B} teams. Verwacht: 18.`);
  }

  if (divisionCounts.onbekend !== 0) {
    errors.push(`Er zijn ${divisionCounts.onbekend} teams zonder geldige divisie.`);
  }

  const invalidTeams = teams.filter((team) => {
    return !team.teamId || !team.name || !team.division;
  });

  if (invalidTeams.length > 0) {
    errors.push(
      `Er zijn teams met ontbrekende velden: ${invalidTeams
        .map((team) => team.docId)
        .join(", ")}`
    );
  }

  const teamIds = teams.map((team) => team.teamId);
  const duplicateTeamIds = teamIds.filter(
    (teamId, index) => teamId && teamIds.indexOf(teamId) !== index
  );

  if (duplicateTeamIds.length > 0) {
    errors.push(`Dubbele teamIds gevonden: ${[...new Set(duplicateTeamIds)].join(", ")}`);
  }

  return {
    errors,
    divisionCounts,
  };
}

async function main() {
  console.log(`Initialiseren periodestanden seizoen ${SEASON_ID}`);
  console.log("Firebase project: derde-divisie-app");
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  const teamsPath = `seasons/${SEASON_ID}/teams`;
  const periodStandingsPath = `seasons/${SEASON_ID}/periodStandings`;

  const currentCounts = {
    teams: await countCollection(teamsPath),
    periodStandings: await countCollection(periodStandingsPath),
  };

  console.log("Huidige staat:");
  console.table(currentCounts);
  console.log("");

  const teams = await getTeams();
  const validation = validateTeams(teams);

  console.log("Controle teams:");
  console.table(
    teams.map((team) => ({
      docId: team.docId,
      teamId: team.teamId,
      name: team.name,
      division: team.division,
    }))
  );

  console.log("Verdeling teams:");
  console.table(validation.divisionCounts);
  console.log("");

  if (validation.errors.length > 0) {
    console.log("❌ Initialisatie afgebroken. Fouten:");
    for (const error of validation.errors) {
      console.log(`- ${error}`);
    }
    process.exit(1);
  }

  const periodStandingRows = [];

  for (const team of teams) {
    for (const periodInfo of PERIODS) {
      const docId = createPeriodStandingDocId(team.teamId, periodInfo.period);

      periodStandingRows.push({
        docId,
        teamId: team.teamId,
        teamName: team.name,
        division: team.division,
        period: periodInfo.period,
        periodLabel: periodInfo.label,
        played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        goalDifference: 0,
        points: 0,
      });
    }
  }

  console.log("Periodestanden die aangemaakt worden:");
  console.table(
    periodStandingRows.map((row) => ({
      docId: row.docId,
      teamName: row.teamName,
      division: row.division,
      period: row.period,
      played: row.played,
      points: row.points,
      goalDifference: row.goalDifference,
    }))
  );

  const expectedTotal = 36 * PERIODS.length;

  const periodCounts = periodStandingRows.reduce(
    (acc, row) => {
      const key = `periode_${row.period}`;
      acc[key] = (acc[key] || 0) + 1;
      acc.totaal += 1;
      return acc;
    },
    { totaal: 0 }
  );

  console.log("");
  console.log("Controle aantallen:");
  console.table({
    expectedTotal,
    actualTotal: periodStandingRows.length,
    ...periodCounts,
  });

  if (periodStandingRows.length !== expectedTotal) {
    console.log("");
    console.log(
      `❌ Initialisatie afgebroken. Verwacht ${expectedTotal} periodestanden, maar script maakte er ${periodStandingRows.length}.`
    );
    process.exit(1);
  }

  if (DRY_RUN) {
    console.log("");
    console.log("DRY_RUN = false, er is niets geschreven.");
    console.log("Controleer bovenstaande tabel. Zet daarna DRY_RUN op false.");
    return;
  }

  console.log("");
  console.log("Schrijven gestart...");

  const batchSize = 400;
  let batch = db.batch();
  let operationCount = 0;
  let totalWritten = 0;

  for (const row of periodStandingRows) {
    const ref = db
      .collection("seasons")
      .doc(SEASON_ID)
      .collection("periodStandings")
      .doc(row.docId);

    batch.set(
      ref,
      {
        seasonId: SEASON_ID,
        teamId: row.teamId,
        teamName: row.teamName,
        division: row.division,
        period: row.period,
        periodLabel: row.periodLabel,
        played: row.played,
        wins: row.wins,
        draws: row.draws,
        losses: row.losses,
        goalsFor: row.goalsFor,
        goalsAgainst: row.goalsAgainst,
        goalDifference: row.goalDifference,
        points: row.points,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    operationCount += 1;
    totalWritten += 1;

    if (operationCount >= batchSize) {
      await batch.commit();
      batch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }

  console.log(`Geschreven periodestanden: ${totalWritten}`);

  const afterCounts = {
    periodStandings: await countCollection(periodStandingsPath),
  };

  console.log("");
  console.log("Staat achteraf:");
  console.table(afterCounts);

  if (afterCounts.periodStandings === expectedTotal) {
    console.log("");
    console.log("Initialisatie periodestanden klaar.");
  } else {
    console.log("");
    console.log(
      `Let op: verwacht ${expectedTotal} periodestanden, maar Firestore bevat nu ${afterCounts.periodStandings}.`
    );
  }
}

main().catch((error) => {
  console.error("Initialisatie periodestanden mislukt:");
  console.error(error);
  process.exit(1);
});