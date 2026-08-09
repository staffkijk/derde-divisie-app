const assert = require('node:assert/strict');
const {after, before, beforeEach, describe, it} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  setLogLevel,
  updateDoc,
} = require('firebase/firestore');
const fs = require('node:fs');

const projectId = 'derdediv-security-tests';

setLogLevel('silent');

describe('Firestore emulator security rules', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync('firestore.rules', 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/alice'), {
        username: 'Alice',
        ismoderator: false,
        privacy: {shareEmailWithPouleOwner: false},
      });
      await setDoc(doc(db, 'users/bob'), {
        username: 'Bob',
        ismoderator: false,
      });
      await setDoc(doc(db, 'users/moderator'), {
        username: 'Mod',
        ismoderator: true,
      });
      await setDoc(doc(db, 'poules/poule-alice'), {
        ownerId: 'alice',
        name: 'Alice poule',
        isPublic: true,
        predictionScope: 'both',
      });
      await setDoc(doc(db, 'voorspellingen/bob-prediction'), {
        gebruikerId: 'bob',
        wedstrijdId: 'A1',
        scoreThuis: 1,
        scoreUit: 1,
      });
      await setDoc(doc(db, 'poule_predictions/bob-poule-prediction'), {
        gebruikerId: 'bob',
        pouleId: 'poule-alice',
        matchId: 'A1',
        scoreThuis: 1,
        scoreUit: 1,
      });
      await setDoc(doc(db, 'eindstand_voorspellingen/alice_A'), {
        gebruikerId: 'alice', divisie: 'A', voorspelling: ['Club 1', 'Club 2'],
      });
      await setDoc(doc(db, 'eindstand_voorspellingen/alice_B'), {
        divisie: 'B', voorspelling: ['Legacy Club 1', 'Legacy Club 2'],
      });
      await setDoc(doc(db, 'eindstand_voorspellingen/bob_A'), {
        gebruikerId: 'bob', divisie: 'A', voorspelling: ['Bob Club 1'],
      });
      await setDoc(doc(db, 'eindstand_voorspellingen/dave_A'), {
        gebruikerId: 'bob', divisie: 'A', voorspelling: ['Bob Club 1'],
      });
    });
  });

  const authed = (uid) =>
    testEnv.authenticatedContext(uid, {email: `${uid}@example.test`})
      .firestore();
  const unauthenticated = () => testEnv.unauthenticatedContext().firestore();

  it('blocks unauthenticated writes to protected and user-owned collections', async () => {
    const db = unauthenticated();

    await assertFails(setDoc(doc(db, 'matches/A1'), {status: 'finished'}));
    await assertFails(setDoc(doc(db, 'standen/acv'), {points: 3}));
    await assertFails(setDoc(doc(db, 'periodestanden/dda/periode_1/acv'), {points: 3}));
    await assertFails(setDoc(doc(db, 'sync_logs/test'), {message: 'x'}));
    await assertFails(setDoc(doc(db, 'voorspel_punten/alice'), {punten_A: 10}));
    await assertFails(setDoc(doc(db, 'activityLogs/log1'), {uid: 'alice'}));
    await assertFails(setDoc(doc(db, 'system/moderatorConfig'), {enabled: true}));
  });

  it('blocks normal users from moderator-only writes', async () => {
    const db = authed('alice');

    await assertFails(setDoc(doc(db, 'matches/A1'), {status: 'finished'}));
    await assertFails(setDoc(doc(db, 'standen/acv'), {points: 3}));
    await assertFails(setDoc(doc(db, 'periodestanden/dda/periode_1/acv'), {points: 3}));
    await assertFails(setDoc(doc(db, 'sync_logs/test'), {message: 'x'}));
    await assertFails(setDoc(doc(db, 'voorspel_punten/alice'), {punten_A: 10}));
    await assertFails(setDoc(doc(db, 'system/moderatorConfig'), {enabled: true}));
    await assertFails(deleteDoc(doc(db, 'voorspellingen/bob-prediction')));
  });

  it('allows moderators to perform required moderator writes', async () => {
    const db = authed('moderator');

    await assertSucceeds(setDoc(doc(db, 'matches/A1'), {status: 'finished'}));
    await assertSucceeds(setDoc(doc(db, 'standen/acv'), {points: 3}));
    await assertSucceeds(setDoc(doc(db, 'periodestanden/dda/periode_1/acv'), {points: 3}));
    await assertSucceeds(setDoc(doc(db, 'sync_logs/test'), {message: 'ok'}));
    await assertSucceeds(setDoc(doc(db, 'voorspel_punten/alice'), {punten_A: 10}));
    await assertSucceeds(setDoc(doc(db, 'system/moderatorConfig'), {enabled: true}));
    await assertSucceeds(updateDoc(doc(db, 'voorspellingen/bob-prediction'), {
      gebruikerId: 'bob',
      punten: 7,
      verwerkt: true,
    }));
    await assertSucceeds(getDoc(doc(db, 'activityLogs/log1')));
  });

  it('allows normal users to create and update their own predictions only', async () => {
    const db = authed('alice');

    await assertSucceeds(setDoc(doc(db, 'voorspellingen/alice-prediction'), {
      gebruikerId: 'alice',
      wedstrijdId: 'A1',
      scoreThuis: 2,
      scoreUit: 1,
    }));
    await assertSucceeds(updateDoc(doc(db, 'voorspellingen/alice-prediction'), {
      gebruikerId: 'alice',
      wedstrijdId: 'A1',
      scoreThuis: 3,
      scoreUit: 1,
    }));
    await assertFails(updateDoc(doc(db, 'voorspellingen/bob-prediction'), {
      gebruikerId: 'alice',
      wedstrijdId: 'A1',
      scoreThuis: 4,
      scoreUit: 1,
    }));
  });

  it('saves new, existing and legacy eindstand predictions for normal users', async () => {
    const db = authed('alice');
    const payload = (division) => ({
      gebruikerId: 'alice', divisie: division, seasonId: '2026-2027',
      voorspelling: ['Club 2', 'Club 1'],
    });

    await assertSucceeds(setDoc(
      doc(db, 'eindstand_voorspellingen/alice_A'), payload('A'), {merge: true},
    ));
    await assertSucceeds(setDoc(
      doc(db, 'eindstand_voorspellingen/alice_B'), payload('B'), {merge: true},
    ));
    const newUserDb = authed('charlie');
    await assertSucceeds(setDoc(
      doc(newUserDb, 'eindstand_voorspellingen/charlie_A'),
      {...payload('A'), gebruikerId: 'charlie'},
    ));

    const reopened = await assertSucceeds(
      getDoc(doc(db, 'eindstand_voorspellingen/alice_B')),
    );
    assert.deepEqual(reopened.data().voorspelling, ['Club 2', 'Club 1']);
    assert.equal(reopened.data().gebruikerId, 'alice');
  });

  it('uses the same own eindstand save flow for a moderator', async () => {
    const db = authed('moderator');
    await assertSucceeds(setDoc(
      doc(db, 'eindstand_voorspellingen/moderator_A'),
      {gebruikerId: 'moderator', divisie: 'A', seasonId: '2026-2027', voorspelling: ['Club 2', 'Club 1']},
    ));
  });

  it('does not let a normal user claim another eindstand document', async () => {
    const db = authed('alice');
    await assertFails(setDoc(
      doc(db, 'eindstand_voorspellingen/bob_A'),
      {gebruikerId: 'alice', divisie: 'A', seasonId: '2026-2027', voorspelling: ['Overgenomen']},
      {merge: true},
    ));
    await assertFails(setDoc(
      doc(authed('dave'), 'eindstand_voorspellingen/dave_A'),
      {gebruikerId: 'dave', divisie: 'A', seasonId: '2026-2027', voorspelling: ['Overgenomen']},
      {merge: true},
    ));
  });

  it('allows profile, privacy and own notifications but blocks changing another user', async () => {
    const aliceDb = authed('alice');
    const bobDb = authed('bob');

    await assertSucceeds(updateDoc(doc(aliceDb, 'users/alice'), {
      displayName: 'Alice Updated',
      privacy: {shareEmailWithPouleOwner: true},
    }));
    await assertFails(updateDoc(doc(aliceDb, 'users/alice'), {
      ismoderator: true,
    }));
    await assertFails(updateDoc(doc(aliceDb, 'users/alice'), {
      isModerator: true,
    }));
    await assertSucceeds(setDoc(doc(aliceDb, 'users/alice/notifications/n1'), {
      title: 'Reminder',
      read: false,
    }));
    await assertSucceeds(updateDoc(doc(aliceDb, 'users/alice/notifications/n1'), {
      read: true,
    }));
    await assertFails(updateDoc(doc(aliceDb, 'users/bob'), {
      displayName: 'Not Alice',
    }));
    await assertFails(setDoc(doc(bobDb, 'users/alice/notifications/n2'), {
      title: 'Nope',
    }));
  });

  it('allows moderators, but not users, to change moderator claims', async () => {
    const aliceDb = authed('alice');
    const modDb = authed('moderator');

    await assertFails(updateDoc(doc(aliceDb, 'users/alice'), {
      ismoderator: true,
    }));
    await assertSucceeds(updateDoc(doc(modDb, 'users/alice'), {
      ismoderator: true,
    }));
  });

  it('allows normal poule creation, joining and owner-managed settings', async () => {
    const aliceDb = authed('alice');
    const bobDb = authed('bob');

    await assertSucceeds(setDoc(doc(aliceDb, 'poules/new-poule'), {
      ownerId: 'alice',
      name: 'Nieuwe poule',
      isPublic: false,
      predictionScope: 'matches',
      shareEmailsWithOwner: false,
    }));
    await assertSucceeds(updateDoc(doc(aliceDb, 'poules/new-poule'), {
      isPublic: true,
      shareEmailsWithOwner: true,
    }));
    await assertSucceeds(setDoc(doc(bobDb, 'poules/poule-alice/deelnemers/bob'), {
      userId: 'bob',
      rol: 'deelnemer',
      punten: 0,
    }));
    await assertSucceeds(setDoc(doc(aliceDb, 'poules/poule-alice/deelnemers/bob'), {
      userId: 'bob',
      rol: 'deelnemer',
      syncEnabled: true,
    }));
    await assertFails(updateDoc(doc(bobDb, 'poules/poule-alice'), {
      name: 'Overgenomen',
    }));
  });

  it('protects backward-compatible poule prediction collections by existing owner', async () => {
    const aliceDb = authed('alice');

    await assertSucceeds(setDoc(doc(aliceDb, 'poule_predictions/alice-poule-prediction'), {
      gebruikerId: 'alice',
      pouleId: 'poule-alice',
      matchId: 'A1',
      scoreThuis: 2,
      scoreUit: 1,
    }));
    await assertFails(updateDoc(doc(aliceDb, 'poule_predictions/bob-poule-prediction'), {
      gebruikerId: 'alice',
      pouleId: 'poule-alice',
      matchId: 'A1',
      scoreThuis: 5,
      scoreUit: 1,
    }));
  });

  it('allows safe activity log creation and blocks unsafe or mutable activity logs', async () => {
    const aliceDb = authed('alice');
    const bobDb = authed('bob');
    const modDb = authed('moderator');

    await assertSucceeds(setDoc(doc(aliceDb, 'activityLogs/alice-log'), {
      uid: 'alice',
      eventType: 'navigation_click',
      metadata: {destination: 'Programma'},
    }));
    await assertFails(setDoc(doc(aliceDb, 'activityLogs/unsafe-log'), {
      uid: 'alice',
      eventType: 'login',
      metadata: {email: 'alice@example.test'},
    }));
    await assertFails(updateDoc(doc(aliceDb, 'activityLogs/alice-log'), {
      eventType: 'tampered',
    }));
    await assertSucceeds(getDoc(doc(modDb, 'activityLogs/alice-log')));
    await assertFails(getDoc(doc(bobDb, 'activityLogs/alice-log')));
  });

  it('keeps season structure publicly readable but moderator-writable only', async () => {
    const publicDb = unauthenticated();
    const aliceDb = authed('alice');
    const modDb = authed('moderator');

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'seasons/2026-2027/matches/A1'), {
        division: 'A',
      });
    });

    const publicRead = await assertSucceeds(
      getDoc(doc(publicDb, 'seasons/2026-2027/matches/A1')),
    );
    assert.equal(publicRead.exists(), true);
    await assertFails(setDoc(doc(aliceDb, 'seasons/2026-2027/matches/A2'), {
      division: 'A',
    }));
    await assertSucceeds(setDoc(doc(modDb, 'seasons/2026-2027/matches/A2'), {
      division: 'A',
    }));
  });
});
