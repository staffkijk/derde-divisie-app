/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {ACTIVE_SEASON, fingerprint} from "./result-domain";
import {processMatch} from "./result-processor";
import {updateRankingMetadata} from "./ranking-fields";
if (!admin.apps.length) admin.initializeApp();
export const processMatchResult = functions.region("europe-west1").runWith({failurePolicy: true, timeoutSeconds: 540, memory: "512MB"})
  .firestore.document("seasons/{seasonId}/matches/{matchId}").onWrite(async (change, context) => {
    if (context.params.seasonId !== ACTIVE_SEASON || context.params.matchId === "_meta" || !change.after.exists) return;
    const before=change.before.data(); const after=change.after.data() ?? {};
    // Metadata writes and same-day kickoff edits never launch a score rebuild.
    try {
      if (before && fingerprint(before) === fingerprint(after)) return;
    } catch (_) {
      const raw=(d:any)=>{
        const copy={...d}; for (const k of ["processed", "verwerkt", "processingStatus", "predictionProcessingComplete", "processingError", "processingFailedAt", "processingAttempts", "processingInputKey", "processedInputKey", "processedAt", "processedResultKey", "predictionSelectedUsers", "predictionProcessedUsers", "pouleProcessedUsers", "updatedAt", "updatedBy"]) delete copy[k]; return JSON.stringify(copy);
      };
      if (before && raw(before)===raw(after)) return;
    }
    await processMatch(admin.firestore(), context.params.matchId);
  });
export const retryMatchResult = functions.region("europe-west1").https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Log in.");
  const db=admin.firestore(); const user=await db.doc(`users/${context.auth.uid}`).get();
  if (user.data()?.ismoderator !== true) throw new functions.https.HttpsError("permission-denied", "Moderator required.");
  if (typeof data?.matchId !== "string" || data.matchId.includes("/") || !data.matchId || data.matchId==="_meta") {
    throw new functions.https.HttpsError("invalid-argument", "Invalid matchId.");
  }
  await db.runTransaction(async (tx)=>{
    const lock=await tx.get(db.doc("system/result_processing_maintenance")); if (lock.data()?.enabled) throw new functions.https.HttpsError("failed-precondition", "Maintenance active.");
    tx.update(db.doc(`seasons/${ACTIVE_SEASON}/matches/${data.matchId}`), {processingRequest: FieldValue.increment(1),
      processed: false, verwerkt: false, processingStatus: "pending", predictionProcessingComplete: false});
  });
  return {queued: true};
});
export const rebuildDivisionStandings = functions.region("europe-west1").runWith({timeoutSeconds: 120}).https.onCall(async (data, context) => {
  if (!context.auth || (await admin.firestore().doc(`users/${context.auth.uid}`).get()).data()?.ismoderator !== true) {
    throw new functions.https.HttpsError("permission-denied", "Moderator required.");
  }
  if (!["A", "B"].includes(data?.division)) throw new functions.https.HttpsError("invalid-argument", "Invalid division.");
  const db=admin.firestore();
  const source=await db.collection(`seasons/${ACTIVE_SEASON}/matches`).where("division", "==", data.division).limit(1).get();
  if (source.empty) throw new functions.https.HttpsError("not-found", "No matches.");
  const {updateStandings}=await import("./result-processor.js");
  await updateStandings(db, source.docs[0].ref, fingerprint(source.docs[0].data()), true);
  return {complete: true};
});
export const maintainRankingFields = functions.region("europe-west1").firestore.document("users/{uid}").onWrite(async (change) => {
  if (!change.after.exists) return;
  await updateRankingMetadata(admin.firestore(), change.after.ref);
});

async function predictionSourceChanged(change: functions.Change<admin.firestore.DocumentSnapshot>): Promise<void> {
  const before=change.before.data(); const after=change.after.data();
  const source=(p: any) => p ? [p.gebruikerId, p.userId, p.uid, p.matchId, p.wedstrijdId, p.pouleId, p.poule, p.scoreThuis, p.scoreUit, p.homeScore, p.awayScore, p.homeGoals, p.awayGoals, p.thuisScore, p.uitScore, p.voorspellingThuis, p.voorspellingUit, p.thuis, p.uit, p.home, p.away, p.goalsHome, p.goalsAway, p.predHome, p.predAway, p.timestamp?.toMillis(), p.seasonId] : null;
  if (JSON.stringify(source(before)) === JSON.stringify(source(after))) return;
  const ids=new Set([before, after].filter((p)=>p && (!p.seasonId || p.seasonId===ACTIVE_SEASON)).map((p)=>p?.matchId ?? p?.wedstrijdId));
  for (const id of ids) {
    if (typeof id !== "string" || id.includes("/")) continue;
    const db=admin.firestore(); const ref=db.doc("seasons/"+ACTIVE_SEASON+"/matches/"+id);
    await db.runTransaction(async (tx) => {
      const lock=await tx.get(db.doc("system/result_processing_maintenance")); if (lock.data()?.enabled) throw Error("Maintenance active");
      const match=await tx.get(ref); if (!match.exists || match.data()?.status !== "finished") return;
      tx.update(ref, {processingRequest: FieldValue.increment(1), processed: false, verwerkt: false, processingStatus: "pending", predictionProcessingComplete: false});
    });
  }
}
const predictionTrigger = (path: string) => functions.region("europe-west1").runWith({failurePolicy: true})
  .firestore.document(path).onWrite(predictionSourceChanged);
export const processSeasonPredictionEdit = functions.region("europe-west1").runWith({failurePolicy: true})
  .firestore.document("seasons/{seasonId}/predictions/{id}").onWrite(async (change, context) => {
    if (context.params.seasonId===ACTIVE_SEASON) await predictionSourceChanged(change);
  });
export const processGeneralPredictionEdit=predictionTrigger("voorspellingen/{id}");
export const processPouleAPredictionEdit=predictionTrigger("poule_predictions/{id}");
export const processPouleBPredictionEdit=predictionTrigger("poule_voorspellingen/{id}");
export const processTeamPredictionEdit=predictionTrigger("predictions/{id}");
export const processFinalStandings = functions.region("europe-west1").runWith({timeoutSeconds: 540}).https.onCall(async (data, context) => {
  if (!context.auth || (await admin.firestore().doc(`users/${context.auth.uid}`).get()).data()?.ismoderator!==true) {
    throw new functions.https.HttpsError("permission-denied", "Moderator required.");
  }
  if (!["A", "B"].includes(data?.division) || (data.reset!=null && typeof data.reset!=="boolean")) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid division or reset flag.");
  }
  const {awardFinalPoints}=await import("./final-points.js");
  await awardFinalPoints(admin.firestore(), data.division, data.reset===true);
  return {complete: true};
});
