/* eslint-disable no-console */

const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const serviceAccount = require("./serviceAccountKey.json");

if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const db = getFirestore();

const SEASON_ID = "2025-2026";
const ARCHIVE_ROOT = db.collection("season_archives").doc(SEASON_ID);

async function countCollection(ref) {
  const snap = await ref.get();
  return snap.size;
}

async function readDoc(ref) {
  const snap = await ref.get();
  return snap.exists ? snap.data() : null;
}

async function showTopGlobalRanking() {
  const snap = await ARCHIVE_ROOT
    .collection("rankings")
    .doc("global")
    .collection("users")
    .orderBy("rank", "asc")
    .limit(10)
    .get();

  const rows = snap.docs.map((doc) => {
    const data = doc.data();

    return {
      rank: data.rank,
      username: data.username,
      totaalPunten: data.totaalPunten,
      puntenA: data.puntenA,
      puntenB: data.puntenB,
      eindstandPuntenA: data.eindstandPuntenA,
      eindstandPuntenB: data.eindstandPuntenB,
      isFake: data.isFake,
      uid: doc.id,
    };
  });

  console.log("");
  console.log("Top 10 globale ranking in archief:");
  console.table(rows);
}

async function showTopPouleRanking() {
  const snap = await ARCHIVE_ROOT
    .collection("rankings")
    .doc("poules")
    .collection("users")
    .orderBy("rank", "asc")
    .limit(10)
    .get();

  const rows = snap.docs.map((doc) => {
    const data = doc.data();

    return {
      rank: data.rank,
      username: data.username,
      totalPoulePoints: data.totalPoulePoints,
      poulesCount: data.poulesCount,
      isFake: data.isFake,
      uid: doc.id,
    };
  });

  console.log("");
  console.log("Top 10 poule ranking in archief:");
  console.table(rows);
}

async function checkUsernameIndex() {
  const usernamesCount = await countCollection(db.collection("usernames"));

  const usersSnap = await db.collection("users").limit(20).get();

  let usersWithUsernameKey = 0;
  let usersWithUsernameLower = 0;

  for (const doc of usersSnap.docs) {
    const data = doc.data();

    if (data.usernameKey) usersWithUsernameKey += 1;
    if (data.usernameLower) usersWithUsernameLower += 1;
  }

  return {
    usernamesCount,
    sampleUsersChecked: usersSnap.size,
    sampleUsersWithUsernameKey: usersWithUsernameKey,
    sampleUsersWithUsernameLower: usersWithUsernameLower,
  };
}

async function main() {
  console.log("Controle archief seizoen 2025/2026");
  console.log("");

  const archiveMeta = await readDoc(ARCHIVE_ROOT);

  if (!archiveMeta) {
    console.error("FOUT: season_archives/2025-2026 bestaat niet.");
    process.exit(1);
  }

  const globalMeta = await readDoc(
    ARCHIVE_ROOT.collection("rankings").doc("global")
  );

  const poulesMeta = await readDoc(
    ARCHIVE_ROOT.collection("rankings").doc("poules")
  );

  const divisionAMeta = await readDoc(
    ARCHIVE_ROOT.collection("divisions").doc("A")
  );

  const divisionBMeta = await readDoc(
    ARCHIVE_ROOT.collection("divisions").doc("B")
  );

  const counts = {
    usersLive: await countCollection(db.collection("users")),
    usernames: await countCollection(db.collection("usernames")),

    archiveGlobalUsers: await countCollection(
      ARCHIVE_ROOT.collection("rankings").doc("global").collection("users")
    ),

    archivePouleUsers: await countCollection(
      ARCHIVE_ROOT.collection("rankings").doc("poules").collection("users")
    ),

    resultsA: await countCollection(
      ARCHIVE_ROOT.collection("divisions").doc("A").collection("results")
    ),

    resultsB: await countCollection(
      ARCHIVE_ROOT.collection("divisions").doc("B").collection("results")
    ),

    finalStandingsA: await countCollection(
      ARCHIVE_ROOT.collection("divisions").doc("A").collection("final_standings")
    ),

    finalStandingsB: await countCollection(
      ARCHIVE_ROOT.collection("divisions").doc("B").collection("final_standings")
    ),

    xPostsLatest: await countCollection(
      ARCHIVE_ROOT.collection("x_posts_latest")
    ),
  };

  const expected = {
    usersLive: 520,
    archiveGlobalUsers: 520,
    resultsA: 306,
    resultsB: 306,
    finalStandingsA: 18,
    finalStandingsB: 18,
    xPostsLatest: 5,
  };

  console.log("Metadata season archive:");
  console.log(JSON.stringify(archiveMeta, null, 2));

  console.log("");
  console.log("Metadata global ranking:");
  console.log(JSON.stringify(globalMeta, null, 2));

  console.log("");
  console.log("Metadata poules ranking:");
  console.log(JSON.stringify(poulesMeta, null, 2));

  console.log("");
  console.log("Metadata divisie A:");
  console.log(JSON.stringify(divisionAMeta, null, 2));

  console.log("");
  console.log("Metadata divisie B:");
  console.log(JSON.stringify(divisionBMeta, null, 2));

  console.log("");
  console.log("Aantallen:");
  console.table(counts);

  console.log("");
  console.log("Verwachte controles:");

  let hasError = false;

  for (const [key, expectedValue] of Object.entries(expected)) {
    const actualValue = counts[key];

    if (actualValue !== expectedValue) {
      hasError = true;
      console.error(
        `FOUT: ${key} is ${actualValue}, verwacht ${expectedValue}`
      );
    } else {
      console.log(`OK: ${key} = ${actualValue}`);
    }
  }

  const usernameCheck = await checkUsernameIndex();

  console.log("");
  console.log("Username index check:");
  console.table(usernameCheck);

  await showTopGlobalRanking();
  await showTopPouleRanking();

  console.log("");

  if (hasError) {
    console.error("Controle afgerond met fouten. Nog niets verwijderen.");
    process.exit(1);
  }

  console.log("Controle afgerond zonder harde fouten.");
  console.log("Nog steeds niets verwijderen totdat de inhoud visueel is gecontroleerd.");
  process.exit(0);
}

main().catch((error) => {
  console.error("Controle mislukt:");
  console.error(error);
  process.exit(1);
});