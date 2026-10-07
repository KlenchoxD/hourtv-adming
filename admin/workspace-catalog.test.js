const test=require('node:test');
const assert=require('node:assert/strict');
const {openWorkspace}=require('./workspace-test-helpers');
const item=(id,title)=>({id,title,year:2026,genre:'Drama',rating:7});
const catalog={version:2,movies:Array.from({length:60},(_,i)=>item('m'+i,'Película '+i)),series:[item('s1','Serie uno'),item('s2','Serie dos')],sources:[]};
const tab=(page,type)=>page.locator(`[data-catalog-type="${type}"]`);

test('catalog starts in movies and series has a distinct counted list',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  assert.equal(await page.locator('#workspace-title').textContent(),'Películas');
  assert.equal(await tab(page,'movies').getAttribute('aria-selected'),'true');
  assert.match(await tab(page,'movies').textContent(),/60/);
  assert.match(await tab(page,'series').textContent(),/2/);
  assert.equal(await page.getByRole('combobox',{name:'Tipo',exact:true}).isVisible(),false);
  assert.equal(await page.locator('#list tbody tr').count(),25);
  assert.ok((await page.locator('#list .title-select').allTextContents()).every(title=>title.startsWith('Película')));
  await tab(page,'series').click();
  assert.equal(await page.locator('#workspace-title').textContent(),'Series');
  assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Serie uno','Serie dos']);
  assert.equal(await tab(page,'series').getAttribute('aria-selected'),'true');
});

test('changing collection clears stale filters and inspector and adds the correct type',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await page.getByRole('button',{name:'Siguiente',exact:true}).click();
  await page.getByLabel('Buscar título',{exact:true}).fill('Película 51');
  await page.getByLabel('Buscar título',{exact:true}).press('Enter');
  await page.locator('#list .title-select').click();
  await tab(page,'series').click();
  assert.equal(await page.locator('#search').inputValue(),'');
  assert.equal(await page.getByRole('button',{name:'Abrir editor',exact:true}).count(),0);
  assert.equal(await page.locator('#list tbody tr').count(),2);
  await page.getByRole('button',{name:'Añadir serie',exact:true}).click();
  assert.equal(await page.locator('#f_content_type').inputValue(),'series');
  await page.evaluate(()=>closeModal());
  await page.locator('#list .title-select').first().click();
  await page.getByRole('button',{name:'Abrir editor',exact:true}).click();
  assert.equal(await page.locator('#f_title').inputValue(),'Serie uno');
  assert.equal(await page.locator('#f_content_type').inputValue(),'series');
});

test('reselecting the active collection keeps the search and selected title',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await page.getByLabel('Buscar título',{exact:true}).fill('Película 51');
  await page.getByLabel('Buscar título',{exact:true}).press('Enter');
  await page.locator('#list .title-select').click();
  await tab(page,'movies').click();await tab(page,'movies').press('Home');
  assert.equal(await page.locator('#search').inputValue(),'Película 51');
  assert.equal(await page.locator('#workspace-inspector h2').textContent(),'Película 51');
});

test('catalog tabs support keyboard navigation and preserve the collection on return',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await tab(page,'movies').focus();await tab(page,'movies').press('ArrowRight');
  assert.equal(await tab(page,'series').evaluate(e=>e===document.activeElement),true);
  assert.equal(await tab(page,'series').getAttribute('tabindex'),'0');
  assert.equal(await tab(page,'movies').getAttribute('tabindex'),'-1');
  await tab(page,'series').press('Home');
  assert.equal(await tab(page,'movies').getAttribute('aria-selected'),'true');
  await tab(page,'movies').press('End');
  assert.equal(await tab(page,'anime').getAttribute('aria-selected'),'true');
  await tab(page,'anime').press('ArrowLeft');
  await page.getByRole('button',{name:'TV en vivo',exact:true}).click();
  assert.equal(await page.locator('#workspace-catalog-tabs').isVisible(),false);
  await page.getByRole('button',{name:'Catálogo',exact:true}).click();
  assert.equal(await tab(page,'series').getAttribute('aria-selected'),'true');
  assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Serie uno','Serie dos']);
});

test('legacy collection routes and data refresh keep the visible collection consistent',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await page.evaluate(()=>setTab('series'));
  assert.equal(await tab(page,'series').getAttribute('aria-selected'),'true');
  await page.evaluate(()=>{catalog.series.push({id:'s3',title:'Serie tres'});render()});
  assert.match(await tab(page,'series').textContent(),/3/);
  assert.equal(await page.locator('#list tbody tr').count(),3);
  await page.evaluate(()=>setTab('movies'));
  assert.equal(await tab(page,'movies').getAttribute('aria-selected'),'true');
  assert.equal(await page.locator('#list tbody tr').count(),25);
});

test('pending retains its type filter without exposing mixed catalog navigation',async t=>{
  const page=await openWorkspace(t,{catalog:{version:2,movies:[{id:'m',title:'Película pendiente'}],series:[{id:'s',title:'Serie pendiente'}],sources:[]}});if(!page)return;
  await page.getByRole('button',{name:'Pendientes',exact:true}).click();
  assert.equal(await page.locator('#workspace-catalog-tabs').isVisible(),false);
  assert.equal(await page.getByRole('combobox',{name:'Tipo',exact:true}).isVisible(),true);
  await page.locator('#workspace-type').selectOption('series');
  assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Serie pendiente']);
});

test('Cargar is visible beside GitHub and dispatches the existing load action once',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  const connection=page.locator('#workspace-connection');
  assert.equal(await connection.getByRole('button',{name:'Cargar',exact:true}).isVisible(),true);
  assert.equal(await page.locator('[data-action="load"]').count(),1);
  await page.evaluate(()=>{window.loadCalls=0;window.loadFromGitHub=()=>loadCalls++});
  await connection.getByRole('button',{name:'Cargar',exact:true}).click();
  assert.equal(await page.evaluate(()=>loadCalls),1);
});

test('Cargar updates both counts and keeps the active series list after the GitHub response',async t=>{
  const page=await openWorkspace(t,{storage:{hourtv_admin_cfg:{owner:'test-owner',repo:'test-repo',branch:'master',path:'catalog.json',token:'synthetic-token'}}});if(!page)return;
  let finish,start;const started=new Promise(resolve=>start=resolve);let requests=0;
  await page.route('https://api.github.com/**',async route=>{
    assert.equal(route.request().method(),'GET');requests++;start();await new Promise(resolve=>finish=resolve);
    await route.fulfill({status:200,json:{sha:'synthetic-sha',content:Buffer.from(JSON.stringify(catalog)).toString('base64')}});
  });
  await tab(page,'series').click();
  const load=page.getByRole('button',{name:'Cargar',exact:true});await load.click();await started;
  assert.equal(await load.isDisabled(),true);
  finish();await page.waitForFunction(()=>document.getElementById('workspace-change-count').textContent==='Sin cambios locales');
  assert.equal(requests,1);
  assert.equal(await load.isEnabled(),true);
  assert.equal(await tab(page,'series').getAttribute('aria-selected'),'true');
  assert.match(await tab(page,'movies').textContent(),/60/);
  assert.match(await tab(page,'series').textContent(),/2/);
  assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Serie uno','Serie dos']);
});
