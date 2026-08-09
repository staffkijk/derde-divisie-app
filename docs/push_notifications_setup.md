# Pushnotificaties instellen

De app ondersteunt nu volledig werkende in-app meldingen voor ontbrekende voorspellingen. Browserpush is voorbereid, maar vereist Firebase Console-instellingen die niet veilig in de repository horen.

## Handmatige Firebase-stappen

1. Open Firebase Console voor `derde-divisie-app`.
2. Controleer of Cloud Messaging voor de webapp actief is.
3. Maak of kopieer de Web Push certificate key pair, de publieke VAPID key.
4. Geef de publieke VAPID key via veilige configuratie door aan de Flutter webapp. Hardcode deze niet in Git.
5. Publiceer `web/firebase-messaging-sw.js` mee met de hosting build.
6. Sla FCM tokens per gebruiker op onder `users/{uid}/fcmTokens/{tokenId}`.
7. Verstuur geplande pushberichten server-side vanuit Cloud Functions, maximaal:
   - een herinnering ruim voor de deadline;
   - een laatste herinnering kort voor de deadline.

## Gedrag zonder pushconfiguratie

Zonder VAPID key blijft de applicatie normaal werken. De in-app notificatiebel, ongelezen teller en voorspellingherinneringen blijven beschikbaar.

## Datavelden

Gebruikersmeldingen staan onder:

- `users/{uid}/notifications/{notificationId}`

Belangrijke velden:

- `type`
- `title`
- `body`
- `seasonId`
- `division`
- `round`
- `missing`
- `missingMatchIds`
- `read`
- `createdAt`
- `updatedAt`

FCM tokens worden voorbereid onder:

- `users/{uid}/fcmTokens/{tokenId}`

Tokens zijn alleen leesbaar voor de eigenaar en moderators.
