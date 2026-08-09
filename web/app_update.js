(function (global) {
  'use strict';

  const LOG_PREFIX = '[DerdeDiv update]';
  const RELOAD_KEY_PREFIX = 'derdediv_update_reload_';
  const LEGACY_CACHE_NAMES = new Set([
    'flutter-app-cache',
    'flutter-temp-cache',
    'flutter-app-manifest',
  ]);

  function releaseId(version) {
    const name = String(version?.version || 'unknown');
    const build = String(version?.build_number || '0');
    return `${name}+${build}`;
  }

  function versionedUrl(path, version) {
    const url = new URL(path, global.document?.baseURI || global.location?.href);
    url.searchParams.set('v', releaseId(version));
    return url.toString();
  }

  async function fetchDeployedVersion() {
    const url = new URL('version.json', global.document.baseURI);
    url.searchParams.set('_', Date.now().toString());
    const response = await global.fetch(url, {
      cache: 'no-store',
      credentials: 'same-origin',
      headers: { 'Cache-Control': 'no-cache' },
    });
    if (!response.ok) {
      throw new Error(`version.json gaf HTTP ${response.status}`);
    }
    return response.json();
  }

  async function removeLegacyFlutterCaches() {
    let changed = false;

    if ('serviceWorker' in global.navigator) {
      const registrations = await global.navigator.serviceWorker.getRegistrations();
      for (const registration of registrations) {
        const workers = [registration.active, registration.waiting, registration.installing];
        const isLegacyFlutterWorker = workers.some((worker) => {
          if (!worker) return false;
          return new URL(worker.scriptURL).pathname.endsWith('/flutter_service_worker.js');
        });
        if (isLegacyFlutterWorker) {
          changed = (await registration.unregister()) || changed;
          console.info(LOG_PREFIX, 'Oude Flutter-service-worker uitgeschreven.');
        }
      }
    }

    if ('caches' in global) {
      for (const cacheName of await global.caches.keys()) {
        if (LEGACY_CACHE_NAMES.has(cacheName)) {
          changed = (await global.caches.delete(cacheName)) || changed;
          console.info(LOG_PREFIX, `Oude Flutter-cache verwijderd: ${cacheName}`);
        }
      }
    }

    return changed;
  }

  function createUpdater() {
    let runningVersion;
    let checkInProgress;

    async function checkForUpdate() {
      if (checkInProgress) return checkInProgress;
      checkInProgress = (async () => {
        try {
          const deployedVersion = await fetchDeployedVersion();
          const deployedId = releaseId(deployedVersion);
          if (!runningVersion || deployedId === runningVersion) return;

          console.info(LOG_PREFIX, `Nieuwe release gevonden: ${runningVersion} -> ${deployedId}`);
          await removeLegacyFlutterCaches();

          const reloadKey = `${RELOAD_KEY_PREFIX}${deployedId}`;
          if (global.sessionStorage.getItem(reloadKey) === 'attempted') {
            console.warn(LOG_PREFIX, `Herlaadpoging voor ${deployedId} is al uitgevoerd; loop voorkomen.`);
            return;
          }

          global.sessionStorage.setItem(reloadKey, 'attempted');
          const target = new URL(global.location.href);
          target.searchParams.set('appVersion', deployedId);
          global.location.replace(target.toString());
        } catch (error) {
          console.warn(LOG_PREFIX, 'Versiecontrole overgeslagen; de app blijft beschikbaar.', error);
        } finally {
          checkInProgress = undefined;
        }
      })();
      return checkInProgress;
    }

    async function startAndLoad(flutter) {
      await removeLegacyFlutterCaches().catch((error) => {
        console.warn(LOG_PREFIX, 'Oude Flutter-cache kon niet volledig worden opgeruimd.', error);
      });

      let deployedVersion;
      try {
        deployedVersion = await fetchDeployedVersion();
        runningVersion = releaseId(deployedVersion);
        for (const build of flutter.buildConfig?.builds || []) {
          if (build.mainJsPath) {
            build.mainJsPath = versionedUrl(build.mainJsPath, deployedVersion);
          }
        }
        console.info(LOG_PREFIX, `Release ${runningVersion} wordt gestart.`);
      } catch (error) {
        console.warn(LOG_PREFIX, 'Releaseversie niet bereikbaar; Flutter start met de lokale configuratie.', error);
      }

      flutter.loader.load();

      global.addEventListener('pageshow', () => void checkForUpdate());
      global.document.addEventListener('visibilitychange', () => {
        if (global.document.visibilityState === 'visible') void checkForUpdate();
      });
    }

    return { checkForUpdate, startAndLoad };
  }

  const api = { createUpdater, releaseId, versionedUrl };
  global.DerdeDivUpdater = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
