import {Firestore, DocumentReference} from "firebase-admin/firestore";

/** Presentation-only ranking metadata: never derive or initialize points here. */
export function rankingNameForUser(data: Record<string, unknown>): string {
  const name = [data.username, data.usernameLower, data.usernameKey]
    .find((value): value is string => typeof value === "string" && value.trim().length > 0) ?? "Onbekend";
  return name.trim().toLowerCase();
}

/** Skip all writes during maintenance and never modify user point balances. */
export async function updateRankingMetadata(
  db: Firestore, userRef: DocumentReference,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const maintenance = await tx.get(db.doc("system/result_processing_maintenance"));
    if (maintenance.data()?.enabled === true) return;
    const current = await tx.get(userRef);
    const data = current.data();
    if (!data) return;
    const rankingName = rankingNameForUser(data);
    if (data.rankingName === rankingName) return;
    tx.update(userRef, {rankingName});
  });
}
