/* eslint-disable no-console */

const { initializeApp, applicationDefault, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (!getApps().length) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

const SEASON_ID = "2026-2027";
const SEASON_LABEL = "2026/2027";

const EXPECTED = {
  teamsTotal: 36,
  teamsA: 18,
  teamsB: 18,
  standingsTotal: 36,
  standingsA: 18,
  standingsB: 18,
  periodStandingsTotal: 108,
  periodStandingsPerPeriod: 36,
  matches: 0,
  predictions: 0,
  poules: 0,
  settings: 0,
};

function safeData(doc) {
  if (!doc.exists) return null;
  return doc.data();
}

async function countCollection(path) {
  const snap = await db.collection(path).count().get();
  return snap.data().count || 0;
}

async function getDocs(path) {
  const snap = await db.collection(path).get();
  return snap.docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
  }));
}

function countByDivision(rows) {
  const result = {
    A: 0,
    B: 0,
    onbekend: 0,
    totaal: rows.length,
  };

  for (const row of rows) {
    const division = row.data.division;

    if (division === "A") {
      result.A += 1;
    } else if (division === "B") {
      result.B += 1;
    } else {
      result.onbekend += 1;
    }
  }

  return result;
}

function countByPeriod(rows) {
  const result = {
    periode_1: 0,
    periode_2: 0,
    periode_3: 0,
    onbekend: 0,
    totaal: rows.length,
  };

  for (const row of rows) {
    const period = Number(row.data.period);

    if (period === 1) {
      result.periode_1 += 1;
    } else if (period === 2) {
      result.periode_2 += 1;
    } else if (period === 3) {
      result.periode_3 += 1;
    } else {
      result.onbekend += 1;
    }
  }

  return result;
}

function compactTeamRows(rows) {
  return rows.map((row) => ({
    docId: row.id,
    teamId: row.data.teamId || row.id,
    name: row.data.name || row.data.teamName || "",
    division: row.data.division || "",
  }));
}

function compactStandingRows(rows) {
  return rows.map((row) => ({
    docId: row.id,
    teamId: row.data.teamId || row.id,
    teamName: row.data.teamName || row.data.name || "",
    division: row.data.division || "",
    played: row.data.played ?? 0,
    wins: row.data.wins ?? 0,
    draws: row.data.draws ?? 0,
    losses: row.data.losses ?? 0,
    goalsFor: row.data.goalsFor ?? 0,
    goalsAgainst: row.data.goalsAgainst ?? 0,
    goalDifference: row.data.goalDifference ?? 0,
    points: row.data.points ?? 0,
  }));
}

function compactPeriodStandingRows(rows) {
  return rows.map((row) => ({
    docId: row.id,
    teamId: row.data.teamId || "",
    teamName: row.data.teamName || "",
    division: row.data.division || "",
    period: row.data.period ?? "",
    played: row.data.played ?? 0,
    wins: row.data.wins ?? 0,
    draws: row.data.draws ?? 0,
    losses: row.data.losses ?? 0,
    goalsFor: row.data.goalsFor ?? 0,
    goalsAgainst: row.data.goalsAgainst ?? 0,
    goalDifference: row.data.goalDifference ?? 0,
    points: row.data.points ?? 0,
  }));
}

function validateEqual(errors, label, actual, expected) {
  if (actual !== expected) {
    errors.push(`${label}: verwacht ${expected}, gevonden ${actual}`);
  }
}

function validateZeroStandingValues(errors, standings) {
  for (const standing of standings) {
    const data = standing.data;

    const fields = [
      "played",
      "wins",
      "draws",
      "losses",
      "goalsFor",
      "goalsAgainst",
      "goalDifference",
      "points",
    ];

    for (const field of fields) {
      const value = data[field] ?? 0;

      if (value !== 0) {
        errors.push(
          `Standing ${standing.id} heeft ${field} = ${value}. Verwacht 0 bij nieuwe seizoenstart.`
        );
      }
    }
  }
}

