/* eslint-disable no-console */

const { initializeApp, getApps, applicationDefault } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
    projectId: "derde-divisie-app",
  });
}

const db = getFirestore();

const KNOWN_COLLECTIONS = [
  "users",
  "usernames",
  "teams",
  "matches",
  "poules",
  "x_posts",
  "app_config",
  "config",
  "standings",
  "periodestanden",
  "voorspellingen",
  "poule_predictions",
  "poule_voorspellingen",
  "predictions",
  "eindstand_voorspellingen",
  "voorspel_punten",
  "round_overrides",
  "season_archives",
  "archives",
  "seasons",
];

const SAMPLE_LIMIT = 3;

async function countCollection(collectionName) {
  const snap = await db.collection(collectionName).count().get();
  return snap.data().count || 0;
}

async function getSampleDocs(collectionName) {
  const snap = await db.collection(collectionName).limit(SAMPLE_LIMIT).get();

  return snap.docs.map((doc) => {
    const data = doc.data();

    return {
      id: doc.id,
      fields: Object.keys(data).sort(),
      preview: makeSmallPreview(data),
    };
  });
}

function makeSmallPreview(data) {
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
    return value.length > 80 ? `${value.substring(0, 80)}...` : value;
  }

  if (typeof value === "number" || typeof value === "boolean") {
    return value;
  }

  if (Array.isArray(value)) {
    return `[array length ${value.length}]`;
  }

  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }

  if (typeof value === "object") {
    return `[object keys: ${Object.keys(value).join(", ")}]`;
  }

  return String(value);
}

async function listTopLevelCollections() {
  const collections = await db.listCollections();
  return collections.map((collection) => collection.id).sort();
}

async function inspectCollection(collectionName) {
  const count = await countCollection(collectionName);
  const samples = count > 0 ? await getSampleDocs(collectionName) : [];

  return {
    collection: collectionName,
    count,
    samples,
  };
}

async function inspectArchiveRoots() {
  const result = [];

  const possibleRoots = ["season_archives", "archives", "seasons"];

  for (const root of possibleRoots) {
    const rootCount = await countCollection(root);

    if (rootCount === 0) {
      result.push({
        root,
        exists: false,
        count: 0,
        note: "Geen documenten gevonden",
      });
      continue;
    }

    const rootSnap = await db.collection(root).limit(20).get();

    const docs = [];

    for (const doc of rootSnap.docs) {
      const subcollections = await doc.ref.listCollections();

      docs.push({
        id: doc.id,
        fields: Object.keys(doc.data()).sort(),
        subcollections: subcollections.map((sub) => sub.id).sort(),
      });
    }

    result.push({
      root,
      exists: true,
      count: rootCount,
      docs,
    });
  }

  return result;
}

async function main() {
  console.log("Firestore inventory");
  console.log("Dit script telt en leest voorbeelden. Het verwijdert niets.");
  console.log("");

  const liveCollections = await listTopLevelCollections();

  console.log("Live top-level collecties:");
  console.table(liveCollections.map((name) => ({ collection: name })));

  const allCollections = Array.from(
    new Set([...KNOWN_COLLECTIONS, ...liveCollections])
  ).sort();

  console.log("");
  console.log("Aantallen per collectie:");

  const inventory = [];

  for (const collectionName of allCollections) {
    try {
      const info = await inspectCollection(collectionName);

      inventory.push({
        collection: info.collection,
        count: info.count,
        sampleCount: info.samples.length,
      });
    } catch (error) {
      inventory.push({
        collection: collectionName,
        count: "ERROR",
        sampleCount: 0,
        error: error.message,
      });
    }
  }

  console.table(inventory);

  console.log("");
  console.log("Voorbeelden per collectie:");

  for (const collectionName of allCollections) {
    try {
      const info = await inspectCollection(collectionName);

      console.log("");
      console.log(`Collectie: ${collectionName}`);
      console.log(`Aantal: ${info.count}`);

      if (info.samples.length === 0) {
        console.log("Geen voorbeeld-documenten.");
      } else {
        console.dir(info.samples, { depth: 6 });
      }
    } catch (error) {
      console.log("");
      console.log(`Collectie: ${collectionName}`);
      console.log(`Fout: ${error.message}`);
    }
  }

  console.log("");
  console.log("Controle archief/seizoensstructuren:");

  const archiveInfo = await inspectArchiveRoots();
  console.dir(archiveInfo, { depth: 8 });

  console.log("");
  console.log("Inventory klaar. Er is niets verwijderd.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Inventory mislukt:");
    console.error(error);
    process.exit(1);
  });