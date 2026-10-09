const fs=require('node:fs');
let p='lib/features/voorspellen/bekijk_voorspellingen_screen.dart',s=fs.readFileSync(p,'utf8');
s=s.replace("import 'package:derde_divisie/data/firestore/season_paths.dart';","import 'package:derde_divisie/features/voorspellen/prediction_details_loader.dart';");
const a=s.indexOf('    final byMatch ='),b=s.indexOf('    final doelDivisie =',a);
s=s.slice(0,a)+`    final details = await PredictionDetailsLoader().load(widget.userId);
    final byMatch = details.predictions;
    final matchesById = details.matches;
`+s.slice(b);fs.writeFileSync(p,s);
p='functions/src/result-processor.ts';s=fs.readFileSync(p,'utf8');
s=s.replace('  const expected = fingerprint(m), base',`  if (m.processingStatus === 'processed' && m.processedInputKey === fingerprint(m)) return;
  const expected = fingerprint(m), base`);
s=s.replace('    const delta = next-old, div = division(m), userData = user.data()!;',`    const delta = next-old, div = division(m), userData = user.data()!;
    if (previous?.inputKey === expected && previous.predictionPath === selectedPath && previous.points === next &&
      (!p || (p.punten === next && p.verwerkt === processed)) &&
      (pouleId || userData.totalen === Math.max(integer(userData.punten_A),integer(userData.punten_B)))) return;`);fs.writeFileSync(p,s);
// Direct tests explicitly request work for changes to predictions and forced retry.
p='functions/integration/result-processor.test.cjs';s=fs.readFileSync(p,'utf8');
s=s.replace(" await processMatch(db,'A1');\n const ledger=", " await db.doc(`${base}/matches/A1`).update({processingRequest:FieldValue.increment(1)});\n await processMatch(db,'A1');\n const ledger=");fs.writeFileSync(p,s);
