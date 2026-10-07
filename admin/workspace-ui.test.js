const test=require('node:test');const assert=require('node:assert/strict');const {openWorkspace}=require('./workspace-test-helpers');
const movie=(i)=>({id:'m'+i,title:'Título '+i,year:2026,genre:'Drama',rating:7,servers:[{name:'Servidor',language:'Español',url:'https://example.test/video'}]});
test('table is bounded and filtered row opens original editor',async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:Array.from({length:80},(_,i)=>movie(i)),series:[],sources:[]}});if(!page)return;
  assert.equal(await page.locator('#list tbody tr').count(),25);
  await page.getByLabel('Buscar título',{exact:true}).fill('Título 71');
  await page.getByLabel('Buscar título',{exact:true}).press('Enter');
  await page.locator('#list .title-select').click();
  assert.equal(await page.locator('#overlay.open').count(),0);
  await page.getByRole('button',{name:'Abrir editor',exact:true}).click();
  assert.equal(await page.locator('#f_title').inputValue(),'Título 71');
});
test('inspector escapes titles and does not leak source credentials',async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:[{...movie(1),title:'<img src=x onerror=alert(1)>',poster:'javascript:alert(1)'}],series:[],sources:[{id:'live',name:'Privada',type:'xtream',host:'http://example.test',username:'secret-user',password:'secret-password'}]}});if(!page)return;
  assert.equal(await page.locator('#list tbody tr').count(),1);
  await page.locator('#list .title-select').click();
  assert.equal(await page.locator('#workspace-inspector h2').textContent(),'<img src=x onerror=alert(1)>');
  assert.equal(await page.locator('#workspace-inspector img[src^="javascript"]').count(),0);
  await page.getByRole('button',{name:'TV en vivo',exact:true}).click();
  await page.locator('#list .title-select').click();
  const text=await page.locator('#workspace-inspector').textContent();assert.ok(!text.includes('secret-user'));assert.ok(!text.includes('secret-password'));
});
test('selection follows unique ID across collection move and clears after removal',async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:[movie(1)],series:[],sources:[]}});if(!page)return;
  await page.locator('#list .title-select').click();
  await page.evaluate(()=>{catalog.series.push(catalog.movies.pop());render()});
  await page.getByRole('button',{name:'Abrir editor',exact:true}).click();
  assert.equal(await page.locator('#f_content_type').inputValue(),'series');
  await page.evaluate(()=>{closeModal();catalog.series=[];render()});
  assert.equal(await page.getByRole('button',{name:'Abrir editor',exact:true}).count(),0);
});
test('visible utility controls dispatch each existing action once',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  await page.evaluate(()=>{window.calls=[];window.syncTrending=()=>calls.push('trends');window.exportJson=()=>calls.push('export');window.loadFromGitHub=()=>calls.push('load');window.openConfig=()=>calls.push('config');window.publish=()=>calls.push('publish')});
  for(const name of ['Sincronizar tendencias','Descargar JSON','Cargar de GitHub','GitHub','Publicar cambios'])await page.getByRole('button',{name,exact:true}).click();
  assert.deepEqual(await page.evaluate(()=>calls),['trends','export','load','config','publish']);
});
test('initial large catalog never mounts all cards and page size stays bounded',async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:Array.from({length:10000},(_,i)=>movie(i)),series:[],sources:[]}});if(!page)return;
  assert.ok(await page.evaluate(()=>workspacePeak)<=100,'legacy startup must not mount every card');
  await page.locator('#workspace-page-size').selectOption('100');assert.equal(await page.locator('#list tbody tr').count(),100);
  await page.getByRole('button',{name:'Siguiente',exact:true}).click();
  assert.equal(await page.locator('#list tbody tr').count(),100);
  assert.equal(await page.locator('#list .title-select').first().textContent(),'Título 100');
});
test('import and download operate on the actual catalog',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  await page.locator('#workspace-import-file').setInputFiles({name:'catalog.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify({version:2,movies:[movie(4)],series:[],sources:[]}))});
  await page.locator('#list .title-select').waitFor();
  assert.equal(await page.locator('#list .title-select').textContent(),'Título 4');
  const downloadPromise=page.waitForEvent('download');await page.getByRole('button',{name:'Descargar JSON',exact:true}).click();
  const download=await downloadPromise;assert.equal(download.suggestedFilename(),'catalog.json');
  const exported=JSON.parse(require('node:fs').readFileSync(await download.path(),'utf8'));
  assert.equal(exported.movies[0].id,'m4');assert.equal(exported.movies[0].servers[0].url,'https://example.test/video');
});
test('loading and trends cannot submit twice while pending',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  await page.evaluate(()=>{window.trendCalls=0;window.syncTrending=()=>{trendCalls++;return new Promise(resolve=>window.finishTrend=resolve)}});
  const button=page.getByRole('button',{name:'Sincronizar tendencias',exact:true});await button.click();
  assert.equal(await button.isDisabled(),true);assert.equal(await page.evaluate(()=>trendCalls),1);
  await page.evaluate(()=>finishTrend());await button.waitFor({state:'visible'});
  assert.equal(await button.isEnabled(),true);
});
test('legacy navigation reaches the requested server subsection',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  await page.evaluate(()=>setTab('notifications'));
  assert.ok((await page.locator('#workspace-server-tabs button.active').textContent()).startsWith('Notificaciones'));
});
for(const id of ['same',undefined,''])test(`unsafe deletion is blocked for ${String(id)} ID`,async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:[{...movie(1),id},{...movie(2),id}],series:[],sources:[]}});if(!page)return;
  await page.evaluate(()=>{window.confirm=()=>true;window.publishCalls=0;window.publish=()=>publishCalls++;window.messages=[];window.toast=m=>messages.push(m)});
  await page.evaluate(()=>{activeTab='movies';return removeItem(1)});
  assert.equal(await page.evaluate(()=>catalog.movies.length),2);
  assert.equal(await page.evaluate(()=>publishCalls),0);
  assert.match(await page.evaluate(()=>messages.join(' ')),/ID/);
});
test('unique zero ID can be deleted and tombstoned',async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:[{...movie(1),id:0}],series:[],sources:[]}});if(!page)return;
  await page.evaluate(()=>{window.confirm=()=>true;window.publish=()=>true;activeTab='movies';return removeItem(0)});
  assert.equal(await page.evaluate(()=>catalog.movies.length),0);
  assert.equal(await page.evaluate(()=>deletedIds.has(0)),true);
});
test('source notification uses workspace route and remains selected after render',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  await page.evaluate(async()=>{
    sbSession={user:{id:'synthetic'}};supabase={_publicSession:value=>value};
    HourTVReplacementActions.loadAdminData=async()=>({notifications:[{id:'n1',source_id:'s1',notification_type:'confirmed_down',message:'Prueba',status:'open'}],candidates:[],sources:[],events:[],providers:[]});
    await renderNotifications();setTab('down_servers');openSourceNotification('s1');
  });
  await page.locator('#overlay.open').waitFor();
  assert.ok((await page.locator('#workspace-server-tabs button.active').textContent()).startsWith('Notificaciones'));
  await page.evaluate(()=>{closeModal();render()});
  assert.ok((await page.locator('#workspace-server-tabs button.active').textContent()).startsWith('Notificaciones'));
});
