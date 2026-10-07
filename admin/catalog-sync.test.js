const {test}=require('node:test');
const assert=require('node:assert/strict');
const {merge,createPublisher}=require('./catalog-sync');
test('preserves remote servers and local metadata in existing movie',()=>{
 const health={status:'down',consecutiveFailures:3};
 const base={movies:[{id:'a',title:'Old',servers:[{id:'source-a',url:'a',health,replacementForId:'older',replacedById:'newer'}]}]};
 const local={movies:[{id:'a',title:'Edited',servers:[{id:'source-a',url:'a',health,replacementForId:'older',replacedById:'newer'}]}]};
 const remote={movies:[{id:'a',title:'Old',servers:[{url:'a'},{url:'b'}]},{id:'b'}]};
 assert.deepEqual(merge(base,local,remote),{movies:[{id:'a',title:'Edited',servers:[{id:'source-a',url:'a',health,replacementForId:'older',replacedById:'newer'},{url:'b'}]},{id:'b'}]});
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

test('publishing episode still replacements and explicit clearing preserves concurrent server updates',async()=>{
 const server={id:'source',url:'https://stream.example/old'};
 const base={series:[{id:'series',seasons:[{number:1,episodes:[{number:1,poster:'https://old/cover',servers:[server]},{number:2,poster:'https://old/cover',servers:[server]}]}]}]};
 const local=JSON.parse(JSON.stringify(base));
 local.series[0].seasons[0].episodes[0].poster='https://image.tmdb.org/t/p/w300/one.jpg';
 local.series[0].seasons[0].episodes[1].poster=null;
 const remote=JSON.parse(JSON.stringify(base));
 remote.series[0].seasons[0].episodes[0].servers[0].url='https://stream.example/refreshed';
 let published;
 await createPublisher()({base,local,deleted:new Set(),read:async()=>({sha:'current',catalog:remote}),write:async catalog=>{published=JSON.parse(JSON.stringify(catalog));return {ok:true,status:200};}});
 const episodes=published.series[0].seasons[0].episodes;
 assert.equal(episodes[0].poster,'https://image.tmdb.org/t/p/w300/one.jpg');
 assert.equal(episodes[1].poster,null);
 assert.equal(episodes[0].servers[0].url,'https://stream.example/refreshed');
});
