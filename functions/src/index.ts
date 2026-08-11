/* eslint-disable */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import {BetaAnalyticsDataClient} from "@google-analytics/data";
import {defineString} from "firebase-functions/params";
import {buildCalendar, loadCalendarData} from "./calendar";
import {allowsMissingPredictionReminderPush} from "./prediction-reminder-policy";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const region = "europe-west1";
const analyticsDataClient = new BetaAnalyticsDataClient();
const ga4PropertyIdParam = defineString("GA4_PROPERTY_ID");

let calendarCache: {expires: number; data: Awaited<ReturnType<typeof loadCalendarData>>} | null = null;

export const calendarFeed = functions.region(region).https.onRequest(async (req, res): Promise<void> => {
  try {
    if (!calendarCache || calendarCache.expires < Date.now()) {
      calendarCache = {data: await loadCalendarData(db), expires: Date.now() + 5 * 60 * 1000};
    }
    const path = req.path
      .replace(/^\/agenda\//, "")
      .replace(/^\/|\.ics$/g, "");
    const teamMatch = /^team\/([^/]+)$/.exec(path);
    const division = path === "divisie-a" ? "A" : path === "divisie-b" ? "B" : undefined;
    if (path !== "alles" && !division && !teamMatch) {
      res.status(404).send("Onbekende agenda-feed");
      return;
    }
    const baseUrl = `${req.protocol}://${req.get("host")}`;
    const body = buildCalendar({...calendarCache.data, division, teamId: teamMatch?.[1], baseUrl});
    res.set("Content-Type", "text/calendar; charset=utf-8");
    res.set("Cache-Control", "public, max-age=300, s-maxage=300, stale-while-revalidate=60");
    res.set("Content-Disposition", "inline; filename=derdediv-programma.ics");
    res.status(200).send(body);
  } catch (error) {
    console.error("calendarFeed error", error);
    res.status(500).send("De agenda-feed kon niet worden gemaakt.");
  }
});

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

export const sendPredictionReminderPushes = functions
  .region(region)
  .pubsub.schedule("every 60 minutes")
  .timeZone("Europe/Amsterdam")
  .onRun(async (): Promise<void> => {
    const users = await db.collection("users").get();
    const now = admin.firestore.Timestamp.now();

    for (const user of users.docs) {
      const notifications = await user.ref
        .collection("notifications")
        .where("type", "==", "missing_predictions")
        .where("read", "==", false)
        .limit(10)
        .get();
      if (notifications.empty) continue;

      const tokens = await user.ref.collection("fcmTokens").get();
      const tokenValues = tokens.docs
        .map((doc) => String(doc.data().token || doc.id || ""))
        .filter((token) => token.length > 20);
      for (const notification of notifications.docs) {
        const data = notification.data();
        const latestUser = await user.ref.get();
        const latestPreferences = latestUser.data()?.notificationPreferences;
        if (!allowsMissingPredictionReminderPush(
          latestPreferences,
          data.division
        )) {
          await notification.ref.delete();
          continue;
        }
        if (data.pushSentAt || !tokenValues.length) continue;
        await admin.messaging().sendEachForMulticast({
          tokens: tokenValues,
          notification: {
            title: String(data.title || "Voorspellingen ontbreken"),
            body: String(data.body || "Je hebt nog voorspellingen openstaan."),
          },
          webpush: {
            notification: {
              data: {
                url: "/",
              },
            },
          },
          data: {
            type: String(data.type || "missing_predictions"),
            division: String(data.division || ""),
            round: String(data.round || ""),
          },
        });
        await notification.ref.set(
          {
            pushSentAt: now,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }
  });

function ga4PropertyId(): string {
  return ga4PropertyIdParam.value().trim();
}

async function assertModerator(context: functions.https.CallableContext) {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Log in als moderator om GA4 rapportagedata te bekijken."
    );
  }

  const user = await db.collection("users").doc(uid).get();
  if (user.data()?.ismoderator !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Alleen moderators kunnen GA4 rapportagedata bekijken."
    );
  }
}

function metricValue(row: any, index = 0): number {
  const value = row?.metricValues?.[index]?.value;
  const parsed = Number.parseInt(String(value ?? "0"), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function dimensionValue(row: any, index = 0): string {
  return String(row?.dimensionValues?.[index]?.value ?? "").trim();
}

function rowsToBreakdown(rows: any[] | null | undefined) {
  return (rows ?? []).slice(0, 5).map((row) => ({
    label: dimensionValue(row) || "(onbekend)",
    value: metricValue(row),
  }));
}

async function runMetricReport(
  property: string,
  startDate: string,
  endDate: string,
  metricNames: string[]
) {
  const [response] = await analyticsDataClient.runReport({
    property,
    dateRanges: [{startDate, endDate}],
    metrics: metricNames.map((name) => ({name})),
  });
  const row = response.rows?.[0];
  return metricNames.reduce<Record<string, number>>((result, name, index) => {
    result[name] = metricValue(row, index);
    return result;
  }, {});
}

async function runBreakdownReport(
  property: string,
  dimensionName: string,
  metricName: string,
  limit = 5
) {
  const [response] = await analyticsDataClient.runReport({
    property,
    dateRanges: [{startDate: "30daysAgo", endDate: "today"}],
    dimensions: [{name: dimensionName}],
    metrics: [{name: metricName}],
    limit,
    orderBys: [{metric: {metricName}, desc: true}],
  });
  return rowsToBreakdown(response.rows);
}

export const getModeratorGa4Analytics = functions
  .region(region)
  .https.onCall(async (_data, context) => {
    await assertModerator(context);

    const propertyId = ga4PropertyId();
    if (!propertyId) {
      return {
        configured: false,
        message:
          "GA4 rapportagedata nog niet geconfigureerd: parameter GA4_PROPERTY_ID ontbreekt",
      };
    }

    const property = `properties/${propertyId}`;

    try {
      const [today, sevenDays, thirtyDays, realtime] = await Promise.all([
        runMetricReport(property, "today", "today", ["activeUsers"]),
        runMetricReport(property, "7daysAgo", "today", ["activeUsers"]),
        runMetricReport(property, "30daysAgo", "today", [
          "activeUsers",
          "sessions",
          "newUsers",
        ]),
        analyticsDataClient.runRealtimeReport({
          property,
          metrics: [{name: "activeUsers"}],
        }),
      ]);

      const [topPages, deviceCategories, trafficSources] = await Promise.all([
        runBreakdownReport(property, "pageTitle", "screenPageViews"),
        runBreakdownReport(property, "deviceCategory", "activeUsers"),
        runBreakdownReport(property, "sessionDefaultChannelGroup", "sessions"),
      ]);

      const activeUsersNow = metricValue(realtime[0].rows?.[0]);
      const visitorsThirtyDays = thirtyDays.activeUsers ?? 0;
      const newUsersThirtyDays = thirtyDays.newUsers ?? 0;

      return {
        configured: true,
        visitorsToday: today.activeUsers ?? 0,
        visitorsSevenDays: sevenDays.activeUsers ?? 0,
        visitorsThirtyDays,
        activeUsersNow,
        sessionsThirtyDays: thirtyDays.sessions ?? 0,
        newUsersThirtyDays,
        returningUsersThirtyDays: Math.max(
          visitorsThirtyDays - newUsersThirtyDays,
          0
        ),
        topPages,
        deviceCategories,
        trafficSources,
      };
    } catch (error: any) {
      console.error("getModeratorGa4Analytics error", error);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "GA4 rapportagedata nog niet geconfigureerd"
      );
    }
  });
