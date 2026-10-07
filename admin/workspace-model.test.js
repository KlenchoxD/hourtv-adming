const test=require('node:test');
const assert=require('node:assert/strict');
let model;
try{model=require('./workspace-model')}catch(e){if(e.code!=='MODULE_NOT_FOUND')throw e;model={}}
const movie=(id,title='Título')=>({id,title,year:2026,genre:'Drama',rating:0});
const catalog=(movies=[],series=[],sources=[])=>({movies,series,sources});

test('limits_large_catalog',()=>{
  assert.equal(typeof model.buildRows,'function','workspace model must exist');
  const rows=model.buildRows(catalog(Array.from({length:10000},(_,i)=>movie('m'+i))),null);
  assert.equal(model.getView(rows,{pageSize:25,page:1}).rows.length,25);
  assert.equal(model.getView(rows,{pageSize:500,page:1}).rows.length,100);
  assert.equal(model.getView(rows,{pageSize:25,page:99999}).page,400);
});
test('keeps_original_index_after_filter',()=>{
  const rows=model.buildRows(catalog([movie('1','Uno'),movie('2','Dos'),movie('3','Tres')]),null);
  const view=model.getView(rows,{query:'DOS'});
  assert.equal(view.total,1);assert.equal(view.rows[0].index,1);assert.equal(view.rows[0].collection,'movies');
});
test('duplicate_and_missing_ids',()=>{
  const rows=model.buildRows(catalog([movie('x'),movie('x'),movie(undefined),movie(undefined)],[movie('x')]),null);
  assert.equal(new Set(rows.map(r=>r.key)).size,5);
  assert.equal(model.resolveSelection(rows,rows[1].key).index,1);
  assert.equal(model.resolveSelection(rows,'nope'),null);
});
test('optional_fields',()=>{
  const input=catalog([null,{},movie(0)]);const before=JSON.stringify(input);
  const rows=model.buildRows(input,null);
  assert.equal(rows.length,2);assert.deepEqual(rows[0].missing,['año','género','rating']);
  assert.equal(model.getView(rows,{query:'no title'}).total,0);assert.equal(JSON.stringify(input),before);
});
test('pending_is_metadata_not_draft',()=>{
  const input=catalog([movie('complete'),{id:'incomplete',title:'Otro'}],[],[{id:'source',name:'TV'}]);
  const rows=model.buildRows(input,catalog());
  assert.equal(model.getView(rows,{section:'pending'}).total,1);
  assert.equal(model.getView(rows,{status:'complete'}).total,1);
  assert.equal(model.getView(rows,{section:'live'}).total,1);
});
test('clamps_page_after_delete',()=>{
  const rows=model.buildRows(catalog([movie('one')]),null);
  assert.equal(model.getView(rows,{page:2,pageSize:25}).page,1);
  const empty=model.getView([],{page:0,pageSize:NaN});
  assert.equal(empty.page,1);assert.equal(empty.pageSize,25);assert.equal(empty.total,0);
});
test('unknown_baseline',()=>{
  assert.deepEqual(model.summarizeChanges(catalog([movie('x')]),null),{known:false,added:0,modified:0,removed:0,total:0});
  assert.equal(model.buildRows(catalog([movie('x')]),null)[0].change,'unknown');
});
test('counts_added_modified_removed',()=>{
  const base=catalog([movie('same'),movie('changed'),movie('gone')]);
  const local=catalog([movie('same'),movie('changed','Nueva'),movie('added')]);
  assert.deepEqual(model.summarizeChanges(local,base),{known:true,added:1,modified:1,removed:1,total:3});
  assert.equal(model.getView(model.buildRows(local,base),{status:'changed'}).total,2);
  const reordered={rating:0,genre:'Drama',year:2026,title:'Título',id:'same'};
  assert.equal(model.summarizeChanges(catalog([reordered]),catalog([movie('same')])).total,0);
});
test('nested_server_and_episode_changes',()=>{
  const base=catalog([],[{...movie('s'),seasons:[{number:0,episodes:[{number:1,poster:null,servers:[{url:'https://example.test/a'}]}]}]}]);
  const local=JSON.parse(JSON.stringify(base));local.series[0].seasons[0].episodes[0].poster='https://example.test/still.jpg';
  assert.equal(model.summarizeChanges(local,base).modified,1);
  local.series[0].seasons[0].episodes[0].poster=null;local.series[0].seasons[0].episodes[0].servers[0].url='https://example.test/b';
  assert.equal(model.summarizeChanges(local,base).modified,1);
  assert.equal(model.getView(model.buildRows(local,base),{type:'series'}).total,1);
  assert.equal(model.getView(model.buildRows(local,base),{type:'movies'}).total,0);
});
