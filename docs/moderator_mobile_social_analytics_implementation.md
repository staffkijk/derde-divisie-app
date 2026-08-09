# Implementatieverslag moderator, mobiel, analytics en notificaties

## Gewijzigde onderdelen

- Activiteitenfiltering laadt maximaal 200 recente `activityLogs` en filtert lokaal op canonical event keys.
- Normale wedstrijdstatuslabels voor `scheduled` en `finished` worden niet meer als badge getoond.
- Mobiele hoofdnavigatie gebruikt vijf bestemmingen: Home, Divisies, Programma, Voorspellen en Meer.
- Voorspellen toont op mobiel compactere ronde/deadline/progressie-informatie.
- Moderator heeft een nieuw onderdeel `Sociale media` voor 16:9 programma- en uitslagenkaarten.
- Gebruikersactiviteit bevat statistiekkaarten en grafiekdatasets op basis van de geladen events.
- In-app notificaties voor ontbrekende voorspellingen zijn gekoppeld aan de notificatiebel.
- Browserpush is voorbereid met service worker en documentatie, zonder secrets.

## Nieuwe services

- `ActivityEventUtils`: canonical event keys, labels, veilige parsing en lokale filtering.
- `ActivityAnalytics`: lokale aggregatie voor moderatorgrafieken.
- `PredictionReminderService`: centrale berekening en synchronisatie van ontbrekende voorspellingen.

## Nieuwe collections en velden

- `users/{uid}/notifications/{notificationId}`
  - `type`
  - `title`
  - `body`
  - `seasonId`
  - `division`
  - `round`
  - `missing`
  - `missingMatchIds`
  - `read`
  - `resolved`
  - `createdAt`
  - `updatedAt`
  - `pushSentAt`
- `users/{uid}/fcmTokens/{tokenId}` is voorbereid voor FCM tokenopslag.

## Rules en indexes

- Firestore rules beperken notificaties en FCM tokens tot de eigenaar en moderators.
- Activity logs mogen geen gevoelige metadata bevatten en zijn alleen leesbaar voor moderators.
- Nieuwe index: collection group `notifications` op `read ASC, createdAt DESC`.
- Er zijn geen extra dropdownfilter-indexen voor activity logs toegevoegd.

## Cloud Functions

- `sendPredictionReminderPushes` is toegevoegd als Europe/Amsterdam scheduled function.
- De function verstuurt alleen ongelezen `missing_predictions` meldingen naar bestaande tokens en markeert `pushSentAt` om dubbele push te voorkomen.
- Er is geen deployment uitgevoerd.

## Mobiele breakpoints

- Mobiel: kleiner dan 600 px.
- Tablet: 600 tot circa 1024 px.
- Desktop: bestaande zijbalk vanaf circa 980 px blijft behouden.

## Sociale media export

- De preview is 1200 x 675 pixels.
- Data komt uit `SeasonPaths.currentSeasonMatches`.
- Sortering gebruikt datum, tijd en `roundMatchIndex`.
- PNG export gebruikt `RepaintBoundary`.
- X composer opent alleen tekst; de PNG moet handmatig worden toegevoegd.

## Notificatielogica

- Afgelaste wedstrijden tellen niet als verplicht ontbrekend.
- Uitgestelde wedstrijden blijven voorspelbaar zolang de bestaande deadline-logica dat toestaat.
- Deadline is centraal gekozen als 12:00 op de dag van de vroegste wedstrijd in de ronde, conform bestaande voorspelschermen.
- De homekaart en notificatiebel verdwijnen wanneer alles compleet of verlopen is.

## Eventregistratie

Canonical events:

- `screen_view`
- `navigation_click`
- `prediction_screen_opened`
- `round_selected`
- `division_selected`
- `prediction_saved`
- `prediction_completed`
- `social_card_generated`
- `notification_opened`

## Handmatige Firebase-stappen

Zie `docs/push_notifications_setup.md` voor VAPID key, Cloud Messaging en tokenregistratie. De applicatie werkt zonder die configuratie met in-app meldingen.

## Bekende beperkingen

- Browserpush kan pas end-to-end worden getest na Firebase Console-configuratie van Web Push.
- De bestaande Flutter tooling in deze lokale workspace bleef hangen door een langdurig Dart-proces; verificatie moet opnieuw worden uitgevoerd zodra dat proces is vrijgegeven.
