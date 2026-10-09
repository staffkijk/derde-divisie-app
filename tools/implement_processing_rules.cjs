const fs=require('node:fs');
let p='firestore.rules',s=fs.readFileSync(p,'utf8');
s=s.replace("function hasNoModeratorClaims() {",`function noScoreFields() {
      return !request.resource.data.keys().hasAny(['punten', 'punten_A', 'punten_B', 'totalen', 'verwerkt', 'verwerktVoorUitslag', 'processed', 'rankingName']);
    }
    function keepsScoreFields() {
      return !request.resource.data.diff(resource.data).affectedKeys().hasAny(['punten', 'punten_A', 'punten_B', 'totalen', 'verwerkt', 'verwerktVoorUitslag', 'processed', 'rankingName']);
    }
    function hasNoModeratorClaims() {`);
s=s.replace('(isOwner(uid) && hasNoModeratorClaims())','(isOwner(uid) && hasNoModeratorClaims() && noScoreFields())');
// Registration legitimately initializes zero points; never let a user choose a positive score.
s=s.replace('&& noScoreFields()',`&& (!request.resource.data.keys().hasAny(['punten_A','punten_B','totalen','rankingName','punten']) ||
        (request.resource.data.get('punten_A',0) == 0 && request.resource.data.get('punten_B',0) == 0 && request.resource.data.get('totalen',0) == 0 && !request.resource.data.keys().hasAny(['rankingName','punten'])))`);
s=s.replace('(isOwner(uid) && keepsModeratorClaimsUnchanged())','(isOwner(uid) && keepsModeratorClaimsUnchanged() && keepsScoreFields())');
// Guard derived season collections. The broad previous season wildcard cannot remain.
s=s.replace(`    match /seasons/{seasonId}/{document=**} {
      allow read: if true;
      allow write: if isModerator();
    }`,`    match /seasons/{seasonId} {
      allow read: if true;
      allow write: if isModerator();
      match /{collection}/{document=**} {
        allow read: if true;
        allow write: if isModerator() && !(collection in ['standings','periodStandings','processingAggregates','predictionContributions','pouleContributions']) &&
          (collection != 'predictions' || (resource == null ? noScoreFields() : keepsScoreFields()));
      }
    }`);
for(const collection of ['voorspellingen','poule_predictions','poule_voorspellingen','predictions']) {
 const start=s.indexOf(`    match /${collection}/{predictionId}`),end=s.indexOf('\n    }',start);
 let block=s.slice(start,end);
 block=block.replace('allow create: if ', 'allow create: if noScoreFields() && (').replace(/;\n      allow update/,');\n      allow update');
 block=block.replace('allow update: if ', 'allow update: if keepsScoreFields() && (').replace(/;\n      allow delete/,');\n      allow delete');
 s=s.slice(0,start)+block+s.slice(end);
}
fs.writeFileSync(p,s);
p='lib/features/moderator/mod_tools.dart';s=fs.readFileSync(p,'utf8');
for(const name of ['_forEachCollection','_herbouwAlgemeneUserTotalen','_resetAllePouleDeelnemersPunten']) {
 const start=s.indexOf('Future<void> '+name+'('),end=s.indexOf('\n}',start)+2;
 if(start>=0)s=s.slice(0,start)+s.slice(end);
}
fs.writeFileSync(p,s);
