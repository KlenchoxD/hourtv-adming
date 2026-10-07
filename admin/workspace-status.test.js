const test=require('node:test');const assert=require('node:assert/strict');const {openWorkspace}=require('./workspace-test-helpers');
const cfg={owner:'test-owner',repo:'test-repo',branch:'main',path:'catalog.json',token:'synthetic-test-token'};
const remote={version:2,movies:[{id:'m1',title:'Remota',year:2026,genre:'Drama',rating:7,servers:[{url:'https://example.test/a',language:'Español',name:'Video'}]}],series:[],sources:[],liveChannels:[]};
const content=()=>({sha:'test-sha',content:Buffer.from(JSON.stringify(remote)).toString('base64')});
test('configured repository is not represented as verified and legacy base stays unknown',async t=>{
  const page=await openWorkspace(t,{catalog:remote,storage:{hourtv_admin_cfg:cfg,hourtv_admin_base:remote}});if(!page)return;
  assert.equal(await page.locator('#status').textContent(),'Configurado, sin comprobar');
  assert.equal(await page.locator('#workspace-change-count').textContent(),'Base remota no cargada');
});
for(const code of [401,404])test(`GitHub ${code} reports actual connection error and preserves data`,async t=>{
  const page=await openWorkspace(t,{storage:{hourtv_admin_cfg:cfg}});if(!page)return;
  await page.route('https://api.github.com/**',route=>route.fulfill({status:code,json:{message:'test error'}}));
  await page.getByRole('button',{name:'Cargar de GitHub',exact:true}).click();
  await page.waitForFunction(()=>document.getElementById('status').textContent.startsWith('Error'));
  assert.equal(await page.evaluate(()=>catalog.movies.length),0);
});
test('successful load establishes trusted baseline and publication retains in-flight edits',async t=>{
  const page=await openWorkspace(t,{storage:{hourtv_admin_cfg:cfg}});if(!page)return;
  let release;let startedResolve;const started=new Promise(r=>startedResolve=r);
  await page.route('https://api.github.com/**',async route=>{
    if(route.request().method()==='PUT'){startedResolve();await new Promise(r=>release=r);await route.fulfill({status:200,json:{content:{sha:'new-sha'}}})}
    else await route.fulfill({status:200,json:content()});
  });
  await page.getByRole('button',{name:'Cargar de GitHub',exact:true}).click();
  await page.waitForFunction(()=>document.getElementById('workspace-change-count').textContent==='Sin cambios locales');
  assert.equal(await page.locator('#status').textContent(),'Última operación correcta');
  await page.evaluate(()=>{catalog.movies[0].title='Primer cambio';render()});
  await page.getByRole('button',{name:'Publicar cambios',exact:true}).click();await started;
  await page.evaluate(()=>{catalog.movies[0].title='Editada mientras publica';render()});release();
  await page.waitForFunction(()=>!publishing);
  assert.equal(await page.evaluate(()=>catalog.movies[0].title),'Editada mientras publica');
  assert.equal(await page.locator('#workspace-change-count').textContent(),'1 cambios sin publicar');
});
test('late load from previous repository cannot replace current data or connection state',async t=>{
  const page=await openWorkspace(t,{storage:{hourtv_admin_cfg:cfg}});if(!page)return;
  let release;let startedResolve;const started=new Promise(r=>startedResolve=r);
  await page.route('https://api.github.com/**',async route=>{startedResolve();await new Promise(r=>release=r);await route.fulfill({status:200,json:content()})});
  await page.getByRole('button',{name:'Cargar de GitHub',exact:true}).click();await started;
  await page.evaluate(()=>{cfg.repo='otro-repo';refreshStatus()});release();
  await page.waitForFunction(()=>!document.querySelector('[data-action="load"]').disabled);
  assert.equal(await page.locator('#status').textContent(),'Configurado, sin comprobar');
  assert.equal(await page.evaluate(()=>catalog.movies.length),0);
});
test('changing repository immediately invalidates summary and changed filter',async t=>{
  const page=await openWorkspace(t,{catalog:remote,storage:{hourtv_admin_cfg:cfg}});if(!page)return;
  await page.evaluate(async()=>{await persistCatalogBase(JSON.parse(JSON.stringify(catalog)));catalog.movies[0].title='Cambio local';render();hourtvWorkspace.setFilters({status:'changed'})});
  assert.equal(await page.locator('#list tbody tr').count(),1);
  await page.evaluate(()=>{cfg.repo='otro';refreshStatus()});
  assert.equal(await page.locator('#workspace-change-count').textContent(),'Base remota no cargada');
  assert.equal(await page.locator('#list tbody tr').count(),0);
});
test('edits made while GitHub load waits are not discarded',async t=>{
  const page=await openWorkspace(t,{storage:{hourtv_admin_cfg:cfg}});if(!page)return;
  let release,start;const started=new Promise(r=>start=r);
  await page.route('https://api.github.com/**',async route=>{start();await new Promise(r=>release=r);await route.fulfill({status:200,json:content()})});
  await page.getByRole('button',{name:'Cargar de GitHub',exact:true}).click();await started;
  await page.evaluate(()=>{catalog.movies.push({id:'local',title:'Edición durante carga'});save();render()});release();
  await page.waitForFunction(()=>!document.querySelector('[data-action="load"]').disabled);
  assert.equal(await page.evaluate(()=>catalog.movies[0].id),'local');
  assert.equal(await page.locator('#status').textContent(),'Error');
  assert.equal(await page.evaluate(()=>getTrustedCatalogBase()),null);
});
