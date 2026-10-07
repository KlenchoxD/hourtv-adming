const fs=require('node:fs');const http=require('node:http');const path=require('node:path');
let chromium;try{({chromium}=require('playwright'))}catch{}
async function openWorkspace(t,{width=1440,height=900,catalog={version:2,movies:[],series:[],sources:[]},storage={}}={}){
  if(!chromium){t.skip('Playwright test runtime unavailable; set NODE_PATH to bundled packages');return null}
  const server=http.createServer((req,res)=>{
    const file=path.resolve(__dirname,'.'+decodeURIComponent(req.url.split('?')[0]==='/'?'/index.html':req.url.split('?')[0]));
    if(!file.startsWith(__dirname+path.sep)){res.writeHead(403);res.end();return}
    fs.readFile(file,(error,data)=>{if(error){res.writeHead(404);res.end();return}res.setHeader('Content-Type',file.endsWith('.css')?'text/css':file.endsWith('.js')?'text/javascript':'text/html');res.end(data)});
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  let browser;
  try{browser=await chromium.launch({channel:'chrome',headless:true});}
  catch(e){server.close();throw e}
  t.after(async()=>{await browser.close();await new Promise(resolve=>server.close(resolve))});
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(5000);
  await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
  await page.addInitScript(value=>localStorage.setItem('hourtv_admin_catalog',JSON.stringify(value)),catalog);
  await page.addInitScript(value=>{for(const [key,item]of Object.entries(value))localStorage.setItem(key,JSON.stringify(item))},storage);
  await page.addInitScript(()=>{window.workspacePeak=0;new MutationObserver(()=>{window.workspacePeak=Math.max(window.workspacePeak,document.querySelectorAll('#list .item,#list tbody tr').length)}).observe(document,{subtree:true,childList:true})});
  await page.goto('http://127.0.0.1:'+server.address().port,{waitUntil:'load'});
  return page;
}
module.exports={openWorkspace};
