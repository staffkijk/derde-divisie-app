/* eslint-disable no-console */
'use strict';
const fs = require('fs');
const path = require('path');
const { applicationDefault, getApps, initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { resolveLocalLogoAsset, selectSyntheticAvatar } = require('./synthetic_avatar_selector');
const APPLY = process.argv.includes('--apply');
const PROJECT_ID = 'derde-divisie-app'; const SEASON = '2026-2027';
if (!getApps().length) initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore(); const root = path.resolve(__dirname, '..');
function norm(v) { return String(v || '').toLowerCase().replace(/[^a-z0-9]/g, ''); }
async function main() {
  const [usersSnap, teamsSnap] = await Promise.all([
    db.collection('users').where('isFake', '==', true).get(),
    db.collection('seasons').doc(SEASON).collection('teams').get(),
  ]);
  const teams = teamsSnap.docs.map((doc) => { const d = doc.data(); const name = d.name || d.naam || d.teamName || doc.id; return { id: doc.id, name, label: d.label || name, aliases: d.aliases || [], logoPath: d.logoPath || d.logoAsset || d.assetPath || resolveLocalLogoAsset([doc.id, name, d.assetCode, d.code, d.slug], root), nameTokens: String(name).split(/\s+/) }; });
  const scoped = usersSnap.docs.filter((doc) => { const d = doc.data(); return d.isFake === true && d.accountType === 'synthetic' && d.syntheticSeason === SEASON; });
  const rows = scoped.map((doc) => { const user = { id: doc.id, uid: doc.id, ...doc.data() }; return { uid: doc.id, username: user.username || user.displayName || '', oldAvatarUrl: user.avatarUrl || '', ...selectSyntheticAvatar(user, teams, root) }; });
  const counts = { none: 0, football: 0, club: 0 }; rows.forEach((row) => counts[row.kind]++);
  const report = { mode: APPLY ? 'APPLY' : 'DRY_RUN', season: SEASON, totalSyntheticUsersFound: rows.length, unchanged: rows.filter((r) => r.oldAvatarUrl === r.avatarUrl).length, distribution: counts, realUsersTouched: 0, everyAssetExists: rows.filter((r) => r.avatarUrl.startsWith('assets/')).every((r) => fs.existsSync(path.join(root, r.avatarUrl))), rows };
  fs.writeFileSync(path.join(__dirname, 'synthetic_avatar_2026_2027_dry_run.json'), JSON.stringify(report, null, 2));
  fs.writeFileSync(path.join(__dirname, 'synthetic_avatar_2026_2027_dry_run.txt'), [`Mode: ${report.mode}`, `Synthetic users: ${rows.length}`, `Unchanged: ${report.unchanged}`, `Geen avatar: ${counts.none}`, `Voetbal: ${counts.football}`, `Clublogo: ${counts.club}`, `Echte users geraakt: 0`, `Alle assets bestaan: ${report.everyAssetExists}`, '', ...rows.map((r) => `${r.uid}\t${r.username}\t${r.avatarUrl || '<leeg>'}\t${r.reason}`)].join('\n'));
  console.log(JSON.stringify(report, null, 2));
  if (!APPLY) return;
  if (!report.everyAssetExists) throw new Error('Niet ieder gekozen asset bestaat.');
  const backup = { createdAt: new Date().toISOString(), season: SEASON, users: rows.map((r) => ({ uid: r.uid, avatarUrl: r.oldAvatarUrl })) };
  const backupPath = path.join(__dirname, `synthetic_avatar_backup_${new Date().toISOString().replace(/[:.]/g, '-')}.json`); fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2));
  for (let offset = 0; offset < rows.length; offset += 400) { const batch = db.batch(); for (const row of rows.slice(offset, offset + 400)) batch.update(db.collection('users').doc(row.uid), row.avatarUrl ? { avatarUrl: row.avatarUrl } : { avatarUrl: FieldValue.delete() }); await batch.commit(); }
  const verify = await db.getAll(...rows.map((row) => db.collection('users').doc(row.uid))); verify.forEach((snap, i) => { if ((snap.data().avatarUrl || '') !== rows[i].avatarUrl) throw new Error(`Verify mislukt: ${snap.id}`); });
  console.log(`Apply en verify voltooid. Backup: ${backupPath}`);
}
main().catch((error) => { console.error(error); process.exitCode = 1; });