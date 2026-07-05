# Season data flow

## Actief seizoen

`SeasonConfig.activeSeasonId` is de enige bron voor het actieve seizoen. Nieuwe
wedstrijd-, team-, stand- en periodestandcode gebruikt `SeasonPaths`.

Primaire paden:

- `seasons/{seasonId}/teams`
- `seasons/{seasonId}/matches`
- `seasons/{seasonId}/standings`
- `seasons/{seasonId}/periodStandings`
- `seasons/{seasonId}/predictions`

De bestaande rootcollecties blijven voorlopig leesbaar voor compatibiliteit.
Er worden geen bestaande documenten verwijderd door de app.

## Teams

Een team gebruikt minimaal `id`/`slug`, `name`, `division` en een logo-koppeling.
UI-code hoort teamnamen via `SeasonConfig` op te zoeken en niet opnieuw als
losse lijsten vast te leggen. Registratie schrijft naast de oude velden ook
`favoriteTeamSlug`, `favoriteTeamName` en `favoriteDivision`.

De definitieve indeling 2026/2027 staat in `SeasonConfig`: 18 clubs in A en 18
clubs in B. `DivisionDataService` combineert deze indeling met de season-teams,
matches en standings. Divisieschermen gebruiken deze service als gedeelde
filterlaag. Een wedstrijd met een andere divisie of met clubs uit verschillende
definitieve divisies wordt niet getoond.

## Wedstrijden

Canonieke velden zijn:

- `division`, `round`, `roundMatchIndex`
- `homeTeamName`, `awayTeamName`
- `homeTeamSlug`, `awayTeamSlug`
- `scheduledAt` of `date` plus `kickoffTime`
- `homeScore`, `awayScore`
- `status`

Toegestane nieuwe statussen zijn `scheduled`, `finished`, `postponed`,
`cancelled` en `abandoned`. Oude statuswaarden worden alleen bij het lezen
genormaliseerd. `live` wordt niet geschreven.

Publieke sortering is datum/tijd, daarna `roundMatchIndex` en thuisteam.
Gebruik `MatchDateTimeFormatter` om 00:00 niet onbedoeld als aftraptijd te tonen.

## Standen en periodestanden

Alleen wedstrijden met `status == finished` en twee scores tellen mee.
`StandenService` herbouwt `seasons/{seasonId}/standings`; `PeriodestandService`
herbouwt `seasons/{seasonId}/periodStandings`. Beide schrijven canonieke Engelse
velden en tijdelijke Nederlandse compatibiliteitsvelden voor bestaande widgets.

## Result processing

1. Sla eindstand en compatibiliteitsvelden op.
2. Zet `processed` en `verwerkt` op `false`.
3. Verhoog `processingAttempts` en schrijf `lastProcessingRunId`.
4. Herbouw stand en periodestanden.
5. Verwerk centrale voorspellingen en gebruik tijdelijk de rootfallback
   `voorspellingen` wanneer season predictions leeg zijn.
6. Zet bij succes `processed`, `verwerkt`, `processedAt` en `processedBy`.
7. Bewaar bij fouten `processingError`; de eindstand blijft staan.

Uitgesteld, afgelast en gestaakt wissen scores en starten geen puntenverwerking.

## Predictions en poules

Nieuwe en bewerkte poules bewaren `predictionScope` met een van:
`matches`, `finalRanking` of `both`. Bestaande poules zonder dit veld vallen
bewust terug op `matches`, zodat hun huidige werking niet verandert. De
compatibiliteitsvelden `includeMatchPredictions` en
`includeFinalStandingPredictions` blijven daarnaast beschikbaar.

De gewenste eindsituatie is één centrale voorspelling per gebruiker/wedstrijd.
De huidige productiecode gebruikt nog zowel `voorspellingen`,
`seasons/{seasonId}/predictions` als historische poule-predictioncollecties.
Daarom is deze ronde bewust backward compatible.

Veilige vervolgmigratie:

