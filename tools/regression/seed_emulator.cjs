const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'derde-divisie-app';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Start dit script via firebase emulators:exec met Auth en Firestore.');
}

const app = initializeApp({projectId});
const db = getFirestore(app);
const auth = getAuth(app);

async function ensureUser(uid, email) {
  try {
    await auth.getUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await auth.createUser({uid, email, password: 'Regression123!'});
  }
}

async function main() {
  await Promise.all([
    ensureUser('regression-moderator', 'moderator@regression.test'),
    ensureUser('regression-alice', 'alice@regression.test'),
    ensureUser('regression-bob', 'bob@regression.test'),
  ]);

  const batch = db.batch();
  batch.set(db.doc('users/regression-moderator'), {
    username: 'Regression Moderator',
    ismoderator: true,
    punten_A: 0,
    punten_B: 0,
    totalen: 0,
  });
  batch.set(db.doc('users/regression-alice'), {
    username: 'Alice Regression',
    ismoderator: false,
    punten_A: 0,
    punten_B: 0,
    totalen: 0,
  });
  batch.set(db.doc('users/regression-bob'), {
    username: 'Bob Regression',
    ismoderator: false,
    punten_A: 0,
    punten_B: 0,
    totalen: 0,
  });

  const matchTime = Timestamp.fromDate(new Date('2026-08-15T13:30:00Z'));
  batch.set(db.doc('seasons/2026-2027/matches/A_REGRESSION_01'), {
    division: 'A',
    round: 1,
    roundMatchIndex: 1,
    status: 'scheduled',
    homeTeamSlug: 'acv',
    awayTeamSlug: 'ado20',
    homeTeamName: 'ACV',
    awayTeamName: 'ADO20',
    homeTeam: 'ACV',
    awayTeam: 'ADO20',
    thuisteam: 'ACV',
    uitteam: 'ADO20',
    date: matchTime,
    datum: matchTime,
    kickoffTime: '15:30',
  });

  batch.set(db.doc('seasons/2026-2027/predictions/regression-alice-A1'), {
    gebruikerId: 'regression-alice',
    wedstrijdId: 'A_REGRESSION_01',
    matchId: 'A_REGRESSION_01',
    scoreThuis: 2,
    scoreUit: 1,
    timestamp: Timestamp.fromDate(new Date('2026-08-08T18:00:00Z')),
    verwerkt: false,
  });

  batch.set(db.doc('voorspellingen/regression-bob-A1'), {
    gebruikerId: 'regression-bob',
    wedstrijdId: 'A_REGRESSION_01',
    matchId: 'A_REGRESSION_01',
    scoreThuis: 0,
    scoreUit: 2,
    timestamp: Timestamp.fromDate(new Date('2026-08-08T18:05:00Z')),
    verwerkt: false,
  });

  await batch.commit();
  console.log('Regression emulator seed gereed.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
