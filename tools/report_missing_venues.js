/* eslint-disable no-console */
const PROJECT_ID = 'derde-divisie-app';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
  '/databases/%28default%29/documents';
const fields = ['venueName', 'venueAddress', 'venuePostalCode', 'venueCity'];
const {clubIdForName} = require('./club_ids');

function stringField(document, key) {
  return String(document?.fields?.[key]?.stringValue || '').trim();
}

function documentId(document) {
  return String(document.name || '').split('/').pop();
}

async function getJson(path) {
  const response = await fetch(`${BASE_URL}/${path}`);
  if (!response.ok) {
    throw new Error(`Firestore GET ${path} mislukt: ${response.status}`);
  }
  return response.json();
}

async function main() {
  console.log(`Firebase-project: ${PROJECT_ID}`);
  console.log('Modus: alleen publieke Firestore GET-requests; geen writes.');
  const current = await getJson('system/current_season');
  const seasonId = stringField(current, 'seasonId');
  if (!seasonId) throw new Error('system/current_season bevat geen seasonId');
  const [seasonResult, centralResult] = await Promise.all([
    getJson(`seasons/${seasonId}/teams?pageSize=1000`),
    getJson('teams?pageSize=1000'),
  ]);
  const seasonTeams = seasonResult.documents || [];
  const centralTeams = centralResult.documents || [];
  const centralById = new Map(centralTeams.map((doc) => [documentId(doc), doc]));
  const incomplete = seasonTeams.map((team) => {
    const id = documentId(team);
    const name = stringField(team, 'displayName') || stringField(team, 'name') || id;
    let fallbackClubId = id;
    try {
      fallbackClubId = clubIdForName(name);
    } catch (_) {
      // Houd onbekende legacy-documenten leesbaar in het rapport.
    }
    const clubId = stringField(team, 'clubId') || fallbackClubId;
    const club = centralById.get(clubId);
    return {
      id,
      clubId,
      name,
      centralClubFound: Boolean(club),
      missing: fields.filter((field) =>
        !stringField(team, field) && !stringField(club, field)),
    };
  }).filter((team) => team.missing.length);
  console.log(JSON.stringify({
    seasonId,
    seasonTeamCount: seasonTeams.length,
    centralClubCount: centralTeams.length,
    incomplete,
  }, null, 2));
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
