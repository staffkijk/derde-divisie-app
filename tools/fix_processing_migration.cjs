const fs=require('node:fs'),cp=require('node:child_process');
let p='lib/features/moderator/mod_tools.dart',s=cp.execFileSync('git',['show','HEAD:'+p],{encoding:'utf8'}).replace(/\r\n/g,'\n');
s=s.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:derde_divisie/data/firestore/season_paths.dart';\nimport 'package:derde_divisie/features/moderator/result_processing_service.dart';");
for(const name of ['_forEachCollection','_herbouwAlgemeneUserTotalen','_resetAllePouleDeelnemersPunten']) {
 const start=s.indexOf('Future<void> '+name+'(');if(start>=0){const end=s.indexOf('\n}\n',s.indexOf('async {',start))+3;s=s.slice(0,start)+s.slice(end);}
}
for(const name of ['herstelVoorspellingenSpeelronde18A','herstelAlleAlgemeneVoorspellingenEnUserTotalen','herstelAllePoulePunten','herstelAllePeriodestanden','hardeResetEnHerberekenAlles','herberekenAlleWedstrijden']) {
 const start=s.indexOf('Future<void> '+name+'('),end=s.indexOf('\n}\n',s.indexOf('async {',start))+3;
 s=s.slice(0,start)+`Future<void> ${name}() async {
  final matches = await SeasonPaths.currentSeasonMatches${name==='herstelVoorspellingenSpeelronde18A' ? ".where('division', isEqualTo: 'A').where('round', isEqualTo: 18)" : ''}.get();
  for (final match in matches.docs.where((doc) => doc.id != '_meta')) {
    await ResultProcessingService.requestProcessing(match.id);
  }
}\n`+s.slice(end);
}
s=s.replace("await _db.collection('matches').doc(cleanWedstrijdId).get()","await SeasonPaths.currentSeasonMatches.doc(cleanWedstrijdId).get()");fs.writeFileSync(p,s);
p='firestore.rules';s=fs.readFileSync(p,'utf8');
for(const collection of ['voorspellingen','poule_predictions','poule_voorspellingen','predictions']){
 const start=s.indexOf(`    match /${collection}/{predictionId}`),end=s.indexOf('\n    }',start);
 let b=s.slice(start,end);b=b.replace(/;\r?\n      allow update/,');\n      allow update').replace(/;\r?\n      allow delete/,');\n      allow delete');s=s.slice(0,start)+b+s.slice(end);
}
fs.writeFileSync(p,s);
