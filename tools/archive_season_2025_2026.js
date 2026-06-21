/* eslint-disable no-console */

const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const serviceAccount = require("./serviceAccountKey.json");

if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const db = getFirestore();

const SEASON_ID = "2025-2026";
const SEASON_LABEL = "2025/2026";

const ARCHIVE_ROOT = db.collection("season_archives").doc(SEASON_ID);

function nowTimestamp() {
  return FieldValue.serverTimestamp();
}

function asNumber(value, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) return value;

  if (typeof value === "string" && value.trim() !== "" && !Number.isNaN(Number(value))) {
    return Number(value);
  }

  return fallback;
}

function pick(data, keys, fallback = null) {
  for (const key of keys) {
    if (data && Object.prototype.hasOwnProperty.call(data, key)) {
      const value = data[key];

      if (value !== undefined && value !== null && value !== "") {
        return value;
      }
    }
  }

  return fallback;
}

function normalizeDivision(value, fallback = "onbekend") {
  if (value === null || value === undefined) return fallback;

  if (Array.isArray(value)) {
    for (const item of value) {
      const result = normalizeDivision(item, null);
      if (result === "A" || result === "B") return result;
    }

    return fallback;
  }

  const text = String(value).trim().toUpperCase();

  if (
    text === "A" ||
    text === "DDA" ||
    text.includes("DIVISIE A") ||
    text.includes("DERDE DIVISIE A")
  ) {
    return "A";
  }

  if (
    text === "B" ||
    text === "DDB" ||
    text.includes("DIVISIE B") ||
    text.includes("DERDE DIVISIE B")
  ) {
    return "B";
  }

  return fallback;
}

function normalizeUsernameKey(value, uid) {
  const base = String(value || uid || "onbekend")
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");

  return base || String(uid);
}

function getUidFromData(data, fallbackId = null) {
  return pick(
    data,
    [
      "uid",
      "userId",
      "userID",
      "gebruikerId",
      "gebruikerID",
      "deelnemerId",
      "deelnemerID",
      "ownerId",
      "createdBy",
    ],
    fallbackId
  );
}

function getPredictionPoints(data) {
  return asNumber(
    pick(
      data,
      [
        "punten",
        "points",
        "score",
        "totalPoints",
        "totaalPunten",
        "wedstrijdPunten",
        "matchPoints",
        "predictionPoints",
        "pointsEarned",
        "behaaldePunten",
      ],
      0
    ),
    0
  );
}

function getUserTotalPoints(data) {
  return asNumber(
    pick(
      data,
      [
        "totaalPunten",
        "totalPoints",
        "points",
        "punten",
        "totalCombinedPoints",
        "combinedTotal",
        "voorspelPunten",
        "predictionPoints",
      ],
      0
    ),
    0
  );
}

function getUserPointsA(data) {
  return asNumber(
    pick(
      data,
      [
        "puntenA",
        "pointsA",
        "totalPointsA",
        "competitieAPunten",
        "divisieAPunten",
        "ddaPunten",
        "aPoints",
      ],
      0
    ),
    0
  );
}

function getUserPointsB(data) {
  return asNumber(
    pick(
      data,
      [
        "puntenB",
        "pointsB",
        "totalPointsB",
        "competitieBPunten",
        "divisieBPunten",
        "ddbPunten",
        "bPoints",
      ],
      0
    ),
    0
  );
}

function getStandingPointsA(data) {
  return asNumber(
    pick(
      data,
      [
        "eindstand_A_punten",
        "eindstandPuntenA",
        "eindstandAPunten",
        "finalStandingPointsA",
        "finalStandingsPointsA",
      ],
      0
    ),
    0
  );
}

function getStandingPointsB(data) {
  return asNumber(
    pick(
      data,
      [
        "eindstand_B_punten",
        "eindstandPuntenB",
        "eindstandBPunten",
        "finalStandingPointsB",
        "finalStandingsPointsB",
      ],
      0
    ),
    0
  );
}

function getDivisionFromData(data) {
  return normalizeDivision(
    pick(
      data,
      [
        "division",
        "divisie",
        "competition",
        "competitie",
        "competitions",
        "league",
        "poule",
      ],
      null
    ),
    "onbekend"
  );
}

