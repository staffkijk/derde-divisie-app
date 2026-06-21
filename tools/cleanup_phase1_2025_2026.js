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

const DRY_RUN = false;

const COLLECTIONS_TO_DELETE = [
  "voorspellingen",
  "poule_predictions",
  "poule_voorspellingen",
  "predictions",
  "eindstand_voorspellingen",
  "voorspel_punten",
  "round_overrides",
  "periodestanden",
];

const PROTECTED_COLLECTIONS = new Set([
  "users",
  "app_updates",
  "season_archives",
  "standings_archive",
  "matches",
  "standen",
  "poules",
  "x_posts",
  "maintenance",
  "system",
  "sync_logs",
  "usernames",
]);

async function countCollection(collectionName) {
  const snap = await db.collection(collectionName).get();
  return snap.size;
}

async function deleteCollection(collectionName, batchSize = 300) {
  if (PROTECTED_COLLECTIONS.has(collectionName)) {
    throw new Error(`Beveiligde collectie wordt niet verwijderd: ${collectionName}`);
  }

  let totalDeleted = 0;

  while (true) {
    const snap = await db.collection(collectionName).limit(batchSize).get();

    if (snap.empty) {
      break;
    }

    if (DRY_RUN) {
      totalDeleted += snap.size;
      console.log(`[DRY RUN] ${collectionName}: zou ${snap.size} documenten verwijderen`);
      break;
    }

    const batch = db.batch();

    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit();

    totalDeleted += snap.size;

    console.log(`${collectionName}: ${totalDeleted} documenten verwijderd`);

    if (snap.size < batchSize) {
      break;
    }
  }

  return totalDeleted;
}

async function writeCleanupLog(summary) {
  await db.collection("maintenance").doc("cleanup_phase1_2025_2026").set(
    {
      type: "cleanup_phase1_2025_2026",
      dryRun: DRY_RUN,
      collections: COLLECTIONS_TO_DELETE,
      summary,
      createdAt: FieldValue.serverTimestamp(),
      note: "Fase 1 opschoning na archivering seizoen 2025/2026. Users, archief, matches, standen, poules, x_posts, app_updates en systemdata zijn niet verwijderd.",
    },
    { merge: true }
  );
}

async function main() {
  console.log("Start cleanup fase 1 seizoen 2025/2026");
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  console.log("Collecties die verwijderd worden:");
  console.table(COLLECTIONS_TO_DELETE);

  console.log("");
  console.log("Vooraf tellen...");

  const beforeCounts = {};

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    beforeCounts[collectionName] = await countCollection(collectionName);
  }

  console.table(beforeCounts);

  console.log("");
  console.log("Verwijderen gestart...");

  const deletedCounts = {};

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    deletedCounts[collectionName] = await deleteCollection(collectionName);
  }

  console.log("");
  console.log("Achteraf tellen...");

  const afterCounts = {};

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    afterCounts[collectionName] = await countCollection(collectionName);
  }

  console.table(afterCounts);

  const summary = {
    beforeCounts,
    deletedCounts,
    afterCounts,
  };

  await writeCleanupLog(summary);

  console.log("");
  console.log("Cleanup fase 1 klaar.");
  console.log(JSON.stringify(summary, null, 2));

  process.exit(0);
}

main().catch((error) => {
  console.error("Cleanup fase 1 mislukt:");
  console.error(error);
  process.exit(1);
});