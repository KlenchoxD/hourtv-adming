const test=require('node:test');const assert=require('node:assert/strict');
const {openWorkspace}=require('./workspace-test-helpers');
test('menu is centered with unequal side controls',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  const nav=page.locator('#workspace-tabs');assert.equal(await nav.count(),1);
  assert.deepEqual(await nav.locator('button').allTextContents(),['Catálogo','Pendientes','TV en vivo','Servidores']);
  await page.locator('.logo').evaluate(e=>e.style.width='240px');
  const box=await nav.boundingBox();assert.ok(Math.abs(box.x+box.width/2-720)<2);
});
test('tools are separate from filters and editors remain reachable',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  const tools=page.locator('#workspace-utilities');assert.equal(await tools.count(),1);
  for(const label of ['Sincronizar tendencias','Descargar JSON','Importar JSON','Cargar de GitHub'])assert.equal(await tools.getByText(label,{exact:true}).count(),1);
  assert.equal(await page.locator('#workspace-filters #search').count(),1);
  assert.equal(await page.locator('#search').count(),1);
  assert.equal(await page.locator('#workspace-connection').count(),1);
  await page.getByRole('button',{name:'Añadir contenido',exact:true}).click();
  assert.equal(await page.locator('#overlay.open').count(),1);
  assert.equal(await page.locator('#modal #f_title').count(),1);
});
test('small screen keeps centered navigation and no page overflow',async t=>{
  const page=await openWorkspace(t,{width:390});if(!page)return;
  const nav=await page.locator('#workspace-tabs').boundingBox();assert.ok(nav);
  assert.ok(Math.abs(nav.x+nav.width/2-195)<2);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
});
test('desktop utilities evenly fill the approved toolbar',async t=>{
  const page=await openWorkspace(t);if(!page)return;
  const widths=await page.locator('#workspace-utilities > *').evaluateAll(elements=>elements.map(e=>e.getBoundingClientRect().width));
  assert.ok(Math.max(...widths)-Math.min(...widths)<2);
  const parent=await page.locator('#workspace-utilities').boundingBox();assert.ok(widths.reduce((a,b)=>a+b,0)>parent.width*.85);
});
for(const width of [1366,768])test(`workspace and keyboard focus fit ${width}px`,async t=>{
  const page=await openWorkspace(t,{width,catalog:{version:2,movies:[{id:'1',title:'Tiempo fracturado',year:2026,genre:'Ciencia ficción',rating:7.5,servers:[]}],series:[],sources:[]}});if(!page)return;
  await page.locator('#list .title-select').click();
  const nav=await page.locator('#workspace-tabs').boundingBox();assert.ok(Math.abs(nav.x+nav.width/2-width/2)<2);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.keyboard.press('Tab');const outline=await page.evaluate(()=>getComputedStyle(document.activeElement).outlineStyle);assert.notEqual(outline,'none');
  await page.emulateMedia({reducedMotion:'reduce'});
  assert.equal(await page.locator('[data-action="publish"]').evaluate(e=>getComputedStyle(e).transitionDuration),'0s');
  if(width===1366&&process.env.HOURTV_SCREENSHOT)await page.screenshot({path:process.env.HOURTV_SCREENSHOT,fullPage:true});
});
