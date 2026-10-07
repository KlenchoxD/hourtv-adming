const test=require('node:test');
const assert=require('node:assert/strict');
const {openWorkspace}=require('./workspace-test-helpers');
const item=(id,title)=>({id,title,year:2026,genre:'Animación',rating:7});
const catalog={version:2,movies:[item('m','Película normal'),{...item('am','Anime película'),categories:['anime']}],series:[item('s','Serie normal'),{...item('as','Anime serie'),categories:['anime'],seasons:[{number:1,episodes:[{number:1,title:'Inicio',servers:[{url:'https://example.test/video',language:'Español'}]}]}]}],sources:[]};
const tab=(page,type)=>page.locator(`[data-catalog-type="${type}"]`);

test('three tabs expose disjoint lists and counters without changing catalog storage',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  const before=await page.evaluate(()=>JSON.stringify(catalog));
  assert.deepEqual(await page.locator('#workspace-catalog-tabs button').evaluateAll(buttons=>buttons.map(button=>button.dataset.catalogType)),['movies','series','anime']);
  assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Película normal']);
  await tab(page,'series').click();assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Serie normal']);
  await tab(page,'anime').click();assert.deepEqual(await page.locator('#list .title-select').allTextContents(),['Anime película','Anime serie']);
  assert.equal(await page.locator('#workspace-title').textContent(),'Animes');
  assert.equal(await page.locator('#search').getAttribute('placeholder'),'Buscar animes…');
  assert.deepEqual(await page.locator('.workspace-collection-count').allTextContents(),['1','1','2']);
  assert.equal(await page.evaluate(()=>JSON.stringify(catalog)),before);
});

test('anime rows open their original movie or series editor and preserve episode structure',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await tab(page,'anime').click();
  await page.getByRole('button',{name:'Anime película',exact:true}).click();
  await page.getByRole('button',{name:'Abrir editor',exact:true}).click();
  assert.equal(await page.locator('#f_content_type').inputValue(),'movie');
  assert.equal(await page.locator('#f_categories [data-cat="anime"].on').count(),1);
  await page.evaluate(()=>closeModal());
  await page.getByRole('button',{name:'Anime serie',exact:true}).click();
  await page.getByRole('button',{name:'Abrir editor',exact:true}).click();
  assert.equal(await page.locator('#f_content_type').inputValue(),'series');
  assert.equal(await page.locator('#f_seasons [data-ep]').count(),1);
  assert.equal(await page.locator('#f_seasons .t').inputValue(),'Inicio');
});

test('adding anime preselects its category and can save an anime movie in the same view',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await tab(page,'anime').click();await page.getByRole('button',{name:'Añadir anime',exact:true}).click();
  assert.equal(await page.locator('#f_content_type').inputValue(),'series');
  assert.equal(await page.locator('#f_categories [data-cat="anime"].on').count(),1);
  await page.locator('#f_content_type').selectOption('movie');await page.locator('#f_title').fill('Nuevo anime');
  await page.evaluate(()=>{window.collectServers=()=>[{url:'https://example.test/new',language:'Español'}];window.hasMissingLanguage=()=>false;saveItem(null)});
  assert.equal(await page.locator('#overlay.open').count(),0);
  assert.equal(await tab(page,'anime').getAttribute('aria-selected'),'true');
  assert.ok((await page.locator('#list .title-select').allTextContents()).includes('Nuevo anime'));
  assert.equal(await page.evaluate(()=>catalog.movies.at(-1).categories.includes('anime')),true);
});

test('anime tab supports three-way keyboard movement and legacy routing',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  await tab(page,'movies').focus();await tab(page,'movies').press('ArrowLeft');
  assert.equal(await tab(page,'anime').getAttribute('aria-selected'),'true');
  await tab(page,'anime').press('ArrowRight');assert.equal(await tab(page,'movies').getAttribute('aria-selected'),'true');
  await tab(page,'movies').press('End');assert.equal(await tab(page,'anime').getAttribute('aria-selected'),'true');
  await tab(page,'anime').press('Home');assert.equal(await tab(page,'movies').getAttribute('aria-selected'),'true');
  await page.evaluate(()=>setTab('anime'));assert.equal(await tab(page,'anime').getAttribute('aria-selected'),'true');
});

test('three tabs and large counters fit a mobile viewport',async t=>{
  const large={version:2,movies:Array.from({length:3400},(_,i)=>({...item('m'+i,'Película '+i),categories:i<94?['anime']:[]})),series:Array.from({length:364},(_,i)=>({...item('s'+i,'Serie '+i),categories:i<264?['anime']:[]})),sources:[]};
  const page=await openWorkspace(t,{width:390,catalog:large});if(!page)return;
  assert.deepEqual(await page.locator('.workspace-collection-count').allTextContents(),['3306','100','358']);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  for(const type of ['movies','series','anime']){const box=await tab(page,type).boundingBox();assert.ok(box.x>=0&&box.x+box.width<=390)}
  await tab(page,'anime').click();assert.equal(await page.locator('#list tbody tr').count(),25);
});
