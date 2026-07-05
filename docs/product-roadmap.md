# Product-roadmap DerdeDiv.nl

## Deze ronde

- uniforme programmapagina met speelronde- en seizoenweergave;
- divisiepagina met read-only speelschema-matrix;
- wedstrijdcentrum per divisie en uitgebreid favoriete-clubblok;
- clubdetail met programma, vorm en thuis/uitbalans;
- vernieuwd poule-overzicht, create/detailacties en veilige openbare deelname;
- poulescope voor wedstrijden, eindstandranking of beide, met veilige fallback;
- centrale divisiedatalaag en definitieve A/B-indeling voor 2026/2027;
- Geschiedenis als zelfstandig navigatie-item;
- favoriet-filter in voorspellen;
- bestaande moderatoromgeving, activity logging en CSV-exports behouden.

## Volgende veilige fase

- standtabel en alle pouleschermen migreren naar één gedeelde tabel/cardlaag;
- pouleranking de gekozen `predictionScope` volledig laten doorrekenen;
- moderator-audit met tijdreeksen via server-side aggregaties;
- persoonlijke notificatie-inbox met expliciete read-state;
- rankingexport nadat predictiontotalen tussen root- en season-bron zijn
  vergeleken.

## Datamigratierisico’s

Poule-predictions bestaan historisch in meerdere collecties. Deze mogen pas
worden uitgefaseerd na export, backfill naar centrale predictions en vergelijking
van alle gebruikers- en pouletotalen. Tot die tijd blijven fallbacks actief.

De huidige Firestore rules zijn te ruim voor een productiesysteem. Aanscherping
vereist eerst moderatorclaims, security-rule tests en stagingvalidatie; deze
ronde wijzigt de rules niet.

Pushnotificaties vereisen een backendstrategie voor tokens, toestemming,
planning, retries en privacy. Client-side activity logs zijn daarvoor geen
veilig alternatief.
