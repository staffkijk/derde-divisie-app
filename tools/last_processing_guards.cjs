const fs=require('fs');const edit=(p,f)=>fs.writeFileSync(p,f(fs.readFileSync(p,'utf8')));
edit('functions/integration/result-processor.test.cjs',s=>s.replace(/test\('server endpoints[\s\S]*?(?=\r?\n\r?\ntest\('B:)/,m=>m.replace(/A1/g,'A2')));
edit('functions/src/result-processor.ts',s=>s.replace(/  if \(m.processingStatus === "processed" && m.processedInputKey === fingerprint\(m\)\) return;\r?\n  const expected = fingerprint\(m\);/,`  let expected: string;
  try { expected=fingerprint(m); } catch(error) {
    await db.runTransaction(async tx=>{await checkMaintenance(tx,db);const current=await tx.get(matchRef);if(JSON.stringify(current.data())===JSON.stringify(m))tx.update(matchRef,{processed:false,verwerkt:false,processingStatus:"failed",predictionProcessingComplete:false,processingError:String(error)});});throw error;
  }
  if (m.processingStatus === "processed" && m.processedInputKey === expected) return;
 `));
edit('functions/src/result-functions.ts',s=>s.replace(/  await db.doc\(`seasons\/\$\{ACTIVE_SEASON\}\/matches\/\$\{data.matchId\}`\).update\(([\s\S]*?)\);\r?\n  return \{queued: true\};/,`  await db.runTransaction(async tx=>{
    const lock=await tx.get(db.doc('system/result_processing_maintenance'));if(lock.data()?.enabled)throw new functions.https.HttpsError('failed-precondition','Maintenance active.');
    tx.update(db.doc(\`seasons/\${ACTIVE_SEASON}/matches/\${data.matchId}\`),$1);
  });
  return {queued: true};`));
edit('lib/features/moderator/moderator_menu_screen.dart',s=>s.replace(/    await _writeResult\(\r?\n      match: match,[\s\S]*?\r?\n    \);\r?\n\r?\n    if \(!mounted\) return;/,m=>'    try {\n'+m.replace('    if (!mounted) return;','')+"    } catch (_) { _showSnack('Uitslag kon niet worden opgeslagen. Probeer opnieuw.'); return; }\n    if (!mounted) return;"));
