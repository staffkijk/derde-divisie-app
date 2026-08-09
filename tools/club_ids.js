const clubs = require('./data/club_venues.json');

function normalizeClubName(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’']/g, '')
    .replace(/[^a-z0-9]/g, '');
}

function withoutKnownSponsor(value) {
  return value.replace(/jumbo$/, '');
}

const idsByName = new Map();
for (const club of clubs) {
  const normalized = normalizeClubName(club.name);
  const withoutSponsor = withoutKnownSponsor(normalized);
  const withoutPrefix = withoutSponsor.replace(/^(vv|sv|usv|vpv|hvv|rksv|fc)/, '');

  idsByName.set(normalized, club.clubId);
  idsByName.set(withoutSponsor, club.clubId);
  idsByName.set(withoutPrefix, club.clubId);
}

function clubIdForName(name) {
  const normalized = normalizeClubName(name);
  const withoutSponsor = withoutKnownSponsor(normalized);
  const withoutPrefix = withoutSponsor.replace(/^(vv|sv|usv|vpv|hvv|rksv|fc)/, '');
  const clubId = idsByName.get(normalized) || idsByName.get(withoutSponsor) ||
    idsByName.get(withoutPrefix);
  if (!clubId) throw new Error(`Geen stabiele clubId gevonden voor: ${name}`);
  return clubId;
}

module.exports = {clubIdForName, normalizeClubName};
