const fs=require('fs');const edit=(p,f)=>fs.writeFileSync(p,f(fs.readFileSync(p,'utf8')));
edit('functions/src/index.ts',s=>s.replace(/^    const (home|away) = .*\r?\n/gm,''));
edit('functions/src/final-points.ts',s=>s.replace('ACTIVE_SEASON, Data,','ACTIVE_SEASON,'));
edit('test/security/firestore-emulator.test.cjs',s=>s.replace("syncEnabled: true,\n    }));","syncEnabled: true,\n    }, {merge: true}));").replace("syncEnabled: true,\r\n    }));","syncEnabled: true,\r\n    }, {merge: true}));"));
edit('lib/features/voorspellen/prediction_details_loader.dart',s=>s.replace("'${source>=3 ? 'season' : 'legacy'}/${doc.id}'","'${source>=3 ? 'seasons/2026-2027/predictions' : 'voorspellingen'}/${doc.id}'"));
edit('firestore.rules',s=>s.replace('allow delete: if isModerator();\n\n      match /notifications','allow delete: if !processingMaintenance() && isModerator();\n\n      match /notifications').replace('allow delete: if isModerator();\r\n\r\n      match /notifications','allow delete: if !processingMaintenance() && isModerator();\r\n\r\n      match /notifications').replace('allow delete: if isModerator() || isPouleOwner(pouleId) || isOwner(uid);','allow delete: if !processingMaintenance() && (isModerator() || isPouleOwner(pouleId) || isOwner(uid));').replace('function signedIn() {',`function noBonusFields() {
      return !request.resource.data.keys().hasAny(['eindstand_A_punten','eindstand_B_punten']);
    }
    function keepsBonusFields() {
      return !request.resource.data.diff(resource.data).affectedKeys().hasAny(['eindstand_A_punten','eindstand_B_punten']);
    }
    function signedIn() {`).replace(/(match \/eindstand_voorspellingen\/\{predictionId\} \{)[\s\S]*?(?=\n    match \/voorspel_punten)/,`$1
      allow read: if signedIn();
      allow create: if !processingMaintenance() && noBonusFields() && (isModerator() || isNewPredictionOwner());
      allow update: if !processingMaintenance() && keepsBonusFields() && (isModerator() ||
        ((isExistingPredictionOwner() || isOwnerlessOwnEindstandDocument(predictionId)) && isNewPredictionOwner()));
      allow delete: if !processingMaintenance() && isModerator();
    }
`).replace('allow write: if isModerator();\n    }\n\n    match /seasons','allow write: if false;\n    }\n\n    match /seasons').replace('allow write: if isModerator();\r\n    }\r\n\r\n    match /seasons','allow write: if false;\r\n    }\r\n\r\n    match /seasons'));
edit('functions/src/result-functions.ts',s=>s.replace('p.pouleId, p.scoreThuis, p.scoreUit, p.homeScore, p.awayScore, p.timestamp?.toMillis(), p.seasonId','p.pouleId, p.poule, p.scoreThuis, p.scoreUit, p.homeScore, p.awayScore, p.homeGoals, p.awayGoals, p.thuisScore, p.uitScore, p.timestamp?.toMillis(), p.seasonId').replace('const p=after ?? before; if (!p || (p.seasonId && p.seasonId !== ACTIVE_SEASON)) return;\r\n  const id=p.matchId ?? p.wedstrijdId;',`const ids=new Set([before,after].filter(p=>p && (!p.seasonId || p.seasonId===ACTIVE_SEASON)).map(p=>p.matchId ?? p.wedstrijdId));
  for(const id of ids) {`).replace('const p=after ?? before; if (!p || (p.seasonId && p.seasonId !== ACTIVE_SEASON)) return;\n  const id=p.matchId ?? p.wedstrijdId;',`const ids=new Set([before,after].filter(p=>p && (!p.seasonId || p.seasonId===ACTIVE_SEASON)).map(p=>p.matchId ?? p.wedstrijdId));
  for(const id of ids) {`).replace('if (typeof id !== "string" || id.includes("/")) return;','if (typeof id !== "string" || id.includes("/")) continue;').replace(/(tx.update\(ref, \{processingRequest:[\s\S]*?\n  \}\);)\r?\n\}/,'$1\n  }\n}'));
