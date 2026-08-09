/* eslint-disable no-console */

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldPath } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount) });
}

const db = getFirestore();

function hasUsableString(data, field) {
  return typeof data[field] === 'string' && data[field].trim().length > 0;
}

function anonymize(value) {
  const text = String(value).trim();
  if (text.length <= 2) return `${text[0] ?? ''}…`;
  return `${text.slice(0, 2)}…${text.slice(-1)} (${text.length} tekens)`;
}

async function main() {
  const snapshot = await db
    .collection('users')
    .orderBy(FieldPath.documentId())
    .get();

  const observedFields = new Map();
  for (const doc of snapshot.docs) {
    for (const [field, value] of Object.entries(doc.data())) {
      const stats = observedFields.get(field) ?? {
        present: 0,
        usableStrings: 0,
        examples: [],
      };
      stats.present++;
      if (hasUsableString(doc.data(), field)) {
        stats.usableStrings++;
        if (stats.examples.length < 3) stats.examples.push(anonymize(value));
      }
      observedFields.set(field, stats);
    }
  }

  const likelyNameFields = [...observedFields.entries()]
    .filter(([field]) => /name|naam|user|display|nick/i.test(field))
    .sort(([left], [right]) => left.localeCompare(right));

  console.log(`Project: ${serviceAccount.project_id}`);
  console.log(`Users gelezen: ${snapshot.size}`);
  console.log('Mogelijke gebruikersnaamvelden die daadwerkelijk voorkomen:');
  for (const [field, stats] of likelyNameFields) {
    console.log(
      `- ${field}: aanwezig=${stats.present}, niet-leeg-string=${stats.usableStrings}, ` +
        `voorbeelden=${stats.examples.join(' | ') || '(geen)'}`,
    );
  }
  const resolved = snapshot.docs.filter((doc) =>
    ['username', 'usernameLower', 'usernameKey'].some((field) =>
      hasUsableString(doc.data(), field),
    ),
  ).length;
  console.log(`Resolveerbaar met username -> usernameLower -> usernameKey: ${resolved}`);
  console.log(`Zonder bruikbare gebruikersnaam: ${snapshot.size - resolved}`);
  console.log('READ-ONLY: er zijn geen writes uitgevoerd.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
