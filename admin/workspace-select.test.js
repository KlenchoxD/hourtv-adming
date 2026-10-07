const test=require('node:test');
const assert=require('node:assert/strict');
const {openWorkspace}=require('./workspace-test-helpers');
const catalog={version:2,movies:Array.from({length:60},(_,i)=>({id:'m'+i,title:'Película '+i,year:i===0?null:2026,genre:'Drama',rating:7})),series:[{id:'s1',title:'Serie de prueba',year:2026,genre:'Drama',rating:7}],sources:[]};

test('custom filter popup preserves filtering, selection and outside dismissal',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  const trigger=page.getByRole('combobox',{name:'Estado',exact:true});
  await trigger.click();
  const menu=page.getByRole('listbox',{name:'Estado',exact:true});
  assert.equal(await menu.isVisible(),true);
  await menu.getByRole('option',{name:'Ficha incompleta',exact:true}).click();
  assert.equal(await page.locator('#workspace-state').inputValue(),'incomplete');
  assert.equal(await page.locator('#list tbody tr').count(),1);
  assert.equal(await trigger.getAttribute('aria-expanded'),'false');
  assert.equal(await trigger.evaluate(e=>e===document.activeElement),true);
  await trigger.click();await page.locator('#workspace-title').click();
  assert.equal(await menu.isVisible(),false);
});

test('custom selects support keyboard, Escape and pagination rerenders',async t=>{
  const page=await openWorkspace(t,{catalog});if(!page)return;
  let trigger=page.getByRole('combobox',{name:'Filas',exact:true});
  await trigger.focus();await trigger.press('Enter');await trigger.press('ArrowDown');await trigger.press('Enter');
  assert.equal(await page.locator('#workspace-page-size').inputValue(),'50');
  assert.equal(await page.locator('#list tbody tr').count(),50);
  trigger=page.getByRole('combobox',{name:'Filas',exact:true});
  assert.equal(await trigger.evaluate(e=>e===document.activeElement),true);
  await trigger.press('Enter');await trigger.press('End');await trigger.press('Escape');
  assert.equal(await page.locator('#workspace-page-size').inputValue(),'50');
  assert.equal(await trigger.getAttribute('aria-expanded'),'false');
  await page.locator('#workspace-page-size').selectOption('100');
  assert.equal(await trigger.textContent(),'100');
  assert.equal(await page.locator('#list tbody tr').count(),60);
});

for(const width of [1440,390])test(`select arrows, labels and popups fit at ${width}px`,async t=>{
  const page=await openWorkspace(t,{width,catalog});if(!page)return;
  const gap=await page.locator('#workspace-pagination label').evaluate(label=>{
    const text=document.createRange();text.selectNodeContents(label.querySelector('.workspace-select-label'));
    return label.querySelector('.workspace-select-control').getBoundingClientRect().left-text.getBoundingClientRect().right;
  });
  assert.ok(gap>=10,'Filas label must be visibly separated from control');
  const trigger=page.getByRole('combobox',{name:'Estado',exact:true});
  const inset=await trigger.evaluate(button=>{const b=button.getBoundingClientRect(),a=button.querySelector('svg').getBoundingClientRect();return {right:b.right-a.right,vertical:Math.abs((a.top+a.bottom-b.top-b.bottom)/2)}});
  assert.ok(inset.right>=10);assert.ok(inset.vertical<=1);
  for(const name of ['Estado','Filas']){
    await page.getByRole('combobox',{name,exact:true}).click();
    const box=await page.getByRole('listbox',{name,exact:true}).boundingBox();
    assert.ok(box.x>=0&&box.x+box.width<=width,`${name} popup must fit horizontally`);assert.ok(box.y>=0&&box.y+box.height<=900);
    await page.keyboard.press('Escape');
  }
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  if(process.env.HOURTV_SELECT_SCREENSHOT&&width===1440){await page.emulateMedia({reducedMotion:'reduce'});await trigger.click();await page.getByRole('listbox',{name:'Estado',exact:true}).waitFor();await page.screenshot({path:process.env.HOURTV_SELECT_SCREENSHOT});}
});
test('popup opens upward near viewport bottom and caption operates custom control',async t=>{
  const page=await openWorkspace(t,{width:390,height:600,catalog});if(!page)return;
  const trigger=page.getByRole('combobox',{name:'Filas',exact:true});await trigger.scrollIntoViewIfNeeded();
  await page.locator('#workspace-pagination .workspace-select-label').click();
  const menu=page.getByRole('listbox',{name:'Filas',exact:true});
  assert.equal(await menu.isVisible(),true);
  const box=await menu.boundingBox();assert.ok(box.y>=0&&box.y+box.height<=600);
});