1. Inventariseer en exporteer alle predictioncollecties.
2. Kies een canoniek document-id, bijvoorbeeld `{uid}_{matchId}`.
3. Backfill season predictions zonder brondata te verwijderen.
4. Laat poulerankings uitsluitend uit centrale predictions berekenen.
5. Vergelijk totalen per gebruiker en poule.
6. Schakel writes om.
7. Verwijder oude writes pas in een latere release; bewaar archiefdata.

## Activity logs

`ActivityLogService` schrijft functionele events naar `activityLogs` met `uid`,
`eventType`, `createdAt`, `seasonId`, optionele entityvelden en beperkte
metadata. Wachtwoorden, tokens, e-mailadressen en user agents worden gefilterd.
Logging is best effort en blokkeert nooit login of resultaatverwerking.

Client-side logging is niet volledig fraudebestendig. Voor betrouwbare analytics
en moderatormutaties is een Cloud Function of andere trusted backend nodig.

## Export

`CsvExportService` maakt op Flutter web read-only exports van het actieve
season-programma en finished uitslagen. Mobiel toont een duidelijke beperking.
Ranking- en predictionexport blijven uitgeschakeld zolang season predictions en
de rootfallback nog naast elkaar bestaan.

E-mail mag alleen worden geëxporteerd wanneer
`allowEmailSharingWithPouleOwner == true` en het lid tot de betreffende poule
behoort.

## Clubdetail

`ClubDetailScreen` leest uitsluitend teams, matches en standings van het actieve
seizoen. Het scherm toont standpositie, kerncijfers, volgende wedstrijd en
laatste uitslagen, volledig programma, vorm en een eenvoudige thuis/uitbalans.
Er worden geen historische of externe claims gegenereerd.

## Programma en matrix

De uniforme programmapagina kent twee leesweergaven: één speelronde en alle
wedstrijden. Beide gebruiken dezelfde `ProgramScreen` en dezelfde moderator-
editflow. De matrix leest dezelfde season matches en schrijft niets.

## Pouleschermen

Het poule-overzicht en detail lezen de bestaande rootcollectie `poules` en de
subcollectie `deelnemers`. Openbare deelname schrijft dezelfde compatibele
membershipdocumenten als de bestaande create/join-flow. Privépoules blijven via
de bestaande wachtwoordflow lopen. De ranking blijft tijdelijk rekening houden
met historische predictioncollecties; er is geen migratie uitgevoerd.

## Notificaties

De huidige veilige basis bestaat uit het update-log, gelezenstatus en activity
events. Geschikte toekomstige notificatie-events zijn:

- uitslag verwerkt of aangepast;
- behaalde punten en rankingwijziging;
- naderende deadline of nieuwe open ronde;
- poule-uitnodiging;
- uitgestelde, afgelaste of gestaakte wedstrijd.

Pushnotificaties vereisen een trusted backend, device-tokenbeheer, opt-in en een
privacy-/retentiebeleid. `activityLogs` worden niet rechtstreeks als publieke
persoonlijke notificatiefeed gebruikt, omdat deze moderatorgegevens kunnen
bevatten.

## Moderator testflow

1. Sla een nieuwe eindstand op.
2. Controleer scores, status en alle processingvelden.
3. Controleer stand en drie periodestanden.
4. Controleer voorspellerspunten en usertotalen.
5. Wijzig dezelfde uitslag en controleer waarschuwing/nieuwe totalen.
6. Test uitgesteld, afgelast en gestaakt zonder score.
7. Forceer een permissiefout en controleer `processingError`.
8. Controleer activity events zonder gevoelige metadata.

## Bekende beperkingen en fasering

- De poulevoorspelschermen schrijven nog naar historische aparte collecties.
  Omschakelen vereist eerst de bovenstaande data-audit en backfill.
- Productiewaardige security rules vereisen een moderator-claim of server-side
  rolmodel. De huidige brede regels zijn niet stilzwijgend aangescherpt om
  bestaande login- en beheerflows niet te blokkeren.
- Rankingexports, globale zoekfunctie en pushnotificaties zijn vervolgfases.
- Moderatorstatistieken zijn een eerste momentopname; tijdreeksen vereisen
  betrouwbare dagelijkse aggregatie via een backend.
- De centrale match rows zijn beschikbaar; bestaande schermen kunnen per scherm
  worden gemigreerd met visuele regressietests.
