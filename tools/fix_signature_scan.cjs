const fs=require('node:fs');
let p='tools/fix_processing_migration.cjs',s=fs.readFileSync(p,'utf8').replaceAll("s.indexOf('\\n}\\n',start)","s.indexOf('\\n}\\n',s.indexOf('async {',start))");
fs.writeFileSync(p,s);
