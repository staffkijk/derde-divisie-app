/* Actual Firebase client -> rules -> Firestore trigger -> Functions smoke test. */
const assert=require('node:assert/strict');
const {initializeApp}=require('firebase/app');const {getAuth,connectAuthEmulator,signInWithEmailAndPassword}=require('firebase/auth');
const {getFirestore,connectFirestoreEmulator,doc,getDoc,updateDoc,increment,deleteField}=require('firebase/firestore');
if(!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('All emulators required');
const app=initializeApp({apiKey:'emulator-key',projectId:'derde-divisie-app'}),auth=getAuth(app),db=getFirestore(app);
const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');connectFirestoreEmulator(db,host,Number(port));connectAuthEmulator(auth,'http://'+process.env.FIREBASE_AUTH_EMULATOR_HOST,{disableWarnings:true});
const match=doc(db,'seasons/2026-2027/matches/A_REGRESSION_01');
async function wait(){const until=Date.now()+90000;while(Date.now()<until){const d=(await getDoc(match)).data();if(d.processingStatus==='processed'&&d.processed)return;await new Promise(r=>setTimeout(r,200));}throw Error('Server processing did not complete');}
async function scores(a,b){assert.equal((await getDoc(doc(db,'users/regression-alice'))).data().punten_A,a);assert.equal((await getDoc(doc(db,'users/regression-bob'))).data().punten_A,b);}
async function main(){await signInWithEmailAndPassword(auth,'moderator@regression.test','Regression123!');
 await updateDoc(match,{status:'finished',homeScore:2,awayScore:1,processingRequest:increment(1),processingStatus:'pending',processed:false,verwerkt:false,predictionProcessingComplete:false});await wait();await scores(10,0);
 await updateDoc(match,{homeScore:0,awayScore:3,processingRequest:increment(1),processingStatus:'pending',processed:false,verwerkt:false,predictionProcessingComplete:false});await wait();await scores(0,7);
 await updateDoc(match,{status:'postponed',homeScore:deleteField(),awayScore:deleteField(),uitslagThuis:deleteField(),uitslagUit:deleteField(),processingRequest:increment(1),processingStatus:'pending',processed:false,verwerkt:false,predictionProcessingComplete:false});await wait();await scores(0,0);
 console.log('PASS: authenticated moderator saves, real Functions triggers, correction and rollback');process.exit(0);
}main().catch(e=>{console.error(e);process.exit(1);});
