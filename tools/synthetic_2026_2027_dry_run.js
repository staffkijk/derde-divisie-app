/* eslint-disable no-console */
/**
 * Synthetic 2026/2027 predictor â€” STRICT DRY RUN.
 *
 * Read operations:
 * - standings_archive
 * - season_archives/2025-2026
 * - seasons/2026-2027/{teams,matches}
 * - users, usernames, archived fake ranking users (identity collision research)
 *
 * There are deliberately no Firestore/Auth write imports or calls in this file.
 * Output is printed to stdout. Redirecting stdout to a local report is optional.
 */

const crypto = require("crypto");
const { applicationDefault, getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const PROJECT_ID = "derde-divisie-app";
const SEASON = "2026-2027";
const OLD_SEASON = "2025-2026";
const RUN_ID = "synthetic-2026-2027-v1";
const MASTER_SEED = `${RUN_ID}|dry-run|model-v1`;
const PILOT_RUN_ID = "synthetic-2026-2027-pilot-v1";
const PILOT_CONFIG_HASH = "045a3e1f";
const LEGACY_CONFIG_HASH = "205bef84";
const PILOT_IDENTITIES = [
  ["syn_2026_2027_001", "Milan de Boer", "milan92"],
  ["syn_2026_2027_002", "Sophie Vermeer", "sofievermeer"],
  ["syn_2026_2027_003", "Jeroen Bakker", "jbakker83"],
  ["syn_2026_2027_004", "Lisa van Dijk", "lisavd"],
  ["syn_2026_2027_005", "Tom van Dijk", "tomdijk"],
];

if (!getApps().length) {
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
}
const db = getFirestore();

const ENTRY_TYPE = {
  // These two current clubs were outside the 2025/26 Derde Divisie archive and
  // are treated as descending from the higher Tweede Divisie level.
  acv: "relegatedFromTier3",
  excelsiormaassluis: "relegatedFromTier3",
  // Current clubs absent from the 2025/26 Derde Divisie archive and not in the
  // explicit higher-tier list receive a conservative promoted prior.
  hollandia: "promotedFromTier5",
  purmersteijn: "promotedFromTier5",
  svzw: "promotedFromTier5",
  achillesveen: "promotedFromTier5",
  dongen: "promotedFromTier5",
  evvecht: "promotedFromTier5",
  svpoortugaal: "promotedFromTier5",
};

const PROFILE_PLAN = [
  ["strengthFollower", 12], ["conservative", 9], ["homeBias", 7],
  ["supporterBias", 7], ["upsetProne", 6], ["goalLight", 5], ["goalHeavy", 4],
];

const IDENTITY_SEEDS = [
  ["Milan de Boer", "milan92"], ["Sophie Vermeer", "sofievermeer"],
  ["Jeroen Bakker", "jbakker83"], ["Lisa van Dijk", "lisavd"],
  ["Tom van Dijk", "tomdijk"], ["Noor van Dijk", "noor_vd"],
  ["Daan Smit", "daan_smit"], ["Femke Mulder", "femke88"],
  ["Lars de Wit", "larsdw"], ["Eline Jansen", "elinej"],
  ["Bram Vos", "bramvos"], ["Maaike Hoekstra", "maaikeh"],
  ["Niels Kuiper", "nkuiper"], ["Sanne Dekker", "sanne_d"],
  ["Ruben Meijer", "rubenmeijer"], ["Iris Hendriks", "irisado20"],
  ["Koen de Groot", "koendg"], ["Lotte Peters", "lottep"],
  ["Timo Koster", "timofan"], ["Eva de Jong", "evadj"],
  ["Martijn Blom", "martijnb"], ["Lieke Visser", "liekev"],
  ["Joost Kramer", "joostk"], ["Nina van Leeuwen", "ninavl"],
  ["Bas Post", "baspost"], ["Romy Prins", "romyprins"],
  ["Pieter Groen", "pieterg"], ["Elise de Bruin", "elisedb"],
  ["Stijn Verhoef", "stijnv"], ["Anna van Loon", "annavl"],
  ["Rick Bos", "rickbos"], ["Marieke Peeters", "mariekep"],
  ["Thijs van Dam", "thijsvd"], ["Nadine de Graaf", "nadineg"],
  ["Jelle Scholten", "jelles"], ["Rosa Timmer", "rosat"],
  ["Harm Dijkstra", "harmd"], ["Leonie Martens", "leonie_m"],
  ["Wouter Schouten", "wouters"], ["Floor van den Berg", "floorvdb"],
  ["Pascal Willems", "pascalw"], ["Myrthe Jacobs", "myrthej"],
  ["Arjan Mol", "arjanmol"], ["Sil Brouwer", "silb"],
  ["Henk de Ruiter", "henkdr"], ["Matthijs Kok", "matthijsk"],
  ["Stefan van Beek", "stefanvb"], ["Joris Smits", "joriss"],
  ["Kees van der Meer", "keesvdm"], ["Noa de Vries", "noadv"],
];
const SEASON_WEIGHTS = {
  "2025-2026": 1.00, "2024-2025": 0.62, "2023-2024": 0.38,
  "2022-2023": 0.24, "2021-2022": 0.15, "2020-2021": 0.035,
  "2019-2020": 0.05, "2018-2019": 0.05, "2017-2018": 0.03,
  "2016-2017": 0.02,
};

function normalize(value) {
  return String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/&/g, "en").replace(/[^a-z0-9]/g, "");
}

