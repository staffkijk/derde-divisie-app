# Internetagenda

De publieke internetagenda wordt gemaakt door `calendarFeed` in `europe-west1`.
De function leest het actieve seizoen uit `system/current_season`, en haalt daarna
de wedstrijden, seizoensteams en centrale `teams/{clubId}`-documenten parallel op.
De dataset blijft vijf minuten
in een warme function-instance gecachet; Hosting/CDN-responses hebben eveneens een
cacheduur van vijf minuten en één minuut `stale-while-revalidate`.

## Feed-URL's

- `/agenda/alles.ics`
- `/agenda/divisie-a.ics`
- `/agenda/divisie-b.ics`
- `/agenda/team/{teamId}.ics`

De UI bouwt deze paden relatief aan de actieve Hosting-origin. `webcal:` wordt voor
Apple gebruikt. Outlook en Google krijgen hun eigen abonnementsroute en de HTTPS-URL
kan altijd handmatig worden gekopieerd.

## Accommodaties

Ondersteunde optionele velden zijn `venueName`, `venueAddress`, `venuePostalCode`
en `venueCity`. De bestaande seizoenonafhankelijke collectie `teams/{clubId}` is
de centrale clubbron. De prioriteit is: wedstrijd, seizoensteam, centrale club.
Een seizoensteam verwijst met `clubId` naar het centrale document.
Ontbrekende waarden worden niet aangevuld of verzonnen. Moderators kunnen een
afwijkende wedstrijdlocatie in het bestaande wedstrijdbewerkingsvenster invullen.

De repository bevat geen betrouwbare standaardaccommodaties in de team-import.
Daarom gelden bij uitsluitend de ingecheckte brondata alle 36 actieve clubs als
onvolledig. De actuele, exacte Firestore-status kan read-only worden gecontroleerd:

```powershell
node tools/report_missing_venues.js
```

Het script schrijft niets en geeft per club de na centrale fallback ontbrekende
velden als JSON terug.

Het versiebeheerde bronbestand staat in `tools/data/club_venues.json`. Nieuwe of
bevestigde gegevens kunnen eerst veilig worden gecontroleerd met:

```powershell
node tools/import_club_venues.js
```

Alleen `node tools/import_club_venues.js --apply` schrijft naar `teams/{clubId}`.
De importer weigert ieder Firebase-project behalve `derde-divisie-app`, gebruikt
`set(..., {merge: true})` en vult uitsluitend nog lege velden aan.

## Deploy (niet automatisch uitvoeren)

```powershell
firebase deploy --only functions:calendarFeed
firebase deploy --only hosting
```