function getHomeTeam(data) {
  return pick(
    data,
    [
      "homeTeam",
      "thuisTeam",
      "teamThuis",
      "home",
      "thuis",
      "homeName",
      "thuisNaam",
    ],
    ""
  );
}

function getAwayTeam(data) {
  return pick(
    data,
    [
      "awayTeam",
      "uitTeam",
      "teamUit",
      "away",
      "uit",
      "awayName",
      "uitNaam",
    ],
    ""
  );
}

function getHomeGoals(data) {
  return pick(
    data,
    [
      "homeGoals",
      "thuisGoals",
      "homeScore",
      "thuisScore",
      "scoreThuis",
      "doelpuntenThuis",
    ],
    null
  );
}

function getAwayGoals(data) {
  return pick(
    data,
    [
      "awayGoals",
      "uitGoals",
      "awayScore",
      "uitScore",
      "scoreUit",
      "doelpuntenUit",
    ],
    null
  );
}

function getRound(data) {
  return asNumber(
    pick(
      data,
      [
        "round",
        "ronde",
        "speelronde",
        "roundNumber",
        "speelrondeNummer",
      ],
      0
    ),
    0
  );
}

async function writeWithBulkWriter(items, label) {
  const writer = db.bulkWriter();
  let count = 0;

  writer.onWriteError((error) => {
    console.error(`Schrijffout bij ${label}:`, error.documentRef.path, error.message);
    return false;
  });

  for (const item of items) {
    writer.set(item.ref, item.data, { merge: false });
    count += 1;
  }

  await writer.close();

  console.log(`${label}: ${count} documenten geschreven`);

  return count;
}

async function loadUsers() {
  console.log("Users laden...");

  const snap = await db.collection("users").get();
  const users = new Map();

  for (const doc of snap.docs) {
    const data = doc.data();
    const uid = doc.id;

    const username = String(
      pick(
        data,
        [
          "username",
          "displayName",
          "naam",
          "name",
          "gebruikersnaam",
        ],
        uid
      )
    );

    users.set(uid, {
      uid,
      username,
      displayName: pick(
        data,
        [
          "displayName",
          "username",
          "naam",
          "name",
        ],
        username
      ),
      email: pick(data, ["email"], ""),
      avatarUrl: pick(
        data,
        [
          "avatarUrl",
          "photoUrl",
          "profilePhotoUrl",
          "profielfoto",
        ],
        ""
      ),
      isFake: Boolean(pick(data, ["isFake", "fake", "testUser"], false)),
      userDocPointsA: getUserPointsA(data),
      userDocPointsB: getUserPointsB(data),
      userDocTotalPoints: getUserTotalPoints(data),
      usernameKey: normalizeUsernameKey(username, uid),
      rawUserFieldsChecked: true,
    });
  }

  console.log(`Users geladen: ${users.size}`);

  return users;
}

async function buildUsernameIndex(users) {
  console.log("Username index maken...");

  const items = [];

  for (const user of users.values()) {
    items.push({
      ref: db.collection("usernames").doc(user.usernameKey),
      data: {
        uid: user.uid,
        username: user.username,
        displayName: user.displayName,
        email: user.email,
        usernameKey: user.usernameKey,
        updatedAt: nowTimestamp(),
      },
    });

    items.push({
      ref: db.collection("users").doc(user.uid),
      data: {
        usernameLower: String(user.username || "").toLowerCase().trim(),
        usernameKey: user.usernameKey,
        updatedAt: nowTimestamp(),
      },
    });
  }

  await writeWithBulkWriter(items, "Username index");
}