function hash32(input) {
  let h = 2166136261;
  for (const char of String(input)) {
    h ^= char.charCodeAt(0);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function rngFor(...parts) {
  let state = hash32([MASTER_SEED, ...parts].join("|")) || 1;
  return () => {
    state += 0x6D2B79F5;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function gaussian(rng) {
  const u = Math.max(rng(), 1e-12);
  const v = Math.max(rng(), 1e-12);
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function mean(values) { return values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0; }
function round(value, digits = 2) { return Number(value.toFixed(digits)); }

function percentileRanks(rows, selector) {
  const sorted = rows.map(selector).slice().sort((a, b) => a - b);
  return new Map(rows.map((row) => {
    const value = selector(row);
    const lower = sorted.filter((item) => item < value).length;
    const equal = sorted.filter((item) => item === value).length;
    return [row, (lower + (equal - 1) / 2) / Math.max(1, sorted.length - 1)];
  }));
}

async function loadInputs() {
  const [seasonsSnap, teamsSnap, matchesSnap, usersSnap, usernamesSnap, oldFakeSnap, pilotManifestSnap] = await Promise.all([
    db.collection("standings_archive").get(),
    db.collection("seasons").doc(SEASON).collection("teams").get(),
    db.collection("seasons").doc(SEASON).collection("matches").get(),
    db.collection("users").get(),
    db.collection("usernames").get(),
    db.collection("season_archives").doc(OLD_SEASON).collection("rankings")
      .doc("global").collection("users").where("isFake", "==", true).get(),
    db.doc(`synthetic_runs/${PILOT_RUN_ID}`).get(),
  ]);

  const historical = [];
  for (const seasonDoc of seasonsSnap.docs) {
    for (const division of ["A", "B"]) {
      const snap = await seasonDoc.ref.collection("divisions").doc(division).collection("teams").get();
      for (const doc of snap.docs) {
        const data = doc.data();
        historical.push({
          season: seasonDoc.id, division, teamName: String(data.teamName || doc.id),
          key: normalize(data.teamName || doc.id), position: Number(data.position || doc.id),
          played: Number(data.played || 0), points: Number(data.points || 0),
          goalsFor: Number(data.goalsFor || 0), goalsAgainst: Number(data.goalsAgainst || 0),
          // Reconstruct from GF/GA because imported goalDifference can be inconsistent.
          goalDifference: Number(data.goalsFor || 0) - Number(data.goalsAgainst || 0),
        });
      }
    }
  }

  const liveUsers = usersSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const usernames = usernamesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const pilotErrors = [];
  const pilotManifest = pilotManifestSnap.exists ? pilotManifestSnap.data() : null;
  if (!pilotManifest) pilotErrors.push("pilotmanifest ontbreekt");
  else {
    if (pilotManifest.status !== "verified") pilotErrors.push("pilotmanifest is niet verified");
    if (pilotManifest.configHash !== PILOT_CONFIG_HASH) pilotErrors.push("pilot configHash wijkt af");
    if (pilotManifest.syntheticRunId !== PILOT_RUN_ID) pilotErrors.push("pilot manifest syntheticRunId wijkt af");
  }
  for (const [uid, displayName, username] of PILOT_IDENTITIES) {
    const user = liveUsers.find((row) => row.id === uid);
    const index = usernames.find((row) => row.id === normalize(username));
    if (!user || user.displayName !== displayName || user.username !== username || user.syntheticRunId !== PILOT_RUN_ID) pilotErrors.push(`${uid}: inherited identity ongeldig`);
    if (!index || index.uid !== uid || index.username !== username || index.syntheticRunId !== PILOT_RUN_ID) pilotErrors.push(`${uid}: inherited username-index ongeldig`);
  }
  return {
    historical,
    teams: teamsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    matches: matchesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    liveUsers,
    usernames,
    oldFakeUsers: oldFakeSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    inheritedPilot: { valid: pilotErrors.length === 0, errors: pilotErrors, runId: PILOT_RUN_ID, manifestPath: `synthetic_runs/${PILOT_RUN_ID}`, identities: PILOT_IDENTITIES.map(([syntheticId, displayName, username]) => ({ syntheticId, displayName, username })) },
  };
}

function buildStrengths(inputs) {
  const current = inputs.teams.map((team) => ({
    id: team.id,
    name: String(team.displayName || team.teamName || team.name || team.id),
    division: String(team.division || "").toUpperCase(),
    aliases: new Set([team.id, team.displayName, team.teamName, team.name, team.logoKey, team.slug].map(normalize).filter(Boolean)),
  }));

  const bySeasonDivision = new Map();
  for (const row of inputs.historical) {
    const key = `${row.season}|${row.division}`;
    if (!bySeasonDivision.has(key)) bySeasonDivision.set(key, []);
    bySeasonDivision.get(key).push(row);
  }

  const normalizedHistory = [];
  for (const rows of bySeasonDivision.values()) {
    const valid = rows.filter((row) => row.played > 0);
    const ppgRank = percentileRanks(valid, (row) => row.points / row.played);
    const gdRank = percentileRanks(valid, (row) => row.goalDifference / row.played);
    for (const row of valid) {
      const pos = 1 - (row.position - 1) / Math.max(1, valid.length - 1);
      normalizedHistory.push({ ...row, seasonScore: 0.60 * ppgRank.get(row) + 0.25 * gdRank.get(row) + 0.15 * pos });
    }
  }

  const provisional = current.map((club) => {
    const history = normalizedHistory.filter((row) => club.aliases.has(row.key))
      .sort((a, b) => b.season.localeCompare(a.season));
    const weighted = history.filter((row) => SEASON_WEIGHTS[row.season]);
    const weight = weighted.reduce((sum, row) => sum + SEASON_WEIGHTS[row.season], 0);
    const historicalScore = weight
      ? weighted.reduce((sum, row) => sum + row.seasonScore * SEASON_WEIGHTS[row.season], 0) / weight
      : 0.5;
    const recentGames = weighted.filter((row) => row.season >= "2022-2023").reduce((sum, row) => sum + row.played, 0);
    const entryType = ENTRY_TYPE[normalize(club.name)] || "retainedTier4";
    const prior = entryType === "relegatedFromTier3" ? 0.72 : entryType === "promotedFromTier5" ? 0.40 : 0.50;
    const confidence = entryType === "relegatedFromTier3"
      ? clamp(0.48 + Math.min(recentGames, 100) / 500, 0.48, 0.68)
      : clamp(0.25 + recentGames / 220, 0.25, 0.92);
    const combined = confidence * historicalScore + (1 - confidence) * prior;
    return { ...club, history, entryType, confidence, combined };
  });

  // Normalize to 35..85 per current division to keep ratings interpretable.
  const result = [];
  for (const division of ["A", "B"]) {
    const rows = provisional.filter((club) => club.division === division);
    const min = Math.min(...rows.map((row) => row.combined));
    const max = Math.max(...rows.map((row) => row.combined));
    for (const row of rows) {
      const rating = 35 + 50 * (row.combined - min) / Math.max(0.001, max - min);
      const basis = row.history.slice(0, 4).map((h) => `${h.season}:${h.position}e/${round(h.points / h.played, 2)}ppg`).join(", ") || `${row.entryType}-prior`;
      result.push({ ...row, strengthRating: round(rating, 1), historicalBasis: basis });
    }
  }
  return result;
}

function buildPlayers(strengths, inputs) {
  const assignments = [
    ...Array.from({ length: 22 }, () => ["A"]),
    ...Array.from({ length: 22 }, () => ["B"]),
    ...Array.from({ length: 6 }, () => ["A", "B"]),
  ];
  const profiles = PROFILE_PLAN.flatMap(([profile, count]) => Array.from({ length: count }, () => profile));
  const shuffle = (array, key) => {
    const rng = rngFor(key);
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1)); [array[i], array[j]] = [array[j], array[i]];
    }
  };
  shuffle(assignments, "competition-assignments"); shuffle(profiles, "profile-assignments");
  const idleIndices = new Set([7, 19, 32, 46]);
  if (!inputs.inheritedPilot.valid) throw new Error(`Inherited pilot ongeldig: ${inputs.inheritedPilot.errors.join(", ")}`);
  const inheritedIds = new Set([...inputs.inheritedPilot.identities.map((item) => item.syntheticId), ...inputs.liveUsers.filter((user) => user.syntheticRunId === RUN_ID).map((user) => user.id)]);
  const inheritedUsernameKeys = new Set([...inputs.inheritedPilot.identities.map((item) => normalize(item.username)), ...inputs.usernames.filter((item) => item.syntheticRunId === RUN_ID).map((item) => item.id)]);
  const reservedDisplay = new Set(inputs.liveUsers.filter((user) => !inheritedIds.has(user.id)).map((user) => normalize(user.displayName || user.username)).filter(Boolean));
  const reservedUsername = new Set([
    ...inputs.liveUsers.filter((user) => !inheritedIds.has(user.id)).flatMap((user) => [normalize(user.username), normalize(user.usernameKey)]),
    ...inputs.usernames.filter((user) => !inheritedUsernameKeys.has(user.id)).flatMap((user) => [normalize(user.id), normalize(user.username)]),
  ].filter(Boolean));
  const chosenDisplay = new Set();
  const chosenUsername = new Set();

  return assignments.map((competitions, index) => {
    const syntheticId = `syn_2026_2027_${String(index + 1).padStart(3, "0")}`;
    let [displayName, username] = IDENTITY_SEEDS[index];
    if (reservedDisplay.has(normalize(displayName)) || chosenDisplay.has(normalize(displayName))) {
      displayName = `${displayName} ${String.fromCharCode(65 + (index % 26))}.`;
    }
    let suffix = 0;
    const baseUsername = username;
    while (reservedUsername.has(normalize(username)) || chosenUsername.has(normalize(username))) {
      suffix += 1;
      username = `${baseUsername}${suffix === 1 ? "2627" : `2627${suffix}`}`;
    }
    chosenDisplay.add(normalize(displayName)); chosenUsername.add(normalize(username));
    const eligibleClubs = strengths.filter((club) => competitions.includes(club.division));
    const favoriteClub = eligibleClubs[hash32(`${syntheticId}|favorite`) % eligibleClubs.length].name;
    return { syntheticId, displayName, username, competitions, isIdle: idleIndices.has(index), predictionProfile: profiles[index], favoriteClub };
  });
}

function validateTeamData(inputs, strengths) {
  const errors = []; const warnings = [];
  const byDivision = Object.fromEntries(["A", "B"].map((division) => [division, strengths.filter((club) => club.division === division)]));
  for (const division of ["A", "B"]) if (byDivision[division].length !== 18) errors.push(`Divisie ${division}: ${byDivision[division].length} teams, verwacht 18.`);
  const allKeys = strengths.map((club) => normalize(club.name));
  const duplicateKeys = [...new Set(allKeys.filter((key, index) => allKeys.indexOf(key) !== index))];
  if (duplicateKeys.length) errors.push(`Dubbele clubs: ${duplicateKeys.join(", ")}`);
  const invalidMatchTeams = [];
  for (const match of inputs.matches) {
    const fields = matchFields(match);
    const divisionClubs = byDivision[fields.division] || [];
    for (const [role, team] of [["home", fields.home], ["away", fields.away]]) {
      if (!divisionClubs.some((club) => club.aliases.has(normalize(team)))) invalidMatchTeams.push(`${match.id}:${role}:${team}:${fields.division}`);
    }
  }
  if (invalidMatchTeams.length) errors.push(`Wedstrijdteams buiten actuele divisieset (${invalidMatchTeams.length}): ${invalidMatchTeams.slice(0, 20).join(", ")}`);
  for (const forbidden of ["Kloetinge", "Meerssen", "ASWH"]) if (allKeys.includes(normalize(forbidden))) errors.push(`${forbidden} staat onterecht in actuele teamset.`);
  for (const required of ["TOGB", "Zwaluwen"]) {
    const club = strengths.find((item) => normalize(item.name) === normalize(required));
    if (!club || club.division !== "B") errors.push(`${required} ontbreekt in Divisie B.`);
  }
  if (!warnings.length) warnings.push("Geen waarschuwingen in actuele team- en wedstrijdkoppeling.");
  return { valid: errors.length === 0, divisionCounts: { A: byDivision.A.length, B: byDivision.B.length }, uniqueClubs: new Set(allKeys).size, matchesChecked: inputs.matches.length, teamReferencesChecked: inputs.matches.length * 2, invalidMatchTeams, errors, warnings };
}

function buildPools(players, strengths) {
  const active = players.filter((player) => !player.isIdle);
  const byId = new Map(players.map((player) => [player.syntheticId, player]));
  const aPlayers = active.filter((p) => p.competitions.includes("A"));
  const bPlayers = active.filter((p) => p.competitions.includes("B"));
  const pick = (list) => list.map((id) => byId.get(id)).filter((p) => p && !p.isIdle).map((p) => p.syntheticId);
  const spartaFans = [...active.filter((p) => p.favoriteClub === "Sparta Nijkerk"), ...aPlayers].filter((p, index, list) => list.findIndex((x) => x.syntheticId === p.syntheticId) === index).slice(0, 12).map((p) => p.syntheticId);
  const pools = [
    { id: "synpool_2026_2027_sparta", name: "Sparta Nijkerk Supporters", kind: "club", isPublic: true, access: "openbaar", division: "A", teamName: "Sparta Nijkerk", predictionScope: "both", memberIds: spartaFans },
    { id: "synpool_2026_2027_zaterdag", name: "De Zaterdagvrienden", kind: "competition", isPublic: true, access: "openbaar", division: "A+B", predictionScope: "both", memberIds: pick(["syn_2026_2027_004", "syn_2026_2027_010", "syn_2026_2027_028", "syn_2026_2027_037", "syn_2026_2027_038", "syn_2026_2027_039"]) },
    { id: "synpool_2026_2027_kantine3", name: "Kantine 3", kind: "competition", isPublic: true, access: "openbaar", division: "B", predictionScope: "matches", memberIds: bPlayers.slice(3, 9).map((p) => p.syntheticId) },
    { id: "synpool_2026_2027_koplopers", name: "Koplopers onder elkaar", kind: "competition", isPublic: true, access: "openbaar", division: "A", predictionScope: "both", memberIds: aPlayers.slice(8, 14).map((p) => p.syntheticId) },
    { id: "synpool_2026_2027_vandijk", name: "Familie Van Dijk", kind: "competition", isPublic: false, access: "wachtwoord", division: "A+B", predictionScope: "both", passwordPlan: "secret-at-apply; niet in manifest/logs", memberIds: pick(["syn_2026_2027_004", "syn_2026_2027_005", "syn_2026_2027_006"]) },
    { id: "synpool_2026_2027_derdehelft", name: "De Derde Helft", kind: "competition", isPublic: false, access: "wachtwoord", division: "B", predictionScope: "matches", passwordPlan: "secret-at-apply; niet in manifest/logs", memberIds: bPlayers.slice(12, 17).map((p) => p.syntheticId) },
  ];
  for (const pool of pools) {
    pool.creatorSyntheticId = pool.memberIds[0];
    pool.members = pool.memberIds.map((id) => ({ syntheticId: id, displayName: byId.get(id).displayName, role: id === pool.creatorSyntheticId ? "eigenaar" : "deelnemer" }));
  }
  const currentClubNames = new Set(strengths.map((club) => normalize(club.name)));
  const errors = [];
  for (const pool of pools) {
    if (!pool.memberIds.length) errors.push(`${pool.name}: geen deelnemers`);
    if (new Set(pool.memberIds).size !== pool.memberIds.length) errors.push(`${pool.name}: dubbele deelnemer`);
    if (pool.teamName && !currentClubNames.has(normalize(pool.teamName))) errors.push(`${pool.name}: ongeldig team ${pool.teamName}`);
    if (!pool.memberIds.includes(pool.creatorSyntheticId)) errors.push(`${pool.name}: creator is geen deelnemer`);
  }
  return { pools, validation: { valid: errors.length === 0, errors, poolCount: pools.length, uniqueParticipants: new Set(pools.flatMap((pool) => pool.memberIds)).size, usersWithoutPool: players.filter((player) => !pools.some((pool) => pool.memberIds.includes(player.syntheticId))).map((player) => player.syntheticId) } };
}
function finalStandingFor(player, division, strengths) {
  const profileNoise = { strengthFollower: 3.8, conservative: 5.0, homeBias: 5.8, supporterBias: 6.2, upsetProne: 10.0, goalHeavy: 7.0, goalLight: 6.5 };
  const clubs = strengths.filter((club) => club.division === division);
  return clubs.map((club) => {
    const rng = rngFor(player.syntheticId, division, club.name, "final-standing");
    let score = club.strengthRating + gaussian(rng) * profileNoise[player.predictionProfile];
    if (player.predictionProfile === "supporterBias" && club.name === player.favoriteClub) score += 7;
    if (player.predictionProfile === "upsetProne") score += gaussian(rng) * 2.5;
    // Lower-confidence clubs vary more, but priors prevent automatic extremes.
    score += gaussian(rng) * (1 - club.confidence) * 4.5;
    return { club: club.name, score };
  }).sort((a, b) => b.score - a.score || a.club.localeCompare(b.club)).map((row) => row.club);
}

function poisson(lambda, rng) {
  const limit = Math.exp(-lambda);
  let product = 1; let value = 0;
  do { value += 1; product *= rng(); } while (product > limit && value < 9);
  return value - 1;
}

function predictMatch(player, match, home, away) {
  const rng = rngFor(player.syntheticId, match.id, "match");
  const diff = (home.strengthRating - away.strengthRating) / 50;
  let homeLambda = 1.43 * Math.exp(diff * 0.72 + 0.10);
  let awayLambda = 1.15 * Math.exp(-diff * 0.72);
  switch (player.predictionProfile) {
    case "homeBias": homeLambda *= 1.18; awayLambda *= 0.94; break;
    case "conservative": homeLambda *= 0.88; awayLambda *= 0.88; break;
    case "upsetProne": {
      const upset = gaussian(rng) * 0.22; homeLambda *= Math.exp(-upset); awayLambda *= Math.exp(upset); break;
    }
    case "goalHeavy": homeLambda *= 1.28; awayLambda *= 1.28; break;
    case "goalLight": homeLambda *= 0.74; awayLambda *= 0.74; break;
    case "supporterBias":
      if (home.name === player.favoriteClub) homeLambda *= 1.22;
      if (away.name === player.favoriteClub) awayLambda *= 1.22;
      break;
  }
  homeLambda = clamp(homeLambda, 0.35, 3.25); awayLambda = clamp(awayLambda, 0.25, 3.0);
  return { homeGoals: Math.min(6, poisson(homeLambda, rng)), awayGoals: Math.min(6, poisson(awayLambda, rng)), homeLambda, awayLambda };
}

function matchFields(match) {
  return {
    division: String(match.division || match.competition || match.competitie || "").replace(/.*([AB])$/, "$1").toUpperCase(),
    round: Number(match.round || match.speelronde || 0),
    home: String(match.homeTeamName || match.homeTeam || match.thuisteam || ""),
    away: String(match.awayTeamName || match.awayTeam || match.uitteam || ""),
  };
}

function identityResearch(inputs) {
  const currentDisplayNames = new Set(inputs.liveUsers.map((u) => normalize(u.displayName || u.username)).filter(Boolean));
  const currentUsernames = new Set([
    ...inputs.liveUsers.map((u) => normalize(u.username || u.usernameKey)),
    ...inputs.usernames.flatMap((u) => [normalize(u.id), normalize(u.username)]),
  ].filter(Boolean));
  const oldNames = inputs.oldFakeUsers.map((u) => String(u.displayName || u.username || "")).filter(Boolean);
  const nameFrequency = {};
  for (const name of oldNames) nameFrequency[name] = (nameFrequency[name] || 0) + 1;
  return {
    oldFakeSourceCount: inputs.oldFakeUsers.length,
    oldUniqueDisplayNames: new Set(oldNames.map(normalize)).size,
    oldDuplicateDisplayNameGroups: Object.entries(nameFrequency).filter(([, count]) => count > 1).length,
    reservedCurrentDisplayNames: currentDisplayNames.size,
    reservedCurrentUsernames: currentUsernames.size,
    forbiddenLegacyClubTokens: ["aswh", "hsc21", "huizen", "kloetinge", "rohdaraalte", "scheveningen", "stedoco", "urk", "meerssen"],
    proposedAlgorithm: [
      "Gebruik oude fake namen alleen als bronpool; herstel geen UID of account.",
      "Maak quota per voor- en achternaam (maximaal 2 keer elk) en unieke combinaties.",
      "Verwijder clubtags die niet voorkomen in seasons/2026-2027/teams.",
      "Normaliseer case/diakritiek/interpunctie en reserveer live users + usernames vooraf.",
      "Genereer username deterministisch; retry met suffix totdat displayName en username beide uniek zijn.",
      "Validate beÃ«indigt de run bij Ã©Ã©n resterende botsing of scheve naamfrequentie.",
    ],
  };
}

function buildReport(inputs, strengths, players) {
  const teamValidation = validateTeamData(inputs, strengths);
  const poolPlan = buildPools(players, strengths);
  const active = players.filter((player) => !player.isIdle);
  const finalPredictions = [];
  for (const player of active) for (const division of player.competitions) {
    finalPredictions.push({ syntheticId: player.syntheticId, displayName: player.displayName, username: player.username, profile: player.predictionProfile, division, ranking: finalStandingFor(player, division, strengths) });
  }

  const finalStats = {};
  for (const division of ["A", "B"]) {
    const predictions = finalPredictions.filter((row) => row.division === division);
    finalStats[division] = strengths.filter((club) => club.division === division).map((club) => {
      const positions = predictions.map((row) => row.ranking.indexOf(club.name) + 1);
      return { club: club.name, averagePosition: round(mean(positions), 2), highestPosition: Math.min(...positions), lowestPosition: Math.max(...positions), top3: positions.filter((p) => p <= 3).length, bottom3: positions.filter((p) => p >= 16).length };
    }).sort((a, b) => a.averagePosition - b.averagePosition);
  }

  const hasFinalResult = (match) => {
    const status = String(match.status || "").toLowerCase();
    const homeScore = match.homeScore ?? match.uitslagThuis;
    const awayScore = match.awayScore ?? match.uitslagUit;
    return status === "finished" || status === "completed" || (homeScore != null && awayScore != null);
  };
  const eligibleMatches = inputs.matches.map((match) => ({ raw: match, ...matchFields(match) }))
    .filter((match) => ["A", "B"].includes(match.division) && match.round >= 1 && match.round <= 34 && !hasFinalResult(match.raw))
    .sort((a, b) => a.round - b.round || a.division.localeCompare(b.division) || a.raw.id.localeCompare(b.raw.id));
  const matchPredictions = [];
  const matchWarnings = [];
  for (const match of eligibleMatches) {
    const home = strengths.find((club) => club.division === match.division && club.aliases.has(normalize(match.home)));
    const away = strengths.find((club) => club.division === match.division && club.aliases.has(normalize(match.away)));
    if (!home || !away) throw new Error(`Geen strength match voor ${match.division}: ${match.home} - ${match.away}`);
    const eligible = active.filter((player) => player.competitions.includes(match.division));
    const rows = eligible.map((player) => ({ syntheticId: player.syntheticId, displayName: player.displayName, username: player.username, profile: player.predictionProfile, ...predictMatch(player, match.raw, home, away) }));
    const outcomes = rows.map((row) => row.homeGoals === row.awayGoals ? "X" : row.homeGoals > row.awayGoals ? "1" : "2");
    const distribution = { "1": outcomes.filter((x) => x === "1").length, X: outcomes.filter((x) => x === "X").length, "2": outcomes.filter((x) => x === "2").length };
    const maxShare = Math.max(...Object.values(distribution)) / rows.length;
    if (maxShare > 0.80) matchWarnings.push(`${match.division} ${match.home}-${match.away}: ${round(maxShare * 100, 1)}% dezelfde 1/X/2-uitkomst`);
    matchPredictions.push({ matchId: match.raw.id, round: match.round, division: match.division, home: match.home, away: match.away, distribution, averageScore: `${round(mean(rows.map((r) => r.homeGoals)), 2)}-${round(mean(rows.map((r) => r.awayGoals)), 2)}`, predictions: rows.map(({ homeLambda, awayLambda, ...row }) => row) });
  }

  const strengthTables = Object.fromEntries(["A", "B"].map((division) => [division,
    strengths.filter((club) => club.division === division).sort((a, b) => b.strengthRating - a.strengthRating).map((club, index) => ({ strengthPosition: index + 1, club: club.name, strengthRating: club.strengthRating, historicalBasis: club.historicalBasis, confidence: round(club.confidence, 2), entryType: club.entryType }))
  ]));

  const logicalChecks = [];
  for (const division of ["A", "B"]) {
    const rows = strengthTables[division];
    for (const row of rows) {
      if (row.entryType === "promotedFromTier5" && row.strengthPosition === 1) logicalChecks.push(`WAARSCHUWING: promovendus ${row.club} staat als absolute topfavoriet.`);
      if (row.entryType === "relegatedFromTier3" && row.strengthPosition >= 16) logicalChecks.push(`WAARSCHUWING: degradant ${row.club} staat onlogisch in onderste drie.`);
    }
  }
  if (!logicalChecks.length) logicalChecks.push("OK: geen promovendus is absolute topfavoriet en geen degradant uit Tweede Divisie staat in de onderste drie.");

  const displayKeys = players.map((player) => normalize(player.displayName));
  const usernameKeys = players.map((player) => normalize(player.username));
  const oldUidSet = new Set(inputs.oldFakeUsers.map((user) => user.id));
  const inheritedIds = new Set([...inputs.inheritedPilot.identities.map((item) => item.syntheticId), ...inputs.liveUsers.filter((user) => user.syntheticRunId === RUN_ID).map((user) => user.id)]);
  const inheritedUsernameKeys = new Set([...inputs.inheritedPilot.identities.map((item) => normalize(item.username)), ...inputs.usernames.filter((item) => item.syntheticRunId === RUN_ID).map((item) => item.id)]);
  const liveDisplayKeys = new Set(inputs.liveUsers.filter((user) => !inheritedIds.has(user.id)).map((user) => normalize(user.displayName || user.username)).filter(Boolean));
  const liveUsernameKeys = new Set([...inputs.liveUsers.filter((user) => !inheritedIds.has(user.id)).flatMap((user) => [normalize(user.username), normalize(user.usernameKey)]), ...inputs.usernames.filter((user) => !inheritedUsernameKeys.has(user.id)).flatMap((user) => [normalize(user.id), normalize(user.username)])].filter(Boolean));
  const surnameCounts = {};
  for (const player of players) { const surname = player.displayName.split(/\s+/).at(-1); surnameCounts[surname] = (surnameCounts[surname] || 0) + 1; }
  const identityErrors = [];
  if (new Set(players.map((p) => p.syntheticId)).size !== 50) identityErrors.push("syntheticId niet uniek");
  if (players.some((p) => oldUidSet.has(p.syntheticId))) identityErrors.push("oude fake UID hergebruikt");
  if (new Set(displayKeys).size !== 50) identityErrors.push("displayName niet uniek");
  if (new Set(usernameKeys).size !== 50) identityErrors.push("username niet uniek");
  if (displayKeys.some((key) => liveDisplayKeys.has(key))) identityErrors.push("displayName botst met huidige user");
  if (usernameKeys.some((key) => liveUsernameKeys.has(key))) identityErrors.push("username botst met users/usernames");
  const legacyTokens = ["aswh", "hsc21", "huizen", "kloetinge", "rohdaraalte", "scheveningen", "stedoco", "urk", "meerssen"];
  if (players.some((p) => legacyTokens.some((token) => normalize(p.username).includes(token)))) identityErrors.push("username bevat verouderde clubtag");
  const identityValidation = { valid: identityErrors.length === 0, errors: identityErrors, uniqueSyntheticIds: new Set(players.map((p) => p.syntheticId)).size, oldUidReuse: players.filter((p) => oldUidSet.has(p.syntheticId)).length, uniqueDisplayNames: new Set(displayKeys).size, uniqueUsernames: new Set(usernameKeys).size, currentDisplayNameCollisions: displayKeys.filter((key) => liveDisplayKeys.has(key)).length, currentUsernameCollisions: usernameKeys.filter((key) => liveUsernameKeys.has(key)).length, surnameCounts, intentionalFamilyException: { surname: "van Dijk", members: ["Lisa van Dijk", "Tom van Dijk", "Noor van Dijk"] } };
  const predictionsByUser = players.map((player) => {
    const predictions = matchPredictions.flatMap((match) => match.predictions.filter((prediction) => prediction.syntheticId === player.syntheticId).map(() => match));
    const ids = predictions.map((match) => match.matchId);
    const relevant = eligibleMatches.filter((match) => player.competitions.includes(match.division));
    const errors = [];
    if (player.isIdle && ids.length) errors.push("idle user heeft predictions");
    if (!player.isIdle && ids.length !== relevant.length) errors.push(`ontbrekend: verwacht ${relevant.length}, kreeg ${ids.length}`);
    if (new Set(ids).size !== ids.length) errors.push("dubbele matchId");
    if (predictions.some((match) => !player.competitions.includes(match.division))) errors.push("verkeerde divisie");
    if (predictions.some((match) => hasFinalResult(inputs.matches.find((source) => source.id === match.matchId)))) errors.push("prediction voor gespeelde wedstrijd");
    return { syntheticId: player.syntheticId, competitions: player.competitions, isIdle: player.isIdle, predictions: ids.length, errors };
  });
  const predictionsByRound = Object.fromEntries(Array.from({ length: 34 }, (_, index) => index + 1).map((roundNumber) => [roundNumber, matchPredictions.filter((match) => match.round === roundNumber).reduce((sum, match) => sum + match.predictions.length, 0)]));
  const relevantMatchesByDivision = Object.fromEntries(["A", "B"].map((division) => [division, eligibleMatches.filter((match) => match.division === division).length]));
  const predictionCoverage = {
    activeAOnlyUsers: active.filter((player) => player.competitions.length === 1 && player.competitions[0] === "A").length,
    activeBOnlyUsers: active.filter((player) => player.competitions.length === 1 && player.competitions[0] === "B").length,
    activeABUsers: active.filter((player) => player.competitions.length === 2).length,
    idleUsers: players.filter((player) => player.isIdle).length,
    relevantMatchesByDivision,
    playedMatchesExcluded: inputs.matches.length - eligibleMatches.length,
    totalPredictions: matchPredictions.reduce((sum, match) => sum + match.predictions.length, 0),
    predictionsByUser,
    predictionsByRound,
    validation: { valid: predictionsByUser.every((row) => row.errors.length === 0), errors: predictionsByUser.flatMap((row) => row.errors.map((error) => `${row.syntheticId}: ${error}`)) },
  };
  const manifestPaths = {
    userDocumentPaths: players.map((p) => `users/${p.syntheticId}`),
    usernameIndexPaths: players.map((p) => `usernames/${normalize(p.username)}`),
    predictionDocumentPaths: matchPredictions.flatMap((match) => match.predictions.map((p) => `seasons/${SEASON}/predictions/${p.syntheticId}_${match.matchId}`)),
    finalStandingDocumentPaths: finalPredictions.map((p) => `eindstand_voorspellingen/${p.syntheticId}_${p.division}`),
    pouleDocumentPaths: poolPlan.pools.flatMap((pool) => [`poules/${pool.id}`, ...pool.memberIds.flatMap((uid) => [`poules/${pool.id}/deelnemers/${uid}`, `users/${uid}/poules/${pool.id}`])]),
  };
  const effectiveDatasetForHash = {
    runId: RUN_ID,
    teams: strengths.map((club) => ({ name: club.name, division: club.division, strengthRating: club.strengthRating })),
    identities: players.map(({ syntheticId, displayName, username, competitions, predictionProfile, isIdle }) => ({ syntheticId, displayName, username, competitions, predictionProfile, isIdle })),
    finalStandings: finalPredictions.map(({ syntheticId, division, ranking }) => ({ syntheticId, division, ranking })),
    matchPredictions: matchPredictions.flatMap((match) => match.predictions.map(({ syntheticId, homeGoals, awayGoals }) => ({ syntheticId, matchId: match.matchId, division: match.division, homeGoals, awayGoals }))),
    pools: poolPlan.pools.map(({ id, name, kind, isPublic, division, teamName, predictionScope, memberIds, creatorSyntheticId }) => ({ id, name, kind, isPublic, division, teamName, predictionScope, memberIds, creatorSyntheticId })),
  };
  const configHash = crypto.createHash("sha256").update(JSON.stringify(effectiveDatasetForHash)).digest("hex");

  return {
    dryRun: true, projectId: PROJECT_ID, season: SEASON, runId: RUN_ID, seed: MASTER_SEED, legacyConfigHash: LEGACY_CONFIG_HASH,
    writes: { firestore: 0, authentication: 0 },
    validation: { valid: teamValidation.valid && identityValidation.valid && poolPlan.validation.valid && inputs.inheritedPilot.valid && predictionCoverage.validation.valid, teamData: teamValidation, identities: identityValidation, inheritedPilot: inputs.inheritedPilot, pools: poolPlan.validation },
    predictionCoverage,
    sources: { standingsArchiveSeasons: [...new Set(inputs.historical.map((row) => row.season))].sort(), historicalStandingRows: inputs.historical.length, currentTeams: inputs.teams.length, currentMatches: inputs.matches.length, eligibleUnplayedMatches: eligibleMatches.length, playedMatchesExcluded: inputs.matches.length - eligibleMatches.length, seasonArchive2025_26UsedAsCrossCheck: true },
    strengthModel: { formula: "60% season-relative PPG percentile + 25% GD/game percentile + 15% position percentile; recency weighting; confidence shrinkage to entry-type prior; normalized 35..85 per current division", incompleteSeasonsDownweighted: ["2019-2020", "2020-2021"], tables: strengthTables, manualLogicalChecks: logicalChecks },
    players: { count: players.length, active: active.length, idle: players.length - active.length, byCompetition: { A: players.filter((p) => p.competitions.join("+") === "A").length, B: players.filter((p) => p.competitions.join("+") === "B").length, "A+B": players.filter((p) => p.competitions.length === 2).length }, byProfile: Object.fromEntries(PROFILE_PLAN.map(([profile]) => [profile, players.filter((p) => p.predictionProfile === profile).length])), rows: players },
    pools: poolPlan.pools,
    finalStandings: { count: finalPredictions.length, predictions: finalPredictions, statistics: finalStats },
    fullSeasonPredictions: { matches: matchPredictions, warningsOver80Percent: matchWarnings },
    roundOnePredictions: { matches: matchPredictions.filter((match) => match.round === 1), warningsOver80Percent: matchWarnings },
    identityResearch: identityResearch(inputs),
    eligibilityAudit: {
      ranking: "BEWUST: ranking_screen leest alle users; synthetische users worden normaal tussen deelnemers getoond.",
      socialWinners: "BEWUST: social_media_models neemt synthetische users mee; er wordt geen filter toegevoegd.",
      internalAnalytics: "Geen Auth of gesimuleerde activity events; datasetwrites zelf genereren geen clientanalytics.",
      ga4: "Niet van toepassing zolang geen Auth-accounts of interactieve sessies worden gemaakt.",
      priceLogic: "Geen prijslogica of prijsveld toegevoegd, conform besluit.",
    },
    futureApplyPlan: {
      lifecycle: ["dry-run", "validate", "explicit --apply", "verify"],
      requiredMarkers: { isFake: true, accountType: "synthetic", syntheticSeason: SEASON, syntheticRunId: RUN_ID },
      manifest: { proposedPath: `synthetic_runs/${RUN_ID}`, runId: RUN_ID, seasonId: SEASON, configHash, createdAt: "server timestamp bij apply", paths: manifestPaths, verificationCounts: { users: players.length, usernameIndexes: players.length, predictions: manifestPaths.predictionDocumentPaths.length, finalStandings: manifestPaths.finalStandingDocumentPaths.length, poolsAndMembershipIndexes: manifestPaths.pouleDocumentPaths.length } },
      safeguards: ["Admin SDK trusted script; geen client-seeder", "default altijd dry-run", "--apply vereist plus expliciete projectId-check derde-divisie-app", "validatie vóór iedere write", "stop bij usernamebotsing, bestaand doelpad, verkeerde teamset of afwijkende aantallen", "idempotente deterministische IDs", "logische batches onder Firestorelimiet; manifest als laatste alleen na succesvolle databatches", "verify leest ieder manifestpad terug", "cleanup selecteert exact manifest + syntheticRunId, nooit alle isFake users"],
    },
  };
}

async function validatePlannedPaths(report) {
  const pathGroups = report.futureApplyPlan.manifest.paths;
  const allPaths = [
    ...pathGroups.userDocumentPaths,
    ...pathGroups.usernameIndexPaths,
    ...pathGroups.predictionDocumentPaths,
    ...pathGroups.finalStandingDocumentPaths,
    ...pathGroups.pouleDocumentPaths,
    `synthetic_runs/${RUN_ID}`,
  ];
  const uniquePaths = [...new Set(allPaths)];
  const duplicatePlannedPaths = allPaths.filter((path, index) => allPaths.indexOf(path) !== index);
  const pilotManifestSnap = await db.doc(`synthetic_runs/${PILOT_RUN_ID}`).get();
  const inheritedPaths = new Set(pilotManifestSnap.exists && pilotManifestSnap.data().status === "verified" ? pilotManifestSnap.data().allDocumentPaths || [] : []);
  const inheritedExistingPaths = [];
  const existingPaths = [];
  for (let index = 0; index < uniquePaths.length; index += 100) {
    const snapshots = await db.getAll(...uniquePaths.slice(index, index + 100).map((path) => db.doc(path)));
    for (const snapshot of snapshots) if (snapshot.exists) {
      if (inheritedPaths.has(snapshot.ref.path) || snapshot.data().syntheticRunId === RUN_ID) inheritedExistingPaths.push(snapshot.ref.path);
      else existingPaths.push(snapshot.ref.path);
    }
  }
  const existingPoolNames = [];
  for (const pool of report.pools) {
    const snapshot = await db.collection("poules").where("name", "==", pool.name).limit(1).get();
    if (!snapshot.empty) existingPoolNames.push(pool.name);
  }
  const errors = [];
  if (duplicatePlannedPaths.length) errors.push(`Dubbele geplande documentpaden: ${[...new Set(duplicatePlannedPaths)].join(", ")}`);
  if (existingPaths.length) errors.push(`Bestaande doelpaden: ${existingPaths.join(", ")}`);
  if (existingPoolNames.length) errors.push(`Bestaande poulenamen: ${existingPoolNames.join(", ")}`);
  return { valid: errors.length === 0, plannedPathCount: allPaths.length, uniquePlannedPathCount: uniquePaths.length, inheritedExistingPaths, duplicatePlannedPaths: [...new Set(duplicatePlannedPaths)], existingPaths, existingPoolNames, errors };
}
function printHuman(report) {
  console.log("STRICT DRY RUN â€” SYNTHETISCHE VOORSPELLER 2026/2027");
  console.log(`Project=${report.projectId} runId=${report.runId} Firestore writes=0 Auth writes=0\n`);
  for (const division of ["A", "B"]) {
    console.log(`FASE 1 â€” CLUBSTERKTE DIVISIE ${division}`);
    console.table(report.strengthModel.tables[division]);
  }
  console.log("HANDMATIGE LOGICACONTROLE"); console.log(report.strengthModel.manualLogicalChecks.join("\n"));
  console.log("\nFASE 2 â€” SPELERS"); console.table(report.players.rows);
  console.log("\nFASE 3 — POULES"); console.log(JSON.stringify(report.pools, null, 2));
  console.log("\nFASE 4 — ALLE EINDSTANDVOORSPELLINGEN");
  for (const row of report.finalStandings.predictions) console.log(`${row.syntheticId} | ${row.profile} | ${row.division} | ${row.ranking.map((club, i) => `${i + 1}.${club}`).join(" > ")}`);
  for (const division of ["A", "B"]) { console.log(`\nEINDSTANDSTATISTIEKEN ${division}`); console.table(report.finalStandings.statistics[division]); }
  console.log("\nFASE 4 — SPEELRONDE 1");
  for (const match of report.fullSeasonPredictions.matches.filter((item) => item.round === 1)) {
    console.log(`\n${match.division} ${match.matchId}: ${match.home} - ${match.away} | 1/X/2=${match.distribution["1"]}/${match.distribution.X}/${match.distribution["2"]} | gem. ${match.averageScore}`);
    for (const row of match.predictions) console.log(`  ${row.syntheticId} | ${row.profile} | ${row.homeGoals}-${row.awayGoals}`);
  }
  console.log("\n>80%-WAARSCHUWINGEN"); console.log(report.roundOnePredictions.warningsOver80Percent.length ? report.roundOnePredictions.warningsOver80Percent.join("\n") : "Geen.");
  console.log("\nVALIDATIES"); console.log(JSON.stringify(report.validation, null, 2));
  console.log("\nFASE 5 — IDENTITEIT"); console.log(JSON.stringify(report.identityResearch, null, 2));
  console.log("\nFASE 6 — APPLY/ELIGIBILITY PLAN"); console.log(JSON.stringify({ eligibilityAudit: report.eligibilityAudit, futureApplyPlan: report.futureApplyPlan }, null, 2));
  console.log("\nMACHINE-READABLE FULL REPORT"); console.log(JSON.stringify(report, null, 2));
  console.log("\nDRY RUN VOLTOOID â€” Firestore writes: 0; Authentication writes: 0");
}

async function main() {
  if (process.argv.includes("--apply")) throw new Error("Dit script ondersteunt opzettelijk geen --apply.");
  const inputs = await loadInputs();
  const strengths = buildStrengths(inputs);
  const players = buildPlayers(strengths, inputs);
  const report = buildReport(inputs, strengths, players);
  report.validation.plannedPaths = await validatePlannedPaths(report);
  report.validation.valid = report.validation.valid && report.validation.plannedPaths.valid;
  printHuman(report);
}

main().catch((error) => { console.error("DRY RUN MISLUKT:", error); process.exitCode = 1; });












