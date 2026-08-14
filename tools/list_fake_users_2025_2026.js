const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: 'derde-divisie-app',
});

const db = getFirestore();

async function main() {
  const ref = db
    .collection('season_archives')
    .doc('2025-2026')
    .collection('rankings')
    .doc('global')
    .collection('users');

  const snapshot = await ref.where('isFake', '==', true).get();

  console.log(`\nAantal fake gebruikers: ${snapshot.size}\n`);

  const users = snapshot.docs.map((doc) => {
    const data = doc.data();

    return {
      uid: doc.id,
      displayName: data.displayName ?? '',
      email: data.email ?? '',
      totaalPunten: data.berekendTotaal ?? data.totaalPunten ?? 0,
      aantalVoorspellingen: data.aantalVoorspellingen ?? 0,
    };
  });

  users
    .sort((a, b) =>
      a.displayName.localeCompare(b.displayName, 'nl', {
        sensitivity: 'base',
      }),
    )
    .forEach((user, index) => {
      console.log(
        `${String(index + 1).padStart(2, '0')}. ` +
          `${user.displayName} | ` +
          `${user.email} | ` +
          `${user.uid} | ` +
          `${user.totaalPunten} punten | ` +
          `${user.aantalVoorspellingen} voorspellingen`,
      );
    });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\nFOUT:\n', error);
    process.exit(1);
  });