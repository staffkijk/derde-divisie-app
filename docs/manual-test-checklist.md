# Handmatige testchecklist

## Publiek en account

- [ ] Home als gast: desktop en mobiel, loading/empty/error states
- [ ] Wedstrijdcentrum toont komende wedstrijden en laatste uitslagen
- [ ] Homeknoppen openen Programma, Stand A/B en Voorspellen
- [ ] Favoriete club verschijnt op home; ontbrekende club toont profiel-CTA
- [ ] Login met knop en Enter vanuit e-mail/wachtwoord
- [ ] Verkeerde login toont duidelijke fout zonder crash
- [ ] Registratie maakt bestaande uservelden én compatibele favorite-teamvelden
- [ ] Privacy- en voorwaardenlinks werken
- [ ] Favoriete club kiezen en later wijzigen
- [ ] E-mail delen met poulebeheerder staat standaard uit

## Programma en standen

- [ ] Er is één menu-item Programma met Divisie A/B-segment
- [ ] Weergave Speelronde toont alleen gekozen ronde
- [ ] Weergave Alle wedstrijden toont 34 rondes gegroepeerd en scrollbaar
- [ ] Moderator kan in beide programmaweergaven dezelfde editor openen
- [ ] Oude directe `ProgramScreen`-instantiaties blijven werken
- [ ] Programma toont de juiste ronde, divisie en datumgroepen
- [ ] Programmafilter A en B
- [ ] Divisie A toont geen enkele club of wedstrijd uit B, en omgekeerd
- [ ] Wedstrijden op dezelfde dag staan op tijd gesorteerd
- [ ] Ontbrekende tijd toont `Tijd onbekend`, geen onbedoelde 00:00
- [ ] Statussen gepland, afgelopen, uitgesteld, afgelast en gestaakt
- [ ] Klik op thuis- of uitclub opent read-only clubdetail
- [ ] Clubdetail toont positie, cijfers, volgende wedstrijd en resultaten
- [ ] Matrix toont thuisteams als rij en uitteams als kolom
- [ ] Matrix toont datum, uitslag en donkere diagonale cellen
- [ ] Matrix is horizontaal bruikbaar op desktop en mobiel
- [ ] Stand A/B toont ook teams met nul wedstrijden
- [ ] Iedere stand bevat maximaal 18 unieke clubs
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

- [ ] Overzicht scheidt Mijn poules en Openbare poules
- [ ] Poulekaart toont type, privacy, beheerder en deelnemersaantal
- [ ] Openbare poule kan veilig worden gejoined zonder dubbeltelling
- [ ] Privépoule kan niet via detail zonder wachtwoord worden gejoined
- [ ] Uitnodigen/deellink bevat poulecode
- [ ] Poule aanmaken met bestaand datamodel
- [ ] Poule aanmaken/bewerken met scope Wedstrijden, Eindstand of Beide
- [ ] Oude poule zonder `predictionScope` blijft op Wedstrijden staan
- [ ] Open/gesloten poule joinen
- [ ] Pouledetail en ranking
- [ ] Centrale voorspelling telt mee
- [ ] Oude poulevoorspellingen blijven leesbaar tijdens migratiefase
- [ ] E-mailconsent standaard uit en nergens publiek zichtbaar
- [ ] Export bevat alleen consented e-mailadressen zodra export is gebouwd

## Moderator

- [ ] Dashboardstatistieken laden wedstrijden, statussen, fouten en events
- [ ] Programma-export downloadt geldige CSV op web
- [ ] Uitslagenexport bevat alleen finished wedstrijden
- [ ] Rankingexport toont uitleg en geen misleidende actieve knop
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
