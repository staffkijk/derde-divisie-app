const fs=require('fs');let p='tools/audit_result_processing.cjs',s=fs.readFileSync(p,'utf8');s=s.replace('await batch.commit();}','await batch.commit();if(emulator && value(\'--fail-after-batch\')===String(Math.floor(i/400)+1))throw Error(\'Injected emulator-only interruption after committed batch\');}');fs.writeFileSync(p,s);
p='functions/integration/result-processor.test.cjs';s=fs.readFileSync(p,'utf8');s=s.replace("assert.equal(child.status,0,child.stdout+child.stderr);","assert.equal(child.status,args.includes('--fail-after-batch=1')?1:0,child.stdout+child.stderr);");s=s.replace("assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,false);",`assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,false);
 await db.doc('users/u').update({punten_A:999});
 audit('--apply','--allow-fixture','--fail-after-batch=1',\`--output=\${path.join(dir,'interrupted.json')}\`);
 assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,true);
 audit('--apply','--allow-fixture','--resume-maintenance',\`--output=\${path.join(dir,'resumed.json')}\`);
 assert.equal((await db.doc('system/result_processing_maintenance').get()).data().enabled,false);
 assert.equal(audit().changes.length,0);`);
// The last CLI output argument intentionally overrides the default test output.
s=s.replace("value=name=>args.find(a=>a.startsWith(name+'='))", "value=name=>args.find(a=>a.startsWith(name+'='))");
fs.writeFileSync(p,s);
p='tools/audit_result_processing.cjs';s=fs.readFileSync(p,'utf8').replace("args.find(a=>a.startsWith(name+'='))","args.findLast(a=>a.startsWith(name+'='))");fs.writeFileSync(p,s);
