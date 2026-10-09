const fs=require('node:fs'),cp=require('node:child_process');
let p='firestore.rules',s=cp.execFileSync('git',['show','HEAD:'+p],{encoding:'utf8'}).replace(/\r\n/g,'\n');
s=s.replace('    function signedIn() {',`    function noDerivedPredictionFields() {
      return !request.resource.data.keys().hasAny(['punten','verwerkt','processed','verwerktVoorUitslag']);
    }
    function keepsDerivedPredictionFields() {
      return !request.resource.data.diff(resource.data).affectedKeys().hasAny(['punten','verwerkt','processed','verwerktVoorUitslag']);
    }
    function safeUserScores() {
      return request.resource.data.get('punten_A',0) == 0 && request.resource.data.get('punten_B',0) == 0 && request.resource.data.get('totalen',0) == 0 && !request.resource.data.keys().hasAny(['rankingName','punten']);
    }
    function keepsUserScores() {
      return !request.resource.data.diff(resource.data).affectedKeys().hasAny(['punten','punten_A','punten_B','totalen','rankingName','eindstandA_awarded','eindstandB_awarded']);
    }
    function signedIn() {`);
s=s.replace('(isOwner(uid) && hasNoModeratorClaims())','(isOwner(uid) && hasNoModeratorClaims() && safeUserScores())').replace('(isOwner(uid) && keepsModeratorClaimsUnchanged())','(isOwner(uid) && keepsModeratorClaimsUnchanged() && keepsUserScores())');
for(const c of ['voorspellingen','poule_predictions','poule_voorspellingen','predictions']) {
 const a=s.indexOf(`    match /${c}/{predictionId}`),b=s.indexOf('\n    }',a)+6;
 s=s.slice(0,a)+`    match /${c}/{predictionId} {
      allow read: if signedIn();
      allow create: if noDerivedPredictionFields() && (isModerator() || isNewPredictionOwner());
      allow update: if keepsDerivedPredictionFields() && (isModerator() || (isExistingPredictionOwner() && isNewPredictionOwner()));
      allow delete: if isModerator();
    }`+s.slice(b);
}
s=s.replace(`    match /seasons/{seasonId}/{document=**} {
      allow read: if true;
      allow write: if isModerator();
    }`,`    match /seasons/{seasonId} {
      allow read: if true;
      allow write: if isModerator();
      match /{collection}/{document=**} {
        allow read: if true;
        allow create: if isModerator() && !(collection in ['standings','periodStandings','processingAggregates','predictionContributions','pouleContributions']) && (collection != 'predictions' || noDerivedPredictionFields());
        allow update: if isModerator() && !(collection in ['standings','periodStandings','processingAggregates','predictionContributions','pouleContributions']) && (collection != 'predictions' || keepsDerivedPredictionFields());
        allow delete: if isModerator() && !(collection in ['standings','periodStandings','processingAggregates','predictionContributions','pouleContributions','matches']);
      }
    }`);
fs.writeFileSync(p,s);
