const assert = require('node:assert/strict');
const test = require('node:test');

global.location = { href: 'https://derdediv.nl/' };
const { releaseId, versionedUrl } = require('../web/app_update.js');

test('releaseId combineert pubspec-versie en buildnummer', () => {
  assert.equal(releaseId({ version: '1.2.3', build_number: '42' }), '1.2.3+42');
});

test('versionedUrl cache-bust main.dart.js per release', () => {
  assert.equal(
    versionedUrl('main.dart.js', { version: '1.2.3', build_number: '42' }),
    'https://derdediv.nl/main.dart.js?v=1.2.3%2B42',
  );
});

test('releaseId blijft bruikbaar bij ontbrekende velden', () => {
  assert.equal(releaseId({}), 'unknown+0');
});

test('updater herlaadt maximaal een keer voor dezelfde release', async () => {
  let deployed = { version: '1.0.0', build_number: '6' };
  let replacements = 0;
  const storage = new Map();

  global.document = {
    baseURI: 'https://derdediv.nl/',
    visibilityState: 'visible',
    addEventListener() {},
  };
  global.navigator = {};
  global.addEventListener = () => {};
  global.fetch = async () => ({ ok: true, json: async () => deployed });
  global.sessionStorage = {
    getItem: (key) => storage.get(key) || null,
    setItem: (key, value) => storage.set(key, value),
  };
  global.location = {
    href: 'https://derdediv.nl/',
    replace: () => { replacements += 1; },
  };

  const updater = require('../web/app_update.js').createUpdater();
  const flutter = {
    buildConfig: { builds: [{ mainJsPath: 'main.dart.js' }] },
    loader: { load() {} },
  };
  await updater.startAndLoad(flutter);
  assert.match(flutter.buildConfig.builds[0].mainJsPath, /v=1.0.0%2B6/);

  deployed = { version: '1.0.1', build_number: '7' };
  await updater.checkForUpdate();
  await updater.checkForUpdate();
  assert.equal(replacements, 1);
});