async function aggregatePredictions(users) {
  console.log("Voorspellingen aggregeren...");

  const totals = new Map();

  for (const user of users.values()) {
    totals.set(user.uid, {
      uid: user.uid,
      puntenA: 0,
      puntenB: 0,
      wedstrijdPunten: 0,
      aantalVoorspellingen: 0,
      aantalVoorspellingenZonderPunten: 0,
    });
  }

  const stream = db.collection("voorspellingen").stream();

  let processed = 0;
  let skippedWithoutUid = 0;

  for await (const doc of stream) {
    const data = doc.data();
    const uid = getUidFromData(data, null);

    if (!uid) {
      skippedWithoutUid += 1;
      continue;
    }

    if (!totals.has(uid)) {
      totals.set(uid, {
        uid,
        puntenA: 0,
        puntenB: 0,
        wedstrijdPunten: 0,
        aantalVoorspellingen: 0,
        aantalVoorspellingenZonderPunten: 0,
      });
    }

    const row = totals.get(uid);
    const points = getPredictionPoints(data);
    const division = getDivisionFromData(data);

    row.wedstrijdPunten += points;
    row.aantalVoorspellingen += 1;

    if (points === 0) {
      row.aantalVoorspellingenZonderPunten += 1;
    }

    if (division === "A") {
      row.puntenA += points;
    } else if (division === "B") {
      row.puntenB += points;
    }

    processed += 1;

    if (processed % 10000 === 0) {
      console.log(`Voorspellingen verwerkt: ${processed}`);
    }
  }

  console.log(`Voorspellingen verwerkt totaal: ${processed}`);
  console.log(`Voorspellingen zonder uid overgeslagen: ${skippedWithoutUid}`);

  return totals;
}

async function aggregateFinalStandingPoints(users) {
  console.log("Eindstandpunten aggregeren...");

  const finalPoints = new Map();

  for (const user of users.values()) {
    finalPoints.set(user.uid, {
      uid: user.uid,
      eindstandPuntenA: 0,
      eindstandPuntenB: 0,
    });
  }

  const voorspelPuntenSnap = await db.collection("voorspel_punten").get();

  for (const doc of voorspelPuntenSnap.docs) {
    const data = doc.data();
    const uid = getUidFromData(data, doc.id);

    if (!finalPoints.has(uid)) {
      finalPoints.set(uid, {
        uid,
        eindstandPuntenA: 0,
        eindstandPuntenB: 0,
      });
    }

    const row = finalPoints.get(uid);

    row.eindstandPuntenA += getStandingPointsA(data);
    row.eindstandPuntenB += getStandingPointsB(data);
  }

  const eindstandSnap = await db.collection("eindstand_voorspellingen").get();

  for (const doc of eindstandSnap.docs) {
    const data = doc.data();
    const uid = getUidFromData(data, null);

    if (!uid) continue;

    if (!finalPoints.has(uid)) {
      finalPoints.set(uid, {
        uid,
        eindstandPuntenA: 0,
        eindstandPuntenB: 0,
      });
    }

    const row = finalPoints.get(uid);
    const division = getDivisionFromData(data);

    const points = asNumber(
      pick(
        data,
        [
          "punten",
          "points",
          "eindstandpunten",
          "eindstandPunten",
          "eindstand_A_punten",
          "eindstand_B_punten",
        ],
        0
      ),
      0
    );

    if (division === "A") {
      row.eindstandPuntenA += points;
    } else if (division === "B") {
      row.eindstandPuntenB += points;
    }
  }

  console.log(`Eindstandpunten verwerkt voor ${finalPoints.size} users`);

  return finalPoints;
}

