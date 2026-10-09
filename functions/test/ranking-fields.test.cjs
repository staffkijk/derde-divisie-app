const {test}=require('node:test');
const assert=require('node:assert/strict');
const {rankingNameForUser}=require('../lib/ranking-fields');

test('ranking metadata does not require or initialize score fields',()=>{
  assert.equal(rankingNameForUser({username:'  Club Fan  '}),'club fan');
  assert.equal(rankingNameForUser({username:'',usernameLower:'Supporter'}),'supporter');
  assert.equal(rankingNameForUser({}), 'onbekend');
  const user={username:'Fan',punten_A:21,punten_B:17,totalen:900};
  assert.equal(rankingNameForUser(user),'fan');
  assert.deepEqual(user,{username:'Fan',punten_A:21,punten_B:17,totalen:900});
});
