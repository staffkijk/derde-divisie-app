/* eslint-disable max-len, require-jsdoc */
import {Firestore, FieldValue} from "firebase-admin/firestore";
import {ACTIVE_SEASON, contribution, standings, uid, integer, fingerprint} from "./result-domain";
import {teams} from "./season-teams";
const normal = (v: unknown) => String(v ?? "").toUpperCase().replace(/['’\s/._-]/g, "");
export async function awardFinalPoints(db: Firestore, div: string, reset = false): Promise<void> {
  if (!["A", "B"].includes(div)) throw Error("Invalid division");
  const source = await db.collection("eindstand_voorspellingen").where("divisie", "==", div).get();
  const selected = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const doc of source.docs) {
    const d=doc.data(); if (d.seasonId !== ACTIVE_SEASON || !uid(d)) continue;
    const user=uid(d); const old=selected.get(user);
    if (!old || (d.timestamp?.toMillis() ?? 0) > (old.data().timestamp?.toMillis() ?? 0) ||
      ((d.timestamp?.toMillis() ?? 0) === (old.data().timestamp?.toMillis() ?? 0) && doc.id < old.id)) selected.set(user, doc);
  }
  for (const [userId, doc] of selected) {
    await db.runTransaction(async (tx) => {
      const lock=await tx.get(db.doc("system/result_processing_maintenance")); if (lock.data()?.enabled) throw Error("Maintenance active");
      const matchDocs = reset ? null : await tx.get(db.collection(`seasons/${ACTIVE_SEASON}/matches`).where("division", "==", div));
      const prediction=await tx.get(doc.ref); const p=prediction.data(); if (!p) return;
      const userRef=db.doc(`users/${userId}`); const user=await tx.get(userRef); if (!user.exists) throw Error("Missing user");
      const ledgerRef=db.doc(`seasons/${ACTIVE_SEASON}/endstandContributions/${div}__${userId}`); const ledger=await tx.get(ledgerRef);
      let next=0;
      if (!reset && matchDocs) {
        if (matchDocs.size!==306 || matchDocs.docs.some((m)=>m.data().status!=="finished" || m.data().processedInputKey!==fingerprint(m.data()))) throw Error("All 306 results must be completely processed before awarding final standings points");
        const table=standings(div, Object.fromEntries(matchDocs.docs.map((m)=>[m.id, contribution(m.data())])));
        if (table.some((r)=>r.sportingTie)) throw Error("An unresolved sporting tie requires the KNVB decision before final points");
        const predicted=p.voorspelling ?? p.ranking ?? p.volgorde ?? p.teams;
        if (!Array.isArray(predicted) || predicted.length!==18) throw Error("Expected 18 predicted clubs");
        const seen=new Set<string>();
        for (let i=0; i<predicted.length; i++) {
          const club=teams.find((t)=>t.division===div && [t.id, t.name, ...t.aliases].some((n)=>normal(n)===normal(predicted[i])));
          if (!club || seen.has(club.id)) throw Error("Invalid or duplicate final prediction club"); seen.add(club.id);
          const actual=table.findIndex((r)=>r.teamId===club.id); const distance=Math.abs(actual-i);
          next+=actual===0&&i===0?30:distance===0?10:distance===1?6:distance===2?2:0;
        }
      }
      const marker=`eindstand_${div}_punten`; const old=integer(ledger.data()?.points ?? p[marker]); const delta=next-old;
      const u=user.data() ?? {}; const a=integer(u.punten_A)+(div==="A"?delta:0); const b=integer(u.punten_B)+(div==="B"?delta:0);
      tx.update(userRef, {punten_A: a, punten_B: b, totalen: Math.max(a, b), [div==="A"?"eindstandA_awarded":"eindstandB_awarded"]: !reset});
      tx.update(doc.ref, {[marker]: next});
      tx.set(db.doc(`voorspel_punten/${userId}`), {[marker]: next}, {merge: true});
      tx.set(ledgerRef, {userId, division: div, points: next, predictionPath: doc.ref.path, updatedAt: FieldValue.serverTimestamp()});
    }, {maxAttempts: 20});
  }
}
