const fs=require('node:fs');
let p='functions/src/result-domain.ts',s=fs.readFileSync(p,'utf8');
const a=s.indexOf('  sorted.sort('),b=s.indexOf('  return sorted.map',a);
s=s.slice(0,a)+`  const compare = (a: Data, b: Data) => b.points-a.points || a.played-b.played ||
    (b.goalsFor-b.goalsAgainst)-(a.goalsFor-a.goalsAgainst) || b.goalsFor-a.goalsFor;
  sorted.sort(compare);
  // KNVB 2026/27 section 2.6: tied teams use their mutual results.
  // Period titles explicitly exclude this tie-breaker (section 2.3).
  for (let start=0; start<sorted.length;) {
    let end=start+1; while(end<sorted.length && compare(sorted[start],sorted[end])===0) end++;
    if(end-start>1 && !period) {
      const group=sorted.slice(start,end), ids=new Set(group.map(r=>r.teamId));
      const mutual: Data=Object.fromEntries(group.map(r=>[r.teamId,{points:0,gf:0,ga:0}]));
      for(const c of Object.values(contributions) as Data[]) {
        if(!c || !ids.has(c.home) || !ids.has(c.away)) continue;
        for(const [id,gf,ga] of [[c.home,c.h,c.a],[c.away,c.a,c.h]]) {
          mutual[id].gf+=gf; mutual[id].ga+=ga; mutual[id].points+=gf>ga?3:gf===ga?1:0;
        }
      }
      const tie=(a:Data,b:Data)=>mutual[b.teamId].points-mutual[a.teamId].points ||
        (mutual[b.teamId].gf-mutual[b.teamId].ga)-(mutual[a.teamId].gf-mutual[a.teamId].ga) || mutual[b.teamId].gf-mutual[a.teamId].gf;
      group.sort((a,b)=>tie(a,b) || a.teamName.localeCompare(b.teamName));
      for(const row of group) row.sportingTie=group.some(other=>other!==row && tie(row,other)===0);
      sorted.splice(start,group.length,...group);
    } else if(end-start>1) {
      const group=sorted.slice(start,end).sort((a,b)=>a.teamName.localeCompare(b.teamName));
      for(const row of group) row.sportingTie=true;
      sorted.splice(start,group.length,...group);
    }
    start=end;
  }
`+s.slice(b);fs.writeFileSync(p,s);
p='functions/src/result-processor.ts';s=fs.readFileSync(p,'utf8');
s=s.replace('    const processed = !!r && !!p', '    const processed = !!r && !!p');
s=s.replace('const next = processed ? points(score(p!, true), score(p!, false), r![0], r![1]) : 0;', 'const next = processed && p && r ? points(score(p, true), score(p, false), r[0], r[1]) : 0;');
s=s.replace('user.data()!','user.data() ?? {}').replace('const resultKey = processed ? `${r![0]}-${r![1]}` : "";','const resultKey = processed && r ? `${r[0]}-${r[1]}` : "";').replaceAll('latest.data()!', 'latest.data() ?? {}');
fs.writeFileSync(p,s);
p='functions/src/result-functions.ts';s=fs.readFileSync(p,'utf8').replaceAll('change.after.data()!', 'change.after.data() ?? {}');fs.writeFileSync(p,s);
p='functions/src/index.ts';s=fs.readFileSync(p,'utf8');
s=s.replace('    const data = change.after.data() || {};',`    const data = change.after.data() || {};
    const sourceFields = (p: any) => p ? [p.gebruikerId,p.userId,p.wedstrijdId,p.matchId,p.scoreThuis,p.scoreUit,p.homeGoals,p.awayGoals,p.timestamp?.toMillis()] : null;
    if (JSON.stringify(sourceFields(change.before.data())) === JSON.stringify(sourceFields(data))) return;`);
s=s.replace('    const home = (data.scoreThuis ?? data.homeGoals ?? null) as number | null;\r\n    const away = (data.scoreUit ?? data.awayGoals ?? null) as number | null;','');
var start=s.indexOf('          await destRef.set('),end=s.indexOf('\n        })()',start);
s=s.slice(0,start)+`          await db.runTransaction(async (tx) => {
            const current=await tx.get(change.after.ref), live=current.data();
            const destination=await tx.get(destRef);
            if (!live || String(live.gebruikerId || live.userId || '')!==uid || String(live.wedstrijdId || live.matchId || '')!==matchId) return;
            const submitted=live.timestamp || live.updatedAt;
            if (!submitted || (settings.startAt && submitted.toMillis()<settings.startAt.toMillis())) return;
            const home=live.scoreThuis ?? live.homeGoals,away=live.scoreUit ?? live.awayGoals;
            if(destination.data()?.scoreThuis===home && destination.data()?.scoreUit===away && destination.data()?.timestamp?.toMillis()===submitted.toMillis()) return;
            tx.set(destRef,{pouleId,userId:uid,matchId,wedstrijdId:matchId,homeGoals:home,awayGoals:away,
              scoreThuis:home,scoreUit:away,timestamp:submitted,seasonId:live.seasonId ?? '2026-2027',
              syncedFrom:'global',syncedAt:admin.firestore.FieldValue.serverTimestamp(),sourceUpdatedAt:submitted},{merge:true});
          });`+s.slice(end);fs.writeFileSync(p,s);
p='lib/features/moderator/moderator_tools_screen.dart';s=fs.readFileSync(p,'utf8');
for(const text of ['Algemene voorspellingen en usertotalen zijn hersteld.','Alle poulepunten zijn hersteld.','Periodestanden zijn hersteld.','Speelronde 18 A is opnieuw verwerkt.','Sync afgerond.','Reset uitgevoerd.','Volledige reset uitgevoerd.'])s=s.replace(text,'Verwerking aangevraagd. Volg de status bij de wedstrijden.');
fs.writeFileSync(p,s);
p='firestore.rules';s=fs.readFileSync(p,'utf8');
var start=s.indexOf('      match /deelnemers/{uid}'),end=s.indexOf('\n    }',start);
s=s.slice(0,start)+`      match /deelnemers/{uid} {
        allow read: if signedIn();
        allow create: if request.resource.data.get('punten',0) == 0 && (isModerator() || isPouleOwner(pouleId) || isOwner(uid));
        allow update: if !request.resource.data.diff(resource.data).affectedKeys().hasAny(['punten']) && (isModerator() || isPouleOwner(pouleId) || isOwner(uid));
        allow delete: if isModerator() || isPouleOwner(pouleId) || isOwner(uid);
      }
      match /{collection}/{document=**} {
        allow read: if signedIn();
        allow write: if collection != 'deelnemers' && (isModerator() || isPouleOwner(pouleId));
      }`+s.slice(end);fs.writeFileSync(p,s);