function validateZeroPeriodStandingValues(errors, periodStandings) {
  for (const row of periodStandings) {
    const data = row.data;

    const fields = [
      "played",
      "wins",
      "draws",
      "losses",
      "goalsFor",
      "goalsAgainst",
      "goalDifference",
      "points",
    ];

    for (const field of fields) {
      const value = data[field] ?? 0;

      if (value !== 0) {
        errors.push(
          `Periodestanding ${row.id} heeft ${field} = ${value}. Verwacht 0 bij nieuwe seizoenstart.`
        );
      }
    }
  }
}

async function main() {
  const errors = [];
  const warnings = [];

  console.log(`Controle setup seizoen ${SEASON_ID}`);
  console.log("Firebase project: derde-divisie-app");
  console.log("");

  const seasonRef = db.collection("seasons").doc(SEASON_ID);
  const seasonDoc = await seasonRef.get();
  const seasonData = safeData(seasonDoc);

  console.log("1. Controle hoofddocument seizoen");
  console.log(`seasons/${SEASON_ID}: ${seasonDoc.exists ? "JA" : "NEE"}`);

  if (!seasonDoc.exists) {
    errors.push(`seasons/${SEASON_ID} ontbreekt`);
  } else {
    console.log("");
    console.log("Seizoen-document:");
    console.dir(seasonData, { depth: null });

    validateEqual(errors, "seasonId", seasonData.seasonId, SEASON_ID);
    validateEqual(errors, "seasonLabel", seasonData.seasonLabel, SEASON_LABEL);
    validateEqual(errors, "isCurrentSeason", seasonData.isCurrentSeason, true);
    validateEqual(errors, "isArchived", seasonData.isArchived, false);
    validateEqual(errors, "isFinal", seasonData.isFinal, false);

    if (seasonData.status !== "preparation") {
      warnings.push(
        `Seizoenstatus is ${seasonData.status}. Voor deze fase is preparation logisch.`
      );
    }

    if (!seasonData.predictionRules) {
      errors.push("predictionRules ontbreken op het seizoen-document");
    }

    if (!seasonData.divisions || !seasonData.divisions.A || !seasonData.divisions.B) {
      errors.push("divisions A en/of B ontbreken op het seizoen-document");
    } else {
      validateEqual(
        errors,
        "divisions.A.expectedTeams",
        seasonData.divisions.A.expectedTeams,
        18
      );
      validateEqual(
        errors,
        "divisions.B.expectedTeams",
        seasonData.divisions.B.expectedTeams,
        18
      );
      validateEqual(
        errors,
        "divisions.A.expectedMatches",
        seasonData.divisions.A.expectedMatches,
        306
      );
      validateEqual(
        errors,
        "divisions.B.expectedMatches",
        seasonData.divisions.B.expectedMatches,
        306
      );
    }
  }

  console.log("");
  console.log("2. Controle system/current_season");

  const currentSeasonDoc = await db.collection("system").doc("current_season").get();
  const currentSeasonData = safeData(currentSeasonDoc);

  console.log(`system/current_season: ${currentSeasonDoc.exists ? "JA" : "NEE"}`);

  if (!currentSeasonDoc.exists) {
    errors.push("system/current_season ontbreekt");
  } else {
    console.dir(currentSeasonData, { depth: null });

    validateEqual(errors, "system/current_season.seasonId", currentSeasonData.seasonId, SEASON_ID);
    validateEqual(
      errors,
      "system/current_season.seasonLabel",
      currentSeasonData.seasonLabel,
      SEASON_LABEL
    );

    if (currentSeasonData.status !== "preparation") {
      warnings.push(
        `system/current_season.status is ${currentSeasonData.status}. Voor deze fase is preparation logisch.`
      );
    }
  }

  console.log("");
  console.log("3. Controle top-level aantallen");

  const topLevelCounts = {
    seasons: await countCollection("seasons"),
    matches: await countCollection("matches"),
    standen: await countCollection("standen"),
    poules: await countCollection("poules"),
    voorspellingen: await countCollection("voorspellingen"),
    season_archives: await countCollection("season_archives"),
    standings_archive: await countCollection("standings_archive"),
    users: await countCollection("users"),
    usernames: await countCollection("usernames"),
    x_posts: await countCollection("x_posts"),
  };

  console.table(topLevelCounts);

  if (topLevelCounts.matches !== 0) {
    warnings.push(
      `Top-level matches bevat ${topLevelCounts.matches} documenten. Controleer of oude live data echt bewust is verwijderd.`
    );
  }

  if (topLevelCounts.standen !== 0) {
    warnings.push(
      `Top-level standen bevat ${topLevelCounts.standen} documenten. Controleer of oude live data echt bewust is verwijderd.`
    );
  }

  if (topLevelCounts.voorspellingen !== 0) {
    warnings.push(
      `Top-level voorspellingen bevat ${topLevelCounts.voorspellingen} documenten. Controleer of oude live data echt bewust is verwijderd.`
    );
  }

  console.log("");
  console.log(`4. Controle subcollecties onder seasons/${SEASON_ID}`);

  const basePath = `seasons/${SEASON_ID}`;

  const subCounts = {
    teams: await countCollection(`${basePath}/teams`),
    matches: await countCollection(`${basePath}/matches`),
    standings: await countCollection(`${basePath}/standings`),
    periodStandings: await countCollection(`${basePath}/periodStandings`),
    predictions: await countCollection(`${basePath}/predictions`),
    poules: await countCollection(`${basePath}/poules`),
    settings: await countCollection(`${basePath}/settings`),
  };

  console.table(subCounts);

  validateEqual(errors, "teams", subCounts.teams, EXPECTED.teamsTotal);
  validateEqual(errors, "standings", subCounts.standings, EXPECTED.standingsTotal);
  validateEqual(
    errors,
    "periodStandings",
    subCounts.periodStandings,
    EXPECTED.periodStandingsTotal
  );

  validateEqual(errors, "matches", subCounts.matches, EXPECTED.matches);
  validateEqual(errors, "predictions", subCounts.predictions, EXPECTED.predictions);
  validateEqual(errors, "poules", subCounts.poules, EXPECTED.poules);
  validateEqual(errors, "settings", subCounts.settings, EXPECTED.settings);

  console.log("");
  console.log("5. Controle teams");

  const teams = await getDocs(`${basePath}/teams`);
  teams.sort((a, b) => {
    const divisionCompare = String(a.data.division || "").localeCompare(String(b.data.division || ""));
    if (divisionCompare !== 0) return divisionCompare;

    return String(a.data.name || "").localeCompare(String(b.data.name || ""));
  });

  console.table(compactTeamRows(teams));

  const teamDivisionCounts = countByDivision(teams);

  console.log("Verdeling teams:");
  console.table(teamDivisionCounts);

  validateEqual(errors, "teams A", teamDivisionCounts.A, EXPECTED.teamsA);
  validateEqual(errors, "teams B", teamDivisionCounts.B, EXPECTED.teamsB);
  validateEqual(errors, "teams onbekend", teamDivisionCounts.onbekend, 0);

  const missingTeamIds = teams.filter((team) => !team.data.teamId);
  if (missingTeamIds.length > 0) {
    errors.push(
      `Er zijn ${missingTeamIds.length} teams zonder teamId: ${missingTeamIds
        .map((team) => team.id)
        .join(", ")}`
    );
  }

  const missingTeamNames = teams.filter((team) => !team.data.name);
  if (missingTeamNames.length > 0) {
    errors.push(
      `Er zijn ${missingTeamNames.length} teams zonder name: ${missingTeamNames
        .map((team) => team.id)
        .join(", ")}`
    );
  }

  console.log("");
  console.log("6. Controle standings");

  const standings = await getDocs(`${basePath}/standings`);
  standings.sort((a, b) => {
    const divisionCompare = String(a.data.division || "").localeCompare(String(b.data.division || ""));
    if (divisionCompare !== 0) return divisionCompare;

    return String(a.data.teamName || "").localeCompare(String(b.data.teamName || ""));
  });

  console.table(compactStandingRows(standings));

  const standingDivisionCounts = countByDivision(standings);

  console.log("Verdeling standings:");
  console.table(standingDivisionCounts);

  validateEqual(errors, "standings A", standingDivisionCounts.A, EXPECTED.standingsA);
  validateEqual(errors, "standings B", standingDivisionCounts.B, EXPECTED.standingsB);
  validateEqual(errors, "standings onbekend", standingDivisionCounts.onbekend, 0);

  validateZeroStandingValues(errors, standings);

  const teamIds = new Set(teams.map((team) => team.data.teamId || team.id));
  const standingTeamIds = new Set(standings.map((standing) => standing.data.teamId || standing.id));

  for (const teamId of teamIds) {
    if (!standingTeamIds.has(teamId)) {
      errors.push(`Team ${teamId} heeft geen standing-document`);
    }
  }

  for (const standingTeamId of standingTeamIds) {
    if (!teamIds.has(standingTeamId)) {
      errors.push(`Standing ${standingTeamId} heeft geen bijbehorend team-document`);
    }
  }

  console.log("");
  console.log("7. Controle periodStandings");

  const periodStandings = await getDocs(`${basePath}/periodStandings`);
  periodStandings.sort((a, b) => {
    const periodCompare = Number(a.data.period || 0) - Number(b.data.period || 0);
    if (periodCompare !== 0) return periodCompare;

    const divisionCompare = String(a.data.division || "").localeCompare(String(b.data.division || ""));
    if (divisionCompare !== 0) return divisionCompare;

    return String(a.data.teamName || "").localeCompare(String(b.data.teamName || ""));
  });

  console.table(compactPeriodStandingRows(periodStandings));

  const periodCounts = countByPeriod(periodStandings);

  console.log("Verdeling periodestanden:");
  console.table(periodCounts);

  validateEqual(
    errors,
    "periodStandings totaal",
    periodCounts.totaal,
    EXPECTED.periodStandingsTotal
  );
  validateEqual(
    errors,
    "periodStandings periode 1",
    periodCounts.periode_1,
    EXPECTED.periodStandingsPerPeriod
  );
  validateEqual(
    errors,
    "periodStandings periode 2",
    periodCounts.periode_2,
    EXPECTED.periodStandingsPerPeriod
  );
  validateEqual(
    errors,
    "periodStandings periode 3",
    periodCounts.periode_3,
    EXPECTED.periodStandingsPerPeriod
  );
  validateEqual(errors, "periodStandings onbekend", periodCounts.onbekend, 0);

  validateZeroPeriodStandingValues(errors, periodStandings);

  for (const teamId of teamIds) {
    for (const period of [1, 2, 3]) {
      const expectedDocId = `p${period}_${teamId}`;

      const exists = periodStandings.some((row) => row.id === expectedDocId);

      if (!exists) {
        errors.push(`Periodestanding ${expectedDocId} ontbreekt`);
      }
    }
  }

  console.log("");
  console.log("8. Controle archief 2025-2026");

  const archiveDoc = await db.collection("season_archives").doc("2025-2026").get();

  console.log(`season_archives/2025-2026: ${archiveDoc.exists ? "JA" : "NEE"}`);

  if (!archiveDoc.exists) {
    warnings.push("season_archives/2025-2026 ontbreekt. Controleer of het oude seizoen echt is gearchiveerd.");
  }

  console.log("");
  console.log("9. Samenvatting");
  console.log("");

  if (errors.length === 0) {
    console.log("✅ Geen fouten gevonden.");
  } else {
    console.log("❌ Fouten:");
    for (const error of errors) {
      console.log(`• ${error}`);
    }
  }

  console.log("");

  if (warnings.length === 0) {
    console.log("✅ Geen waarschuwingen gevonden.");
  } else {
    console.log("⚠️ Waarschuwingen:");
    for (const warning of warnings) {
      console.log(`• ${warning}`);
    }
  }

  console.log("");

  if (errors.length === 0 && warnings.length === 0) {
    console.log("Conclusie: setup seizoen 2026/2027 is volledig goed voor deze fase.");
  } else if (errors.length === 0) {
    console.log("Conclusie: setup seizoen 2026/2027 is bruikbaar, maar controleer de waarschuwingen.");
  } else {
    console.log("Conclusie: setup seizoen 2026/2027 is nog niet veilig. Los eerst de fouten op.");
    process.exitCode = 1;
  }

  console.log("");
  console.log("Controle klaar.");
}

main().catch((error) => {
  console.error("Controle mislukt:");
  console.error(error);
  process.exitCode = 1;
});