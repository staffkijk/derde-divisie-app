# Handmatige testchecklist

## Publiek en account

- [ ] Home als gast: desktop en mobiel, loading/empty/error states
- [ ] Login met knop en Enter vanuit e-mail/wachtwoord
- [ ] Verkeerde login toont duidelijke fout zonder crash
- [ ] Registratie maakt bestaande uservelden én compatibele favorite-teamvelden
- [ ] Privacy- en voorwaardenlinks werken
- [ ] Favoriete club kiezen en later wijzigen
- [ ] E-mail delen met poulebeheerder staat standaard uit

## Programma en standen

- [ ] Programma toont de juiste ronde, divisie en datumgroepen
- [ ] Programmafilter A en B
- [ ] Wedstrijden op dezelfde dag staan op tijd gesorteerd
- [ ] Ontbrekende tijd toont `Tijd onbekend`, geen onbedoelde 00:00
- [ ] Statussen gepland, afgelopen, uitgesteld, afgelast en gestaakt
- [ ] Stand A/B toont ook teams met nul wedstrijden
- [ ] Standvolgorde: punten, doelsaldo, goals voor, teamnaam
- [ ] Periodestanden tonen alleen finished wedstrijden

## Voorspellen

- [ ] Divisie A opent op eerstvolgende open ronde
- [ ] Divisie B opent op eerstvolgende open ronde
- [ ] Team voorspellen vindt wedstrijden via slug en naamfallback
- [ ] Centrale voorspelling wordt één keer opgeslagen
- [ ] Autosave en deadline-lock
- [ ] Punten na verwerken: exact, winnaar/gelijk en overige regels
- [ ] Algemene ranking en archiefranking blijven zichtbaar

## Poules

- [ ] Poule aanmaken met bestaand datamodel
- [ ] Open/gesloten poule joinen
- [ ] Pouledetail en ranking
- [ ] Centrale voorspelling telt mee
- [ ] Oude poulevoorspellingen blijven leesbaar tijdens migratiefase
- [ ] E-mailconsent standaard uit en nergens publiek zichtbaar
- [ ] Export bevat alleen consented e-mailadressen zodra export is gebouwd

## Moderator

- [ ] Uitslag invoeren en bulk opslaan
- [ ] `processingAttempts` en `lastProcessingRunId` worden gevuld
- [ ] Succes vult `processedAt` en `processedBy`
- [ ] Verwerkingsfout vult `processingError`
- [ ] Aangepaste uitslag herberekent stand en punten
- [ ] Uitgesteld, afgelast en gestaakt zonder scores
- [ ] Activity events zijn alleen functioneel en bevatten geen e-mail/token
- [ ] Ranking-, poule-, programma- en activity-export zodra fase 2 gereed is

## Data quality

- [ ] Teamsaantal per divisie
- [ ] Wedstrijden per divisie en ronde
- [ ] Ontbrekende/dubbele slugs
- [ ] Ontbrekende logo’s
- [ ] Ontbrekende tijd en bewuste 00:00
- [ ] Niet-verwerkte uitslagen en processing errors
- [ ] Standen en periodestanden aanwezig
- [ ] Aantallen users, poules en activity logs

## Release

- [ ] Desktopbreedtes 1024, 1280 en 1440
- [ ] Mobiel 360 en 390 breed
- [ ] Pagina-refresh op gebruikte web-routes
- [ ] Firestore-rules getest in emulator/staging
- [ ] Benodigde indexen zijn `Enabled`
- [ ] `dart format`
- [ ] `flutter analyze`
