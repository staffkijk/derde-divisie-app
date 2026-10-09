const fs=require('node:fs');
let p='lib/features/voorspellen/ranking_screen.dart',s=fs.readFileSync(p,'utf8');
s=s.replace("final ImageProvider? image = avatar.startsWith('http') ? NetworkImage(avatar) : avatar.startsWith('assets/') ? AssetImage(avatar) : null;", "ImageProvider? image;\n    if (avatar.startsWith('http')) { image = NetworkImage(avatar); }\n    else if (avatar.startsWith('assets/')) { image = AssetImage(avatar); }");fs.writeFileSync(p,s);
// Fix all unbalanced permission expressions using normalized source from HEAD.
p='firestore.rules';s=fs.readFileSync(p,'utf8');
for(const c of ['voorspellingen','poule_predictions','poule_voorspellingen','predictions']) {
 const a=s.indexOf(`    match /${c}/{predictionId}`),b=s.indexOf('\n    }',a);
 let block=s.slice(a,b);
 block=block.replace(/(allow create: if[\s\S]*?);/,m=>{const opens=(m.match(/\(/g)||[]).length,closes=(m.match(/\)/g)||[]).length;return m.slice(0,-1)+')'.repeat(opens-closes)+';';});
 block=block.replace(/(allow update: if[\s\S]*?);/,m=>{const opens=(m.match(/\(/g)||[]).length,closes=(m.match(/\)/g)||[]).length;return m.slice(0,-1)+')'.repeat(opens-closes)+';';});
 s=s.slice(0,a)+block+s.slice(b);
}
fs.writeFileSync(p,s);