async function archiveGlobalRanking(users, predictionTotals, finalStandingPoints) {
  console.log("Globale eindranglijst archiveren...");

  const rows = [];

  for (const user of users.values()) {
    const pred = predictionTotals.get(user.uid) || {
      puntenA: 0,
      puntenB: 0,
      wedstrijdPunten: 0,
      aantalVoorspellingen: 0,
      aantalVoorspellingenZonderPunten: 0,
    };

    const final = finalStandingPoints.get(user.uid) || {
      eindstandPuntenA: 0,
      eindstandPuntenB: 0,
    };

    const berekendTotaal =
      pred.wedstrijdPunten +
      final.eindstandPuntenA +
      final.eindstandPuntenB;

    const totaalPunten =
      user.userDocTotalPoints > 0
        ? user.userDocTotalPoints
        : berekendTotaal;

    const puntenA =
      user.userDocPointsA > 0
        ? user.userDocPointsA
        : pred.puntenA;

    const puntenB =
      user.userDocPointsB > 0
        ? user.userDocPointsB
        : pred.puntenB;

    rows.push({
      uid: user.uid,
      username: user.username,
      displayName: user.displayName,
      email: user.email,
      avatarUrl: user.avatarUrl,
      usernameKey: user.usernameKey,
      isFake: user.isFake,
      puntenA,
      puntenB,
      wedstrijdPunten: pred.wedstrijdPunten,
      eindstandPuntenA: final.eindstandPuntenA,
      eindstandPuntenB: final.eindstandPuntenB,
      berekendTotaal,
      totaalPunten,
      aantalVoorspellingen: pred.aantalVoorspellingen,
      aantalVoorspellingenZonderPunten: pred.aantalVoorspellingenZonderPunten,
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      archivedAt: nowTimestamp(),
    });
  }

  rows.sort((a, b) => {
    if (b.totaalPunten !== a.totaalPunten) {
      return b.totaalPunten - a.totaalPunten;
    }

    return String(a.username).localeCompare(String(b.username), "nl");
  });

  let previousPoints = null;
  let previousRank = 0;

  rows.forEach((row, index) => {
    if (row.totaalPunten === previousPoints) {
      row.rank = previousRank;
    } else {
      row.rank = index + 1;
      previousRank = row.rank;
      previousPoints = row.totaalPunten;
    }
  });

  const items = rows.map((row) => ({
    ref: ARCHIVE_ROOT
      .collection("rankings")
      .doc("global")
      .collection("users")
      .doc(row.uid),
    data: row,
  }));

  await writeWithBulkWriter(items, "Globale eindranglijst");

  const topTen = rows.slice(0, 10).map((row) => ({
    rank: row.rank,
    uid: row.uid,
    username: row.username,
    totaalPunten: row.totaalPunten,
    isFake: row.isFake,
  }));

  await ARCHIVE_ROOT.collection("rankings").doc("global").set({
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,
    type: "global",
    userCount: rows.length,
    includesFakeUsers: true,
    topTen,
    archivedAt: nowTimestamp(),
  });

  console.log("Top 10 globale ranking:");
  console.table(topTen);

  return rows.length;
}

async function archiveMatches() {
  console.log("Wedstrijden archiveren...");

  const items = [];
  const counts = {
    A: 0,
    B: 0,
    onbekend: 0,
  };

  const stream = db.collection("matches").stream();

  for await (const doc of stream) {
    const data = doc.data();
    const division = getDivisionFromData(data);

    const homeGoalsRaw = getHomeGoals(data);
    const awayGoalsRaw = getAwayGoals(data);

    const homeGoals =
      homeGoalsRaw === null
        ? null
        : asNumber(homeGoalsRaw, null);

    const awayGoals =
      awayGoalsRaw === null
        ? null
        : asNumber(awayGoalsRaw, null);

    const archiveData = {
      matchId: doc.id,
      division,
      round: getRound(data),
      homeTeam: getHomeTeam(data),
      awayTeam: getAwayTeam(data),
      homeGoals,
      awayGoals,
      isPlayed: homeGoals !== null && awayGoals !== null,
      playedAt: pick(
        data,
        [
          "playedAt",
          "date",
          "datum",
          "matchDate",
          "scheduledAt",
        ],
        null
      ),
      originalPath: doc.ref.path,
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      archivedAt: nowTimestamp(),
    };

    const targetDivision =
      division === "A" || division === "B"
        ? division
        : "onbekend";

    items.push({
      ref: ARCHIVE_ROOT
        .collection("divisions")
        .doc(targetDivision)
        .collection("results")
        .doc(doc.id),
      data: archiveData,
    });

    counts[targetDivision] = (counts[targetDivision] || 0) + 1;
  }

  await writeWithBulkWriter(items, "Wedstrijden");

  for (const division of Object.keys(counts)) {
    await ARCHIVE_ROOT.collection("divisions").doc(division).set(
      {
        division,
        seasonId: SEASON_ID,
        seasonLabel: SEASON_LABEL,
        resultsCount: counts[division],
        updatedAt: nowTimestamp(),
      },
      { merge: true }
    );
  }

  console.log("Wedstrijden per divisie:", counts);

  return counts;
}

