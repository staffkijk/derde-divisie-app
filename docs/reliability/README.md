# Uitslagverwerking en gecontroleerde ingebruikname

Deze wijziging verplaatst afgeleide wedstrijdgegevens naar Firebase Functions. De app slaat uitsluitend de actuele bronuitslag op. `processingStatus` onderscheidt pending, processing, failed en processed. Een wedstrijd krijgt pas processed nadat standen, algemene voorspellingen en poulebijdragen succesvol zijn verwerkt. Een fout bewaart de bronuitslag en wordt opnieuw aangeboden via Firebase failurePolicy; moderators kunnen bovendien opnieuw verwerking aanvragen.

## Transacties en invariant

- Iedere transactie leest de huidige wedstrijd en vergelijkt de inputfingerprint. Een oude taak mag een nieuwere uitslag niet overschrijven. De fingerprint omvat uitslag, status, teams, ronde, lokale wedstrijddag en processingRequest. Een tijdwijziging op dezelfde dag start geen puntenverwerking.
- Standen gebruiken één transactiedocument per divisie met wedstrijdbijdragen. Alleen bij initialisatie of expliciet herbouwen worden alle divisiewedstrijden opgehaald. Vervolgens wordt één bijdrage aangepast en worden de 18 competitie- en 54 perioderijen in één transactie overschreven. Er worden geen rijen verwijderd.
- Per gebruiker/wedstrijd en per poule/gebruiker/wedstrijd bewaart een ledger de toegepaste bijdrage. De voorspelling, ledger en gebruikers- of deelnemerstotalen worden in dezelfde transactie aangepast met `nieuw - oud`. Correcties, rollback en herhaalde events blijven daarmee idempotent. Vier onafhankelijke gebruikers worden tegelijk verwerkt; alle transacties zijn afgewacht voordat een foutstatus wordt gezet.
- Algemene totalen behouden de bestaande productregel `max(punten_A, punten_B)`. Poulepunten zijn de som van de geselecteerde poulevoorspellingen. Rondepunten blijven afleidbaar uit individuele voorspellingen. Eindstandbonussen gebruiken een aparte ledger en behouden 30/10/6/2 punten. Toekennen vereist alle 306 verwerkte resultaten en een onbetwiste rangschikking.
- Dubbele voorspellingen worden deterministisch geselecteerd op nieuwste geldige timestamp, vervolgens documentpad. Historische seasonId’s worden uitgesloten. Ontbrekende gebruikers/deelnemers worden als fout behandeld.

Het KNVB-handboek 2026/27, onderdelen 2.3 en 2.6, is gebruikt voor de periodegrenzen 1–12, 13–23 en 24–34 en de rangschikking. De voorlopige competitievolgorde gebruikt punten, minder gespeelde wedstrijden, doelsaldo, doelpunten voor en onderlinge resultaten. Onbesliste sportieve gelijke standen worden gemarkeerd; alfabetische presentatie beslist geen titel. Bron: https://www.knvb.nl/downloads/sites/bestand/knvb/30142/handboek-competitie-veldvoetbal.

PR #17 verbetert de oude clientketen met atomische gebruiker/prediction-updates en stabiele stand-ID’s. Die principes zijn meegenomen. De nieuwe keten leest bovendien uitslag en voorspelling binnen de transactie en bewaakt de nieuwste bron. De oude clientprocessors zijn vervangen door compatibele wrappers, zodat er geen tweede puntentoekenningsketen overblijft.

## Snellere gebruikersstromen

Ranglijsten laden 50 gebruikers per pagina, gesorteerd op score, rankingName en document-ID. De eigen positie gebruikt één gebruikersdocument en drie countqueries. RankingName en alle scorevelden moeten vóór publicatie gevuld zijn: Firestore orderBy laat documenten zonder die velden weg.

Voorspellingendetails halen gepagineerd alleen documenten voor de betreffende eigenaar op, combineren legacy en seizoensbronnen en halen alleen verwezen wedstrijden in groepen van maximaal 30 op. Dit werkt ook voor 612 voorspellingen. Lege data, fouten en timeouts beëindigen de laadstatus. Profielen tonen een fout/ontbrekend profiel met retry. Poules lezen dezelfde actuele wedstrijdbron als de processor.

De competitietabel leest 18 standdocumenten voor de divisie. Vormvakjes zijn onderdeel van de serverprojectie; de eerdere extra downloads van teams, wedstrijden en standen zijn verwijderd. De tabel respecteert de opgeslagen serverpositie. Het programma selecteert de relevante ronde met een beperkte query en behoudt zijn stream tussen rebuilds. Moderatorrechten en dashboardstatistieken worden per scherminstantie geladen; het dashboard gebruikt countqueries.

De agenda behoudt een procescache van maximaal vijf minuten en vraagt HTTP-hercontrole zonder aanvullende CDN-cache. Een feedclient bepaalt zelf wanneer hij opnieuw ophaalt; een agenda-app die zelden synchroniseert valt buiten deze servertermijn.

## Dry-run en herstel

Er zijn geen productiegegevens gewijzigd. Voor de eerste ingebruikname moet een bevoegde operator de productiebron controleren. Voer uit na Functions-build, met ADC van het bedoelde project:

```sh
node tools/audit_result_processing.cjs --project=derde-divisie-app --output=controle-2026-2027.json
```

