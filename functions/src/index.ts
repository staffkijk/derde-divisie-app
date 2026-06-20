/* eslint-disable */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const region = "europe-west1";

/* -------------------------------------------------------------------------- */
/*                        Helper functies voorspellen                         */
/* -------------------------------------------------------------------------- */

async function getUserPouleIds(uid: string): Promise<string[]> {
  const snap = await db.collection(`users/${uid}/poules`).get();
  return snap.docs.map((d) => d.id);
}

async function getSyncSettings(
  pouleId: string,
  uid: string
): Promise<{ enabled: boolean; startAt?: admin.firestore.Timestamp | null }> {
  const ref = db.doc(`poules/${pouleId}/deelnemers/${uid}`);
  const snap = await ref.get();
  if (!snap.exists) return { enabled: false, startAt: null };
  const data = snap.data() || {};
  return {
    enabled: !!data.syncEnabled,
    startAt: (data.syncStartAt as admin.firestore.Timestamp) || null,
  };
}

type PouleKind = "DDA" | "DDB" | "ONE_TEAM" | "UNKNOWN";

async function resolvePouleKind(pouleId: string): Promise<PouleKind> {
  const doc = await db.doc(`poules/${pouleId}`).get();
  const p = doc.data() || {};

  const type = (p.type || "").toString().toUpperCase();
  if (type === "DDA") return "DDA";
  if (type === "DDB") return "DDB";
  if (type === "ONE_TEAM") return "ONE_TEAM";

  const comp = (p.competition || "").toString().toLowerCase();
  if (comp === "dda") return "DDA";
  if (comp === "ddb") return "DDB";
  if (comp === "team") return "ONE_TEAM";

  const code = (p.competitionCode || "").toString().toUpperCase();
  if (code === "3A") return "DDA";
  if (code === "3B") return "DDB";

  return "UNKNOWN";
}

function destDocRef(kind: PouleKind, pouleId: string, matchId: string, uid: string) {
  const id = `${pouleId}_${matchId}_${uid}`;
  switch (kind) {
    case "DDA":
      return db.collection("poule_predictions").doc(id);
    case "DDB":
      return db.collection("poule_voorspellingen").doc(id);
    case "ONE_TEAM":
      return db.collection("predictions").doc(id);
    default:
      return null;
  }
}

/* -------------------------------------------------------------------------- */
/*                     🔁 SYNC GLOBALE → POULE VOORSPELLINGEN                */
/* -------------------------------------------------------------------------- */

export const syncVoorspellingToPoules = functions
  .region(region)
  .firestore.document("voorspellingen/{voorspellingId}")
  .onWrite(async (change) => {
    if (!change.after.exists) return;

    const data = change.after.data() || {};
    const uid = String(data.gebruikerId || data.userId || "");
    const matchId = String(data.wedstrijdId || data.matchId || "");
    const home = (data.scoreThuis ?? data.homeGoals ?? null) as number | null;
    const away = (data.scoreUit ?? data.awayGoals ?? null) as number | null;

    const sourceTs =
      (data.timestamp as admin.firestore.Timestamp) ||
      (data.updatedAt as admin.firestore.Timestamp) ||
      admin.firestore.Timestamp.now();

    if (!uid || !matchId) return;

    const pouleIds = await getUserPouleIds(uid);
    if (!pouleIds.length) return;

    const tasks: Promise<unknown>[] = [];

    for (const pouleId of pouleIds) {
      tasks.push(
        (async () => {
          const settings = await getSyncSettings(pouleId, uid);
          if (!settings.enabled) return;
          if (settings.startAt && sourceTs.toMillis() < settings.startAt.toMillis()) return;

          const kind = await resolvePouleKind(pouleId);
          const destRef = destDocRef(kind, pouleId, matchId, uid);
          if (!destRef) return;

          await destRef.set(
            {
              pouleId,
              userId: uid,
              matchId,
              wedstrijdId: matchId,
              homeGoals: home,
              awayGoals: away,
              scoreThuis: home,
              scoreUit: away,
              syncedFrom: "global",
              syncedAt: admin.firestore.FieldValue.serverTimestamp(),
              sourceUpdatedAt: sourceTs,
            },
            { merge: true }
          );
        })()
      );
    }

    await Promise.all(tasks);
  });

/* -------------------------------------------------------------------------- */
/*                        🐦 X SYNC — MET MEDIA                               */
/* -------------------------------------------------------------------------- */

async function fetchAndStoreTweets() {
  const BEARER = functions.config().x?.bearer;
  const USERNAME = (functions.config().x?.username || "Derde_Div").replace("@", "");
  if (!BEARER) throw new Error("Geen BEARER token");

  // 1 — user id
  const userRes = await axios.get(
    `https://api.x.com/2/users/by/username/${USERNAME}`,
    { headers: { Authorization: `Bearer ${BEARER}` } }
  );
  const userId = userRes.data.data.id;

  // 2 — tweets + media
  const tweetRes = await axios.get(
    `https://api.x.com/2/users/${userId}/tweets?max_results=5&tweet.fields=created_at,attachments&expansions=attachments.media_keys&media.fields=url,preview_image_url`,
    { headers: { Authorization: `Bearer ${BEARER}` } }
  );

  const tweets = tweetRes.data?.data ?? [];
  const media = tweetRes.data?.includes?.media ?? [];
  const map = new Map<string, string>();
  for (const m of media) {
    const url = m.url || m.preview_image_url;
    if (url && m.media_key) map.set(m.media_key, url);
  }

  const batch = db.batch();
  for (const t of tweets) {
    const key = t.attachments?.media_keys?.[0];
    const mediaUrl = key ? map.get(key) ?? null : null;
    batch.set(
      db.collection("x_posts").doc(String(t.id)),
      {
        id: t.id,
        text: t.text,
        createdAt: new Date(t.created_at),
        url: `https://x.com/${USERNAME}/status/${t.id}`,
        mediaUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();
  return tweets.length;
}

/* -------------------------------------------------------------------------- */
/*                      🌐 HANDMATIGE SYNC HTTP ENDPOINT                     */
/* -------------------------------------------------------------------------- */

export const xSyncNow = functions
  .region(region)
  .https.onRequest(async (_req, res): Promise<void> => {
    try {
      const count = await fetchAndStoreTweets();
      res.json({ ok: true, count, message: "✅ Tweets (met media) gesynchroniseerd." });
    } catch (e: any) {
      console.error("xSyncNow error:", e);
      res.status(500).json({ ok: false, error: e.message });
    }
  });

/* -------------------------------------------------------------------------- */
/*                       ⏰ ELK UUR AUTOMATISCH SYNC                         */
/* -------------------------------------------------------------------------- */

export const xSyncHourly = functions
  .region(region)
  .pubsub.schedule("every 60 minutes")
  .timeZone("Europe/Amsterdam")
  .onRun(async (): Promise<void> => {
    try {
      const count = await fetchAndStoreTweets();
      console.log(`✅ Hourly sync ok — ${count} tweets bijgewerkt`);
    } catch (e) {
      console.error("Hourly sync error:", e);
    }
  });
