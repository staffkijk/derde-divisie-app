# Flutter Web/PWA releaseproces

De webapp gebruikt het versienummer uit `pubspec.yaml`. Flutter neemt dit bij
`flutter build web` automatisch over in het gegenereerde `build/web/version.json`.
De web-updater gebruikt de combinatie `version+build_number`, bijvoorbeeld
`1.0.0+6`, als unieke release-identificatie.

## Elke release

1. Verhoog in `pubspec.yaml` de regel `version:`. Verhoog minimaal het getal na
   de `+`, bijvoorbeeld van `1.0.0+6` naar `1.0.0+7`. Verhoog ook het semantische
   versienummer voor een functionele release, bijvoorbeeld `1.0.0+6` naar
   `1.1.0+7`.
2. Voer `flutter analyze` en de relevante tests uit.
3. Maak de productiebuild zonder Flutter app-shell-service-worker:

   `flutter build web --release --pwa-strategy=none`

4. Controleer vóór deploy dat `build/web/version.json` het nieuwe nummer bevat
   en dat `build/web/flutter_service_worker.js` leeg (0 bytes) is. Flutter 3.32.5
   laat bij strategie `none` bewust zo'n leeg migratiebestand achter.
5. Deploy daarna pas met `firebase deploy --only hosting`.

De optie `--pwa-strategy=none` is bewust: pushnotificaties kunnen hun aparte
`firebase-messaging-sw.js` blijven gebruiken, maar DerdeDiv gebruikt geen
service worker die appbestanden onderschept of vooraf cachet.

## Automatische afleiding

Er is geen handmatig tweede versiebestand. `version.json` wordt door Flutter uit
`pubspec.yaml` gegenereerd. Het ophogen zelf gebeurt bewust handmatig, zodat twee
verschillende releases nooit per ongeluk dezelfde cache-sleutel krijgen. Een CI-
pipeline kan later het buildnummer vóór de build automatisch verhogen of Flutter
aanroepen met `--build-name` en `--build-number`; ook die waarden komen in
`version.json` terecht.
