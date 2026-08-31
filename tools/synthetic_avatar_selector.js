'use strict';
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const BALL_AVATAR = 'assets/images/profiel_bal.png';
function normalize(value) { return String(value || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, ''); }
function bucket(uid) { return crypto.createHash('sha256').update(String(uid)).digest().readUInt32BE(0) % 100; }
function resolveLocalLogoAsset(values, rootDir) {
  if (!rootDir) return null;
  const directory = path.join(rootDir, 'assets', 'images');
  const files = fs.readdirSync(directory).filter((file) => /^logo_.*\.png$/i.test(file));
  const keys = values.filter(Boolean).map(normalize);
  const prefixes = /^(vv|sv|sc|rkvv|rksv|fc)/;
  for (const file of files) {
    const fileKey = normalize(file.replace(/^logo_/i, '').replace(/\.png$/i, ''));
    if (keys.some((key) => fileKey === key || fileKey.replace(prefixes, '') === key.replace(prefixes, ''))) return `assets/images/${file}`;
  }
  return null;
}
function candidateValues(user) { return [user.favoriteTeamSlug, user.favoriteTeamName, user.favorieteClub].filter(Boolean); }
function resolveTeam(user, teams) {
  for (const value of candidateValues(user)) {
    const key = normalize(value); const team = teams.find((item) => [item.id, item.name, item.label, ...(item.aliases || [])].some((v) => normalize(v) === key));
    if (team) return { team, reason: `favoriete club: ${value}` };
  }
  const identity = normalize(`${user.displayName || ''} ${user.username || ''}`);
  const linked = teams.filter((team) => (team.nameTokens || []).some((token) => token.length >= 6 && identity.includes(normalize(token))));
  return linked.length === 1 ? { team: linked[0], reason: 'unieke naamlink' } : null;
}
function selectSyntheticAvatar(user, teams, rootDir) {
  const value = bucket(user.uid || user.id || user.syntheticId);
  if (value < 40) return { avatarUrl: '', kind: 'none', reason: 'deterministische 40%-groep' };
  if (value < 80) return { avatarUrl: BALL_AVATAR, kind: 'football', reason: 'deterministische 40%-groep' };
  const match = resolveTeam(user, teams);
  if (match && match.team.logoPath && (!rootDir || fs.existsSync(path.join(rootDir, match.team.logoPath)))) return { avatarUrl: match.team.logoPath, kind: 'club', reason: match.reason, teamId: match.team.id };
  return value % 2 ? { avatarUrl: BALL_AVATAR, kind: 'football', reason: 'geen zekere clubbinding' } : { avatarUrl: '', kind: 'none', reason: 'geen zekere clubbinding' };
}
module.exports = { BALL_AVATAR, normalize, bucket, resolveLocalLogoAsset, resolveTeam, selectSyntheticAvatar };