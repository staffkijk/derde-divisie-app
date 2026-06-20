const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const XLSX = require("xlsx");
const path = require("path");

const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const excelPath = path.join(__dirname, "Alle standen derde divisie.xlsx");
const workbook = XLSX.readFile(excelPath);
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];

const rows = XLSX.utils.sheet_to_json(sheet, {
  header: 1,
  defval: "",
  raw: false,
});

function cleanText(value) {
  return String(value ?? "").trim();
}

function toNumber(value) {
  if (value === null || value === undefined || value === "") return 0;

  const cleaned = String(value)
    .replace(",", ".")
    .replace("+", "")
    .trim();

  const number = Number(cleaned);
  return Number.isFinite(number) ? number : 0;
}

function seasonIdFromLabel(label) {
  const value = cleanText(label);

  const match = value.match(/^(\d{4})\/?(\d{2}|\d{4})$/);

  if (!match) {
    throw new Error(`Ongeldig seizoen: ${value}`);
  }

  const startYear = match[1];
  let endYear = match[2];

  if (endYear.length === 2) {
    endYear = startYear.slice(0, 2) + endYear;
  }

  return `${startYear}-${endYear}`;
}

function seasonDisplayLabel(label) {
  const id = seasonIdFromLabel(label);
  const [start, end] = id.split("-");
  return `${start}/${end}`;
}

function getSeasonNote(seasonId) {
  if (seasonId === "2019-2020") {
    return "Seizoen voortijdig beëindigd.";
  }

  if (seasonId === "2020-2021") {
    return "Seizoen voortijdig beëindigd.";
  }

  return "";
}

function parseStandingRow(row, division, currentSeasonLabel) {
  const offset = division === "A" ? 0 : 11;

  const seasonCell = cleanText(row[offset + 0]);
  const teamName = cleanText(row[offset + 1]);

  if (!teamName) return null;

  const seasonLabel = seasonCell || currentSeasonLabel;

  if (!seasonLabel) return null;

  const seasonId = seasonIdFromLabel(seasonLabel);

  return {
    seasonId,
    seasonLabel: seasonDisplayLabel(seasonLabel),
    division,
    teamName,
    played: toNumber(row[offset + 2]),
    wins: toNumber(row[offset + 3]),
    draws: toNumber(row[offset + 4]),
    losses: toNumber(row[offset + 5]),
    points: toNumber(row[offset + 6]),
    goalsFor: toNumber(row[offset + 7]),
    goalsAgainst: toNumber(row[offset + 8]),
    goalDifference: toNumber(row[offset + 9]),
  };
}

async function clearOldTeams(seasonRef, division) {
  const teamsRef = seasonRef
    .collection("divisions")
    .doc(division)
    .collection("teams");

  const snapshot = await teamsRef.get();

  if (snapshot.empty) return;

  const batch = db.batch();

  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
}

async function importStandings() {
  console.log(`Aantal rijen uit Excel: ${rows.length}`);

  const grouped = {};

  let currentSeasonA = "";
  let currentSeasonB = "";

  for (let index = 3; index < rows.length; index++) {
    const row = rows[index];

    const seasonA = cleanText(row[0]);
    const seasonB = cleanText(row[11]);

    if (seasonA) currentSeasonA = seasonA;
    if (seasonB) currentSeasonB = seasonB;

    const teamA = parseStandingRow(row, "A", currentSeasonA);
    const teamB = parseStandingRow(row, "B", currentSeasonB);

    for (const team of [teamA, teamB]) {
      if (!team) continue;

      grouped[team.seasonId] ??= {
        seasonLabel: team.seasonLabel,
        divisions: {
          A: [],
          B: [],
        },
      };

      grouped[team.seasonId].divisions[team.division].push(team);
    }
  }

  const seasons = Object.keys(grouped).sort();

  if (seasons.length === 0) {
    throw new Error("Geen seizoenen gevonden. Controleer de Excelindeling.");
  }

  console.log(`Gevonden seizoenen: ${seasons.join(", ")}`);

  for (const seasonId of seasons) {
    const season = grouped[seasonId];

    const seasonRef = db.collection("standings_archive").doc(seasonId);

    await seasonRef.set(
      {
        seasonId,
        seasonLabel: season.seasonLabel,
        isCurrentSeason: false,
        isFinal: true,
        note: getSeasonNote(seasonId),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    for (const division of ["A", "B"]) {
      const teams = season.divisions[division];

      teams.sort((a, b) => {
        if (b.points !== a.points) return b.points - a.points;
        if (b.goalDifference !== a.goalDifference) {
          return b.goalDifference - a.goalDifference;
        }
        if (b.goalsFor !== a.goalsFor) return b.goalsFor - a.goalsFor;
        return a.teamName.localeCompare(b.teamName);
      });

      await clearOldTeams(seasonRef, division);

      let position = 1;

      for (const team of teams) {
        const docId = String(position).padStart(3, "0");

        await seasonRef
          .collection("divisions")
          .doc(division)
          .collection("teams")
          .doc(docId)
          .set(
            {
              position,
              teamName: team.teamName,
              played: team.played,
              wins: team.wins,
              draws: team.draws,
              losses: team.losses,
              points: team.points,
              goalsFor: team.goalsFor,
              goalsAgainst: team.goalsAgainst,
              goalDifference: team.goalDifference,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

        position++;
      }

      console.log(
        `${seasonId} Divisie ${division}: ${teams.length} teams geïmporteerd`
      );
    }
  }

  console.log("Import klaar.");
}

importStandings()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Import mislukt:");
    console.error(error);
    process.exit(1);
  });