/* eslint-disable no-console */

const { initializeApp, getApps, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

/**
 * Zet eerst op true.
 * Als de controle goed is, zet je deze op false en draai je het script opnieuw.
 */
const DRY_RUN = false;

const COLLECTIONS_TO_DELETE = [
  "matches",
  "standen",
  "poules",
];

async function countCollection(collectionName) {
  const snap = await db.collection(collectionName).count().get();
  return snap.data().count || 0;
}

async function getSampleDocs(collectionName, limit = 5) {
  const snap = await db.collection(collectionName).limit(limit).get();

  return snap.docs.map((doc) => ({
    id: doc.id,
    data: simplifyObject(doc.data()),
  }));
}

function simplifyObject(data) {
  const result = {};

  for (const [key, value] of Object.entries(data)) {
    result[key] = simplifyValue(value);
  }

  return result;
}

function simplifyValue(value) {
  if (value === null || value === undefined) {
    return value;
  }

  if (typeof value === "string") {
    return value.length > 100 ? `${value.substring(0, 100)}...` : value;
  }

  if (typeof value === "number" || typeof value === "boolean") {
    return value;
  }

  if (Array.isArray(value)) {
    return `[array length ${value.length}]`;
  }

  if (typeof value?.toDate === "function") {
    return value.toDate().toISOString();
  }

  if (typeof value === "object") {
    return `[object keys: ${Object.keys(value).join(", ")}]`;
  }

  return String(value);
}

async function deleteCollectionRecursively(collectionName) {
  const collectionRef = db.collection(collectionName);
  const snap = await collectionRef.get();

  let deleted = 0;

  for (const doc of snap.docs) {
    if (DRY_RUN) {
      deleted += 1;
      continue;
    }

    /**
     * recursiveDelete verwijdert ook eventuele subcollecties onder het document.
     * Dat is vooral belangrijk bij poules, omdat daar mogelijk deelnemers,
     * voorspellingen of andere subdata onder kunnen hangen.
     */
    await db.recursiveDelete(doc.ref);
    deleted += 1;

    if (deleted % 25 === 0) {
      console.log(`${collectionName}: ${deleted} documenten verwijderd...`);
    }
  }

  return deleted;
}

async function writeMaintenanceLog(beforeCounts, deletedCounts, afterCounts) {
  if (DRY_RUN) {
    return;
  }

  await db.collection("maintenance").doc("cleanup_phase2_live_2025_2026").set({
    type: "cleanup_phase2_live_2025_2026",
    dryRun: false,
    createdAt: new Date(),
    note:
      "Fase 2 opschoning na archivering seizoen 2025/2026. Matches, standen en poules zijn uit live Firestore verwijderd. Archieven, users, usernames, x_posts, app_updates, standings_archive en system zijn niet verwijderd.",
    collections: COLLECTIONS_TO_DELETE,
    summary: {
      beforeCounts,
      deletedCounts,
      afterCounts,
    },
  });
}

async function main() {
  console.log("Start cleanup fase 2 live data seizoen 2025/2026");
  console.log(`DRY_RUN = ${DRY_RUN}`);
  console.log("");

  console.log("Collecties die worden beoordeeld:");
  console.table(COLLECTIONS_TO_DELETE);

  console.log("");
  console.log("Vooraf tellen...");

  const beforeCounts = {};

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    beforeCounts[collectionName] = await countCollection(collectionName);
  }

  console.table(beforeCounts);

  console.log("");
  console.log("Voorbeeld-documenten vooraf:");

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    const samples = await getSampleDocs(collectionName);

    console.log("");
    console.log(`Collectie: ${collectionName}`);
    console.dir(samples, { depth: 6 });
  }

  console.log("");
  console.log("Belangrijk:");
  console.log("- season_archives wordt NIET verwijderd");
  console.log("- standings_archive wordt NIET verwijderd");
  console.log("- users wordt NIET verwijderd");
  console.log("- usernames wordt NIET verwijderd");
  console.log("- x_posts wordt NIET verwijderd");
  console.log("- app_updates wordt NIET verwijderd");
  console.log("- system wordt NIET verwijderd");
  console.log("");

  if (DRY_RUN) {
    console.log("DRY_RUN staat op true.");
    console.log("Er is niets verwijderd.");
    console.log("");
    console.log("Als bovenstaande aantallen kloppen, zet dan in dit bestand:");
    console.log("const DRY_RUN = false;");
    console.log("");
    console.log("Daarna opnieuw uitvoeren:");
    console.log("node tools/cleanup_phase2_live_2025_2026.js");
    return;
  }

  console.log("Verwijderen gestart...");

  const deletedCounts = {};

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    deletedCounts[collectionName] = await deleteCollectionRecursively(collectionName);
    console.log(`${collectionName}: ${deletedCounts[collectionName]} documenten verwijderd`);
  }

  console.log("");
  console.log("Achteraf tellen...");

  const afterCounts = {};

  for (const collectionName of COLLECTIONS_TO_DELETE) {
    afterCounts[collectionName] = await countCollection(collectionName);
  }

  console.table(afterCounts);

  await writeMaintenanceLog(beforeCounts, deletedCounts, afterCounts);

  console.log("");
  console.log("Cleanup fase 2 klaar.");
  console.dir(
    {
      beforeCounts,
      deletedCounts,
      afterCounts,
    },
    { depth: 6 }
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Cleanup fase 2 mislukt:");
    console.error(error);
    process.exit(1);
  });