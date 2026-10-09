# Gemeten prestaties

Meting: 9 oktober 2026, Windows, Node 22, lokale Firestore-emulator. Fixture: 1.000 gebruikers, 612 wedstrijden, 612 voorspellingen, 36 teams en 100 activiteiten. `tools/benchmark_result_processing.cjs` voert de oude en nieuwe querypatronen uit op dezelfde gegevens; na één opwarmronde is de mediaan van vijf rondes opgeslagen in `query-benchmark.json`.

| Querypatroon | Voor (ms) | Na (ms) | Geretourneerde documenten voor → na |
|---|---:|---:|---:|
| Eerste pagina gebruikersranglijst | 160,97 | 39,91 | 1.000 → 50 |
| Moderator-dashboardstatistieken | 75,40 | 50,78 | 712 → 0 + 6 countresultaten |
| Relevante programmaronde | 43,17 | 32,41 | 306 → 1 |
| Wedstrijdgegevens bij 9 voorspellingen | 74,49 | 90,33 | 612 → 9 |
| Competitiestand inclusief vormgegevens | 72,50 | 15,17 | 720 → 18 |

De wedstrijdlookup bij negen voorspellingen was lokaal iets langzamer, ondanks veel minder overgedragen documenten. Dit is geen bewijs van lagere latency voor iedere afzonderlijke query. Aggregaties zijn databasequeries en hebben indexwerk en factureerbare reads: nul geretourneerde documenten betekent niet nul kosten. Tijden sluiten browserrendering, mobiele verbindingen, Firebase cold starts en productie-indexen uit.

Met de nieuwe pipeline duurden negen opeenvolgende bronwrites 60,51 ms. Na de laatste save waren alle negen serververwerkingen in deze fixture na 4.617,14 ms afgerond; de gecontroleerde gebruikersscore was precies 90 punten. Dit is één run met één gedeelde gebruiker, geen productie-SLA. Een same-day tijdwrite duurde mediaan 8,02 ms. De regressietests bewijzen daarnaast dat die wijziging geen nieuwe scoringpoging start.

Er is geen vergelijkbare gemeten baseline voor de volledige oude clientprocessor. Daarom wordt geen percentage winst voor puntenverwerking geclaimd. De nieuwe app wacht tijdens opslaan uitsluitend op de bronwrite; zij toont afgeleide verwerking afzonderlijk. De emulatorcases testen ook achttien gelijktijdige resultaten over beide divisies, correcties en retries.

De competitiestand haalt vormgegevens uit de 18 standdocumenten. Het oude patroon omvatte de standlistener plus DivisionDataService-reads van teams, alle wedstrijden en standen. De benchmark vergelijkt deze datastroom; historische tabelweergave blijft behouden. Periodestanden hebben gerichte divisie-/periodequeries.

De Fluttertests voor 612 voorspellingen bevestigen complete paginering en gegroepeerde matchloads voor zowel eigen als andermans voorspellingen. Deze test is een juistheidscontrole, geen gemeten mobiele laadtijd. Bij een gebruiker met alle 612 voorspellingen zijn nog steeds alle 612 gekoppelde wedstrijden nodig; er wordt geen fictieve besparing op die documenten geclaimd.

Herhalen: `npm run benchmark:processing`. Dit commando weigert gebruik zonder emulator en gebruikt uitsluitend een demo-project. Voor productievalidatie moeten na afzonderlijke toestemming de browser-openmomenten, Functions cold starts, completionlatenties en Firebase-usagecounters worden gemeten.
