const fs = require("fs");
const path = require("path");

const { initializeApp, getApps, cert } = require("firebase-admin/app");
const { getFirestore, Timestamp, GeoPoint, FieldPath } = require("firebase-admin/firestore");

const serviceAccount = require("./serviceAccountKey.json");

if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const db = getFirestore();

const OUTPUT_DIR = path.join(__dirname, "..", "firestore_exports");
const OUTPUT_FILE = path.join(OUTPUT_DIR, "firestore_full_export_safe.json");

const PAGE_SIZE = 300;

const SENSITIVE_KEYS = [
  "email",
  "mail",
  "password",
  "pass",
  "token",
  "secret",
  "apikey",
  "apiKey",
  "auth",
  "phone",
  "tel",
  "telephone",
];

function isSensitiveKey(key) {
  const lower = String(key).toLowerCase();
  return SENSITIVE_KEYS.some((sensitive) =>
    lower.includes(String(sensitive).toLowerCase())
  );
}

function convertValue(key, value) {
  if (isSensitiveKey(key)) {
    return "[REDACTED]";
  }

  if (value === null || value === undefined) {
    return value;
  }

  if (value instanceof Timestamp) {
    return {
      __type: "Timestamp",
      value: value.toDate().toISOString(),
    };
  }

  if (value instanceof GeoPoint) {
    return {
      __type: "GeoPoint",
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }

  if (Buffer.isBuffer(value)) {
    return "[BUFFER]";
  }

  if (Array.isArray(value)) {
    return value.map((item) => convertValue(key, item));
  }

  if (typeof value === "object") {
    const result = {};
    for (const [childKey, childValue] of Object.entries(value)) {
      result[childKey] = convertValue(childKey, childValue);
    }
    return result;
  }

  return value;
}

function convertData(data) {
  const result = {};
  for (const [key, value] of Object.entries(data || {})) {
    result[key] = convertValue(key, value);
  }
  return result;
}

async function exportCollection(collectionRef) {
  const collectionResult = {
    path: collectionRef.path,
    documents: {},
  };

  let lastDoc = null;
  let total = 0;

  while (true) {
    let query = collectionRef
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();

    if (snap.empty) {
      break;
    }

    for (const doc of snap.docs) {
      total++;

      const docResult = {
        id: doc.id,
        data: convertData(doc.data()),
        subcollections: {},
      };

      const subcollections = await doc.ref.listCollections();

      for (const subcollection of subcollections) {
        docResult.subcollections[subcollection.id] =
          await exportCollection(subcollection);
      }

      collectionResult.documents[doc.id] = docResult;
    }

    lastDoc = snap.docs[snap.docs.length - 1];

    console.log(`${collectionRef.path}: ${total} documenten gelezen`);

    if (snap.size < PAGE_SIZE) {
      break;
    }
  }

  collectionResult.count = total;

  return collectionResult;
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const rootCollections = await db.listCollections();

  const exportData = {
    exportedAt: new Date().toISOString(),
    projectNote:
      "Volledige Firestore export voor structuurcontrole. Gevoelige velden zijn gemaskeerd.",
    rootCollections: {},
  };

  for (const collection of rootCollections) {
    console.log("");
    console.log(`Start collectie: ${collection.id}`);

    exportData.rootCollections[collection.id] = await exportCollection(
      collection
    );
  }

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(exportData, null, 2), "utf8");

  console.log("");
  console.log("Export klaar.");
  console.log(`Bestand gemaakt: ${OUTPUT_FILE}`);
}

main().catch((error) => {
  console.error("Export mislukt:");
  console.error(error);
  process.exit(1);
});