async function archiveStandings() {
  console.log("Standen archiveren...");

  const items = [];
  const counts = {
    A: 0,
    B: 0,
    onbekend: 0,
  };

  const stream = db.collection("standen").stream();

  for await (const doc of stream) {
    const data = doc.data();
    const division = getDivisionFromData(data);

    const targetDivision =
      division === "A" || division === "B"
        ? division
        : "onbekend";

    const archiveData = {
      standingId: doc.id,
      division: targetDivision,
      teamName: pick(
        data,
        [
          "teamName",
          "club",
          "naam",
          "name",
          "team",
        ],
        doc.id
      ),
      played: asNumber(
        pick(data, ["played", "gespeeld", "wedstrijden", "g"], 0),
        0
      ),
      wins: asNumber(
        pick(data, ["wins", "gewonnen", "w"], 0),
        0
      ),
      draws: asNumber(
        pick(data, ["draws", "gelijk", "gl"], 0),
        0
      ),
      losses: asNumber(
        pick(data, ["losses", "verloren", "v"], 0),
        0
      ),
      goalsFor: asNumber(
        pick(data, ["goalsFor", "doelpuntenVoor", "voor", "dv"], 0),
        0
      ),
      goalsAgainst: asNumber(
        pick(data, ["goalsAgainst", "doelpuntenTegen", "tegen", "dt"], 0),
        0
      ),
      goalDifference: asNumber(
        pick(data, ["goalDifference", "doelsaldo", "saldo", "ds"], 0),
        0
      ),
      points: asNumber(
        pick(data, ["points", "punten", "pnt"], 0),
        0
      ),
      rank: asNumber(
        pick(data, ["rank", "positie", "plaats"], 0),
        0
      ),
      originalPath: doc.ref.path,
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      archivedAt: nowTimestamp(),
    };

    items.push({
      ref: ARCHIVE_ROOT
        .collection("divisions")
        .doc(targetDivision)
        .collection("final_standings")
        .doc(doc.id),
      data: archiveData,
    });

    counts[targetDivision] = (counts[targetDivision] || 0) + 1;
  }

  await writeWithBulkWriter(items, "Eindstanden");

  for (const division of Object.keys(counts)) {
    await ARCHIVE_ROOT.collection("divisions").doc(division).set(
      {
        division,
        seasonId: SEASON_ID,
        seasonLabel: SEASON_LABEL,
        finalStandingsCount: counts[division],
        isFinal: true,
        updatedAt: nowTimestamp(),
      },
      { merge: true }
    );
  }

  console.log("Eindstanden per divisie:", counts);

  return counts;
}

async function aggregatePouleTotalsFromCollection(collectionName, totals) {
  const snap = await db.collection(collectionName).get();

  let processed = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const uid = getUidFromData(data, null);

    if (!uid) continue;

    if (!totals.has(uid)) {
      totals.set(uid, {
        uid,
        totalPoulePoints: 0,
        poulesCount: 0,
        bronnen: [],
      });
    }

    const row = totals.get(uid);

    row.totalPoulePoints += getPredictionPoints(data);
    row.poulesCount += 1;
    row.bronnen.push(collectionName);

    processed += 1;
  }

  console.log(`${collectionName} verwerkt: ${processed}`);
}

