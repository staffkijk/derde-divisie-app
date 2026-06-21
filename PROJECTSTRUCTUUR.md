# Projectstructuur Derde Divisie app

## Belangrijkste mappen

### lib/core
Algemene hulpfuncties en gedeelde utilities.

### lib/data/models
Datamodellen zoals wedstrijden, poules en voorspellingen.

### lib/data/services
Databronnen en services voor wedstrijden, poules en Firestore-koppelingen.

### lib/features
Hoofdonderdelen van de app per functioneel domein, zoals Derde Divisie, moderator, voorspellen en poules.

### lib/helpers
Ondersteunende logica die nog niet volledig onder core, data of features valt.

### lib/admin
Admin- en onderhoudstools, zoals backfill-scripts.

### lib/loggboek
Schermen en logica voor het update-logboek.

## Controlecommando's

```powershell
flutter analyze
git status