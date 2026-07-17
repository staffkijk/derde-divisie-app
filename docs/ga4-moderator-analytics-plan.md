# GA4 moderator analytics plan

Dit plan beschrijft hoe het moderatorblok `Websitebezoek` echte GA4-data kan
tonen zonder bezoekersaantallen te verzinnen en zonder credentials in de
Flutter-client te plaatsen.

## Architectuur

- Flutter moderator dashboard leest alleen uit een eigen HTTPS Cloud Function.
- De Cloud Function gebruikt de Google Analytics Data API.
- De service account credentials blijven server-side via Firebase/Google Cloud
  secrets of de runtime service account.
- De Flutter-app krijgt alleen geaggregeerde, niet-persoonlijke statistieken.

## Vereiste configuratie

1. Maak of kies een GA4-property waarin zowel `derdediv.nl` als
   `www.derdediv.nl` in dezelfde web data stream meten.
2. Controleer dat beide domeinen hetzelfde GA4 measurement ID gebruiken.
3. Voeg beide domeinen toe aan dezelfde GA4-property en configureer waar nodig
   cross-domain/ongewenste referral-instellingen, zodat `derdediv.nl` en
   `www.derdediv.nl` niet als losse websites worden geïnterpreteerd.
4. Schakel de Google Analytics Data API in voor het Google Cloud-project.
5. Gebruik een service account voor de Cloud Function.
6. Geef het service-account e-mailadres in GA4 Property Access Management
   minimaal Viewer-toegang.
7. Configureer `GA4_PROPERTY_ID` als Firebase Functions parameterized
   configuration value.

## Cloud Function endpoints

Aanbevolen endpoint:

`GET /moderatorAnalytics/websiteVisits`

De function controleert eerst dat de Firebase Auth gebruiker moderator is.
Daarna worden de volgende GA4-rapporten opgehaald.

## Benodigde GA4 Data API queries

### Bezoekers vandaag

- Methode: `runReport`
- Date range: `today` tot `today`
- Metrics: `activeUsers`, eventueel `sessions`

### Bezoekers afgelopen 7 dagen

- Methode: `runReport`
- Date range: `7daysAgo` tot `today`
- Metrics: `activeUsers`, `sessions`

### Bezoekers afgelopen 30 dagen

- Methode: `runReport`
- Date range: `30daysAgo` tot `today`
- Metrics: `activeUsers`, `sessions`

### Actieve bezoekers nu

- Methode: `runRealtimeReport`
- Metrics: `activeUsers`
- Optioneel dimension: `deviceCategory`

### Bezoekers per dag

- Methode: `runReport`
- Date range: `30daysAgo` tot `today`
- Dimensions: `date`
- Metrics: `activeUsers`, `sessions`

### Meest bezochte pagina's

- Methode: `runReport`
- Date range: `30daysAgo` tot `today`
- Dimensions: `pagePath` of `pagePathPlusQueryString`
- Metrics: `screenPageViews`, `activeUsers`
- Limit: bijvoorbeeld 10

### Desktop, mobiel en tablet

- Methode: `runReport`
- Date range: `30daysAgo` tot `today`
- Dimensions: `deviceCategory`
- Metrics: `activeUsers`, `sessions`

### Verkeersbronnen

- Methode: `runReport`
- Date range: `30daysAgo` tot `today`
- Dimensions: `defaultChannelGroup`, eventueel `firstUserSourceMedium`
- Metrics: `activeUsers`, `sessions`

## Privacy

- Toon alleen geaggregeerde aantallen.
- Sla geen GA4-rijdata per bezoeker op in Firestore.
- Exporteer geen IP-adressen, user agents, e-mailadressen of identifiers naar
  activity logs.
- Cache geaggregeerde resultaten kort server-side, bijvoorbeeld 5 tot 15
  minuten, om quota te beschermen.

## Flutter dashboard

Zodra de function bestaat:

- voeg een `WebsiteAnalyticsService` toe;
- vervang de huidige `-` waarden in `Websitebezoek` door echte waarden;
- toon duidelijk labels voor `unieke actieve bezoekers`, `sessies` en `events`;
- toon een fout-/niet-geconfigureerd-paneel wanneer de function `not_configured`
  teruggeeft.