async function archivePouleTotals(users) {
  console.log("Pouletotalen archiveren...");

  const totals = new Map();

  await aggregatePouleTotalsFromCollection("poule_predictions", totals);
  await aggregatePouleTotalsFromCollection("poule_voorspellingen", totals);
  await aggregatePouleTotalsFromCollection("predictions", totals);

  const deelnemerStream = db.collectionGroup("deelnemers").stream();

  let deelnemersProcessed = 0;

  for await (const doc of deelnemerStream) {
    const data = doc.data();
    const uid = getUidFromData(data, doc.id);

    if (!uid) continue;

    if (!totals.has(uid)) {
      totals.set(uid, {
        uid,
        totalPoulePoints: 0,
        poulesCount: 0,
        bronnen: [],
      });
    }

    const row = totals.get(uid);

    row.totalPoulePoints += asNumber(
      pick(
        data,
        [
          "punten",
          "points",
          "totalPoints",
          "totaalPunten",
          "poulePunten",
        ],
        0
      ),
      0
    );

    row.poulesCount += 1;
    row.bronnen.push(doc.ref.path);

    deelnemersProcessed += 1;
  }

  console.log(`Poule deelnemers verwerkt: ${deelnemersProcessed}`);

  const rows = [];

  for (const [uid, row] of totals.entries()) {
    const user = users.get(uid);

    rows.push({
      uid,
      username: user ? user.username : uid,
      displayName: user ? user.displayName : uid,
      email: user ? user.email : "",
      avatarUrl: user ? user.avatarUrl : "",
      isFake: user ? user.isFake : false,
      totalPoulePoints: row.totalPoulePoints,
      poulesCount: row.poulesCount,
      bronnen: Array.from(new Set(row.bronnen)).slice(0, 20),
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      archivedAt: nowTimestamp(),
    });
  }

  rows.sort((a, b) => {
    if (b.totalPoulePoints !== a.totalPoulePoints) {
      return b.totalPoulePoints - a.totalPoulePoints;
    }

    return String(a.username).localeCompare(String(b.username), "nl");
  });

  rows.forEach((row, index) => {
    row.rank = index + 1;
  });

  const items = rows.map((row) => ({
    ref: ARCHIVE_ROOT
      .collection("rankings")
      .doc("poules")
      .collection("users")
      .doc(row.uid),
    data: row,
  }));

  await writeWithBulkWriter(items, "Pouletotalen");

  await ARCHIVE_ROOT.collection("rankings").doc("poules").set({
    seasonId: SEASON_ID,
    seasonLabel: SEASON_LABEL,
    type: "poules",
    userCount: rows.length,
    archivedAt: nowTimestamp(),
  });

  return rows.length;
}

async function archiveLatestXPosts() {
  console.log("Laatste 5 X posts archiveren...");

  const snap = await db.collection("x_posts").get();

  const posts = snap.docs.map((doc) => {
    const data = doc.data();
    const sortValue = pick(
      data,
      [
        "createdAt",
        "publishedAt",
        "date",
        "datum",
        "timestamp",
      ],
      null
    );

    return {
      id: doc.id,
      data,
      sortValue,
    };
  });

  posts.sort((a, b) => {
    const aMillis =
      a.sortValue && typeof a.sortValue.toMillis === "function"
        ? a.sortValue.toMillis()
        : 0;

    const bMillis =
      b.sortValue && typeof b.sortValue.toMillis === "function"
        ? b.sortValue.toMillis()
        : 0;

    return bMillis - aMillis;
  });

  const latest = posts.slice(0, 5);

  const items = latest.map((post) => ({
    ref: ARCHIVE_ROOT.collection("x_posts_latest").doc(post.id),
    data: {
      ...post.data,
      originalPath: `x_posts/${post.id}`,
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      archivedAt: nowTimestamp(),
    },
  }));

  await writeWithBulkWriter(items, "Laatste 5 X posts");

  return latest.length;
}

async function writeArchiveMeta(summary) {
  await ARCHIVE_ROOT.set(
    {
      seasonId: SEASON_ID,
      seasonLabel: SEASON_LABEL,
      archiveType: "season_archive",
      includesFakeUsersInRanking: true,
      createdAt: nowTimestamp(),
      updatedAt: nowTimestamp(),
      summary,
      note: "Aangemaakt door archive_season_2025_2026.js. Dit script verwijdert geen live data.",
    },
    { merge: true }
  );
}

async function main() {
  console.log("Start archivering seizoen 2025/2026");
  console.log("Er wordt niets verwijderd.");

  const users = await loadUsers();

  await buildUsernameIndex(users);

  const predictionTotals = await aggregatePredictions(users);
  const finalStandingPoints = await aggregateFinalStandingPoints(users);

  const globalRankingCount = await archiveGlobalRanking(
    users,
    predictionTotals,
    finalStandingPoints
  );

  const matchCounts = await archiveMatches();
  const standingCounts = await archiveStandings();
  const pouleUsersCount = await archivePouleTotals(users);
  const latestXPostsCount = await archiveLatestXPosts();

  const summary = {
    usersLoaded: users.size,
    globalRankingCount,
    matchCounts,
    standingCounts,
    pouleUsersCount,
    latestXPostsCount,
  };

  await writeArchiveMeta(summary);

  console.log("Archivering klaar.");
  console.log("Samenvatting:");
  console.log(JSON.stringify(summary, null, 2));

  process.exit(0);
}

main().catch((error) => {
  console.error("Archivering mislukt:");
  console.error(error);
  process.exit(1);
});