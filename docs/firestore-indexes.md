# Firestore-indexen

De deploybare configuratie staat in `firestore.indexes.json`. Controleer bij
Firebase-indexfouten altijd de echte query en voeg alleen de gevraagde index toe.

## Matches

- `division ASC, round ASC, roundMatchIndex ASC`
- `division ASC, round ASC, date ASC, kickoffTime ASC`
- legacy: `competitie ASC, speelronde ASC, datum ASC`

Queries op alleen `homeTeamSlug` of alleen `awayTeamSlug` gebruiken de
automatische single-field index. Voor een gecombineerde teamzoekopdracht zijn
twee queries nodig; Firestore ondersteunt geen OR over twee willekeurige velden
zonder aangepaste query/indexstrategie.

## Poules

- `seasonId ASC, createdAt DESC`

De rootcollectie blijft tijdens de compatibiliteitsfase in gebruik.

## Activity logs

- `eventType ASC, createdAt DESC`
- alleen `createdAt DESC` gebruikt de automatische single-field index

## Predictions

Huidige queries zijn voornamelijk gelijkheidsfilters op `gebruikerId`,
`wedstrijdId` of `matchId` en hebben geen composite index nodig. Voeg bij een
toekomstige ronde/deadlinequery de exacte door Firebase voorgestelde index toe.

## Deployment

Gebruik in de juiste Firebase-projectcontext:

```text
firebase deploy --only firestore:indexes
```

Indexbouw kan enige tijd duren. Deploy indexen vóór een release die de
bijbehorende query activeert.
