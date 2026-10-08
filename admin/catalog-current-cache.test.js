const {test}=require('node:test');
const assert=require('node:assert/strict');
const {openWorkspace}=require('./workspace-test-helpers');

function catalog(count){return {version:2,movies:[],series:Array.from({length:count},(_,id)=>({id:'anime-'+id,title:'Anime '+id,genre:'Anime'})),sources:[]};}

test('large loaded catalog survives refresh while localStorage retains old 72 entries',async t=>{
  const page=await openWorkspace(t,{catalog:catalog(72)});if(!page)return;
  await page.evaluate(()=>window.catalogReady);
  await page.evaluate(()=>{
    cfg={token:'synthetic',owner:'test',repo:'catalog',branch:'main',path:'catalog.json'};
    localStorage.setItem('hourtv_admin_cfg',JSON.stringify(cfg));
  });
  await page.addInitScript(()=>{
    const original=Storage.prototype.setItem;
    Storage.prototype.setItem=function(key,value){
      if(key==='hourtv_admin_catalog'){
        const parsed=JSON.parse(value),data=parsed.cacheVersion===2?parsed.catalog:parsed;
        if(data.series.length>100)throw new DOMException('Quota exceeded','QuotaExceededError');
      }
      return original.call(this,key,value);
    };
  });
  // Apply the same quota constraint to this already-open document.
  await page.evaluate(()=>{
    const original=Storage.prototype.setItem;
    Storage.prototype.setItem=function(key,value){
      if(key==='hourtv_admin_catalog'&&JSON.parse(value).catalog?.series.length>100)throw new DOMException('Quota exceeded','QuotaExceededError');
      return original.call(this,key,value);
    };
  });
  const content=Buffer.from(JSON.stringify(catalog(320))).toString('base64');
  await page.route('https://api.github.com/**',route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({sha:'synthetic-sha',content})}));
  assert.equal(await page.evaluate(()=>loadFromGitHub()),true);
  assert.equal(await page.evaluate(()=>catalog.series.length),320);
  await page.reload({waitUntil:'load'});
  await page.evaluate(()=>window.catalogReady);
  assert.equal(await page.evaluate(()=>catalog.series.length),320);
  assert.equal(await page.evaluate(async()=>{const value=await HourTvCatalogBaselineStore.getCatalog();return value.catalog.series.length}),320);
});

test('legacy large IndexedDB cache wins over stale nonempty local snapshot',async t=>{
  const page=await openWorkspace(t,{catalog:catalog(72)});if(!page)return;
  await page.evaluate(()=>window.catalogReady);
  await page.evaluate(value=>HourTvCatalogBaselineStore.setCatalog(value),catalog(320));
  await page.reload({waitUntil:'load'});
  await page.evaluate(()=>window.catalogReady);
  assert.equal(await page.evaluate(()=>catalog.series.length),320);
});
