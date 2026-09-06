const {test}=require('node:test');
const assert=require('node:assert/strict');
const {merge,createPublisher}=require('./catalog-sync');
test('preserves remote servers and local metadata in existing movie',()=>{
 const base={movies:[{id:'a',title:'Old',servers:[{url:'a'}]}]};
 const local={movies:[{id:'a',title:'Edited',servers:[{url:'a'}]}]};
 const remote={movies:[{id:'a',title:'Old',servers:[{url:'a'},{url:'b'}]},{id:'b'}]};
 assert.deepEqual(merge(base,local,remote),{movies:[{id:'a',title:'Edited',servers:[{url:'a'},{url:'b'}]},{id:'b'}]});
});
test('preserves intentional deletions and remote metadata',()=>{
 assert.deepEqual(merge({movies:[{id:'a'},{id:'b'}]}, {movies:[{id:'a'}]}, {movies:[{id:'a',year:2024},{id:'b'}]}),{movies:[{id:'a',year:2024}]});
});
test('reads and merges before every write; concurrent callers share operation',async()=>{
 const publish=createPublisher(); let reads=0; const written=[];
 const options={base:{movies:[]},local:{movies:[{id:'local'}]},deleted:new Set(),
 read:async()=>({sha:String(++reads),catalog:{movies:[{id:'remote'+reads}]}}),
 write:async(catalog,sha)=>{written.push({catalog,sha});return {ok:written.length===2,status:409};}};
 const first=publish(options); assert.equal(publish(options),first); await first;
 assert.equal(reads,2); assert.deepEqual(written[1],{sha:'2',catalog:{movies:[{id:'remote2'},{id:'local'}]}});
});
test('aborts on read failure without writing',async()=>{
 let writes=0; await assert.rejects(createPublisher()({read:async()=>{throw Error('read failed')},write:async()=>{writes++}}));
 assert.equal(writes,0);
});
