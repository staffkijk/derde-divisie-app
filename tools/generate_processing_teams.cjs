const fs = require('node:fs');
const text = fs.readFileSync('lib/data/config/season_config.dart','utf8');
const entries = [...text.matchAll(/SeasonTeam\(\s*id: '([^']+)',\s*name: '((?:\\.|[^'])*)',[\s\S]*?division: division([AB]),[\s\S]*?logoFileName: '([^']+)'([\s\S]*?)\n    \),/g)].map(m => {
 const tail = m[5];
 const aliases = [...tail.matchAll(/'((?:\\.|[^'])*)'/g)].map(a=>a[1].replace(/\\'/g,"'"));
 aliases.push(m[4].replace(/^logo_/,'').replace(/\.[^.]+$/,''));
 return {id:m[1],name:m[2].replace(/\\'/g,"'"),division:m[3],aliases};
});
if(entries.length!==36) throw Error(`Expected 36 teams, got ${entries.length}`);
fs.writeFileSync('functions/src/season-teams.ts','// Mirrors SeasonConfig for the active season. Verified against Dart in tests.\nexport const teams = '+JSON.stringify(entries,null,2)+';\n');

const {spawnSync}=require('node:child_process');const path=require('node:path');
const formatted=spawnSync(process.execPath,[path.resolve('functions/node_modules/eslint/bin/eslint.js'),'--fix','src/season-teams.ts'],{cwd:path.resolve('functions'),stdio:'inherit'});if(formatted.status)throw Error('Team source formatting failed');