Dry-run schrijft uitsluitend een lokaal rapport. Het rapporteert afwijkende standen, periodes, prediction-ledgers, gebruikers- en pouletotalen en vult rankingName in het correctievoorstel. Onbekende bronclubs, ontbrekende eigenaren, orphan-ledgers, ontbrekende seizoenidentiteit bij toegekende bonussen en dubbele bonusmarkers verhinderen apply. De controle verwacht 306 wedstrijden per divisie. Bekijk het volledige rapport en de reden van iedere puntenverlaging voordat toestemming wordt gevraagd.

**Productie-apply mag uitsluitend na expliciete toestemming voor het beoordeelde rapport.** Het script vereist daarvoor ook de projectbevestiging:

```sh
node tools/audit_result_processing.cjs --project=derde-divisie-app --apply --confirm-production=derde-divisie-app --output=herstel-2026-2027.json
```

Apply neemt eerst een onderhoudslock met een unieke eigenaar. Iedere correctietransactie controleert die eigenaar; clients kunnen de lock niet wijzigen. Security Rules blokkeren actuele bronmutaties en de servertransacties controleren dezelfde lock. Een volledige backup van alle te wijzigen documenten wordt lokaal geschreven voordat batches beginnen. Batches mergen alleen afgeleide velden; voorspellingen, bronuitslagen en historische seizoensdocumenten worden niet verwijderd. Een bestaande backup wordt nooit overschreven. Bewaar het rapport en de backup buiten versiebeheer.

Bij een onderbreking na de eerste batch blijft de lock actief. Inspecteer het eerdere rapport en backup en hervat onder dezelfde expliciete productieautorisatie met `--resume-maintenance` en **een nieuwe outputnaam**. Een gecontroleerde fout markeert de lock als interrupted. Bij een harde procescrash moet eerst worden vastgesteld dat de oude taak is gestopt; geef vervolgens ook `--takeover-run=<owner>` met de eigenaar uit het lockdocument op. Een actieve taak wordt anders niet overgenomen. Hervatten herberekent vanuit de bron; zet de lock niet handmatig uit terwijl de database gedeeltelijk is gerepareerd. Draai na succesvol herstel opnieuw dry-run en eis nul wijzigingen en nul inhoudelijke issues. Emulator-only `--allow-fixture` en `--fail-after-batch` bestaan uitsluitend voor regressietests.

Legacy bonusdocumenten zonder expliciet actief seizoen moeten handmatig aan het juiste seizoen worden gekoppeld na controle; er wordt geen seizoen gegokt. Het script behoudt expliciet gemarkeerde actieve bonussen. Het herberekent niet automatisch al toegekende eindstandbonussen op basis van een onafgemaakte competitie.

## Ingebruikname na toestemming

1. Controleer de dry-run, backupmogelijkheden en bestaande dataformaten, inclusief bonusmarkers. Verwijder of stop eventueel extern draaiende oude puntenverwerkers: zij staan niet in deze repository.
2. Plan een onderhoudsmoment. Deploy de samengestelde indexen en wacht tot ze gereed zijn. Bereid serverfuncties en aangescherpte regels voor; nieuwe app en regels moeten samen worden uitgerold omdat oude clients afgeleide punten proberen te schrijven.
3. Deploy de Functions en regels uitsluitend na afzonderlijke expliciete toestemming. Voer het goedgekeurde herstel uit en verifieer nul afwijkingen, rankingName en numerieke scorevelden voor alle gebruikers.
4. Publiceer de nieuwe app na controle van de serverketen. Test één uitslag, negen snelle uitslagen, een correctie en een same-day tijdwijziging met het bevoegde account. Controleer de verwerkingsstatus en uiteindelijke punten.
5. Bewaak failed-statussen en Functions-retries. Ontbrekende brongegevens moeten worden hersteld; oneindig herproberen repareert geen verkeerde club-ID of ontbrekende deelnemer.

De bestaande Windows integratieketen is aangepast zodat hij Functions-emulatorverwerking afwacht. In CI worden geen productiegegevens geschreven of hostingdeploys uitgevoerd. Een eventuele rollback naar oude clients vereist ook passende server-/regelrollback; publiceer de oude client niet naast de nieuwe processor.

## Herhaalbare controle

```sh
flutter analyze
flutter test
npm --prefix functions run lint
npm --prefix functions test
npm run test:processing
npm run test:security
npm run test:web-update
npm run benchmark:processing
```

Scenario’s A–I controleren bronresultaten, correcties, rollback, dubbele verwerking, parallelle moderators, gedeelde gebruikers en onderbreking na algemene verwerking. De emulator vergelijkt alle standrijen met de bron en gebruikers-/pouletotalen met onafhankelijke sommen. J controleert same-day tijdmutaties en metadata-events. Fluttertests controleren K en L: error/retry/empty, navigatie, paginering en 612 eigen/andermans voorspellingen. Hersteltests controleren dry-run, backup, herhaald herstel en de onderhoudslock. Securitytests blokkeren afgeleide puntenwrites voor zowel gebruikers als moderators; alleen Admin SDK-servercode kan die gegevens schrijven.

Voor prestatiemetingen en hun beperkingen zie `performance.md` en `query-benchmark.json`. Lokale querytijden zijn geen gemeten productie- of mobiele laadtijden.
