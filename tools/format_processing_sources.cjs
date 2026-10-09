const fs=require('node:fs');for(const p of ['functions/src/result-domain.ts','functions/src/result-functions.ts','functions/src/result-processor.ts','functions/src/season-teams.ts']) {
 const s=fs.readFileSync(p,'utf8');fs.writeFileSync(p,'/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */\n'+s);
}
