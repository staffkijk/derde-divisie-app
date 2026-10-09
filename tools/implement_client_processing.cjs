const fs=require('node:fs');
const path='lib/data/services/poule_service.dart';
let s=fs.readFileSync(path,'utf8');
s=s.replace("import 'dart:developer' as developer;", "import 'package:derde_divisie/features/moderator/result_processing_service.dart';");
s=s.slice(0,s.indexOf('  /// Verwerk punten'))+`  Future<void> verwerkPuntenVoorPouleVoorspellingen({
    required String pouleId, required String matchId,
    required int echteHome, required int echteAway,
  }) => ResultProcessingService.requestProcessing(matchId);
}\n`;
fs.writeFileSync(path,s);
let p='functions/src/result-processor.ts';s=fs.readFileSync(p,'utf8').replace('expected: string): Promise<void>', 'expected: string, force = false): Promise<void>').replace('if (!aggregate.exists) {','if (!aggregate.exists || force) {').replace('if (aggregate.exists && JSON.stringify','if (!force && aggregate.exists && JSON.stringify');fs.writeFileSync(p,s);
p='functions/src/index.ts';s=fs.readFileSync(p,'utf8').replace('processMatchResult, retryMatchResult','processMatchResult, retryMatchResult, rebuildDivisionStandings');fs.writeFileSync(p,s);
