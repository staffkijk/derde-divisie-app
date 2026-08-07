const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const root = path.join(__dirname, '../..');
const venueData = JSON.parse(
  fs.readFileSync(path.join(root, 'tools/data/club_venues.json'), 'utf8'),
);

test('venue data has 36 unique stable IDs and no invented locations', () => {
  const data = venueData;
  assert.equal(data.length, 36);
  assert.equal(new Set(data.map((row) => row.clubId)).size, 36);
  for (const row of data) {
    assert.ok(row.clubId);
    assert.ok(row.name);
    for (const key of ['venueName', 'venueAddress', 'venuePostalCode', 'venueCity']) {
      assert.equal(row[key], '');
    }
  }
  assert.ok(data.some((row) => row.clubId === 'vv_zwaluwen'));
  assert.ok(!data.some((row) => /kloetinge/i.test(row.clubId)));
});

test('venue IDs equal app config, team import and actual match clubs', () => {
  const expected = venueData.map((row) => row.clubId).sort();
  const dart = fs.readFileSync(
    path.join(root, 'lib/data/config/season_config.dart'),
    'utf8',
  );
  const activeBlock = dart.slice(
    dart.indexOf('static const List<SeasonTeam> teams = ['),
    dart.indexOf('static List<SeasonTeam> teamsForDivision'),
  );
  const appIds = [...activeBlock.matchAll(/id: '([^']+)'/g)]
    .map((match) => match[1])
    .sort();
  assert.deepEqual(appIds, expected);

  const {clubIdForName} = require('../../tools/club_ids');
  const importSource = fs.readFileSync(
    path.join(root, 'tools/import_teams_2026_2027.js'),
    'utf8',
  );
  const teamBlock = importSource.slice(
    importSource.indexOf('const TEAMS = ['),
    importSource.indexOf('];', importSource.indexOf('const TEAMS = [')),
  );
  const importIds = [...teamBlock.matchAll(/^  "([^"]+)",$/gm)]
    .map((match) => clubIdForName(match[1]))
    .sort();
  assert.deepEqual(importIds, expected);

  const matches = JSON.parse(
    fs.readFileSync(path.join(root, 'tools/matches_2026_2027.json'), 'utf8'),
  );
  const matchIds = [...new Set(
    matches.flatMap((match) => [
      clubIdForName(match.homeTeam),
      clubIdForName(match.awayTeam),
    ]),
  )].sort();
  assert.deepEqual(matchIds, expected);
});

test('venue importer dry run needs no credentials and performs no writes', () => {
  const result = spawnSync(process.execPath, ['tools/import_club_venues.js'], {
    cwd: root,
    encoding: 'utf8',
    env: {...process.env, GOOGLE_APPLICATION_CREDENTIALS: 'definitely-missing.json'},
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Modus: DRY RUN/);
  assert.match(result.stdout, /Firestore is niet geïnitialiseerd/);
  assert.match(result.stdout, /overgeslagen=36/);
});

test('venue importer refuses another project before Firestore access', () => {
  const result = spawnSync(
    process.execPath,
    ['tools/import_club_venues.js', '--project=ander-project'],
    {cwd: root, encoding: 'utf8'},
  );
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /project moet derde-divisie-app/);
});
