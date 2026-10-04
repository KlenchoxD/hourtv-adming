// Read-only bounded stream audit. Credentials come from process environment,
// never from committed source. Reports remain in the ignored .wrangler folder.
import fs from 'node:fs/promises';
import {createDecipheriv} from 'node:crypto';
import {lookup} from 'node:dns/promises';
import {isIP} from 'node:net';

const folder = new URL('./.wrangler/channel-audit/', import.meta.url);
await fs.mkdir(folder, {recursive:true});
const encoder = new TextDecoder();
const addressCache = new Map();
function privateIp(ip) {
  return /^(127\.|10\.|192\.168\.|169\.254\.|0\.|172\.(1[6-9]|2\d|3[01])\.|224\.|255\.|::|fc|fd|fe80)/i.test(ip);
}
async function safeUrl(value) {
  const u = new URL(value);
  if (!['http:','https:'].includes(u.protocol) || u.username || u.password) throw new Error('unsupported');
  let addresses = addressCache.get(u.hostname);
  if (!addresses) {
    addresses = isIP(u.hostname) ? [{address:u.hostname}] : await lookup(u.hostname,{all:true});
    addressCache.set(u.hostname,addresses);
  }
  if (!addresses.length || addresses.some(a=>privateIp(a.address))) throw new Error('private-address');
  return u;
}
export async function read(url, limit=512*1024, prefix=false) {
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(),8000);
  let response;
  try {
    let u = await safeUrl(url);
    for(let n=0;n<6;n++) {
      response = await fetch(u,{signal:controller.signal,redirect:'manual',headers:{'User-Agent':'Mozilla/5.0'}});
      if([301,302,303,307,308].includes(response.status)) {
        const location=response.headers.get('location'); await response.body?.cancel();
        if(!location) throw new Error('redirect');
        u=await safeUrl(new URL(location,u)); continue;
      }
      break;
    }
    if(!response.ok) {const code=response.status; await response.body?.cancel(); return {code};}
    const reader=response.body.getReader(); const chunks=[]; let size=0;
    try {
      while(true) {
        const {done,value}=await reader.read(); if(done) break;
        const chunk=value.subarray(0,Math.max(0,limit-size));chunks.push(chunk);size+=chunk.length;
        if(size>=limit) {if(!prefix) throw new Error('oversized');break;}
      }
    } finally {await reader.cancel().catch(()=>{});}
    return {code:response.status,url:response.url || u.href,bytes:Buffer.concat(chunks),type:response.headers.get('content-type')||'',cors:response.headers.get('access-control-allow-origin')};
  } catch(e) { return {code:0,error:e.name==='AbortError'?'timeout':String(e.code||e.message).replace(/https?:\/\/\S+/g,'[url]')}; }
  finally {clearTimeout(timer);controller.abort();}
}
export function transportOffset(bytes) {
  for(let off=0;off<376 && off+376<bytes.length;off++) {
    if(bytes[off]===71 && bytes[off+188]===71 && bytes[off+376]===71)return off;
  }
  return -1;
}
export function codecs(bytes) {
  const types=new Set();
  const sync=transportOffset(bytes);if(sync<0)return [];
  for(let off=sync;off+188<=bytes.length;off+=188) {
    const p=bytes.subarray(off,off+188);if(p[0]!==71 || !(p[1]&64))continue;
    const control=(p[3]>>4)&3;if(!(control&1))continue;
    let start=4;if(control&2)start+=p[4]+1;start+=p[start]+1;
    if(start+12>=188 || p[start]!==2)continue;
    const len=((p[start+1]&15)<<8)|p[start+2],info=((p[start+10]&15)<<8)|p[start+11];
    for(let pos=start+12+info;pos<Math.min(start+3+len-4,188)&&pos+5<=188;) {
      types.add(p[pos]);pos+=5+((p[pos+3]&15)<<8)+p[pos+4];
    }
  }
  return [...types];
}
const hostSlots=new Map();
async function acquireHost(host) {
  let slot=hostSlots.get(host);if(!slot){slot={active:0,waiting:[]};hostSlots.set(host,slot);}
  if(slot.active>=2)await new Promise(resolve=>slot.waiting.push(resolve));
  slot.active++;
  return ()=>{slot.active--;slot.waiting.shift()?.();};
}
export async function probe(url) {
  let release;
  try {release=await acquireHost(new URL(url).hostname);return await probeMedia(url);}
  catch{return {status:'unknown',reason:'invalid-url'};}
  finally{release?.();}
}
async function probeMedia(url) {
  let result=await read(url,512*1024,true);
  if(!result.bytes) return {status:'failed',code:result.code,error:result.error};
  let text=encoder.decode(result.bytes),depth=0;
  while(text.trimStart().startsWith('#EXTM3U')) {
    if(depth++>4)return {status:'unknown',reason:'nested-playlists'};
    const lines=text.split(/\r?\n/),uris=lines.filter(l=>l.trim()&&!l.startsWith('#'));
    if(!uris.length)return {status:'failed',code:200,error:'empty-playlist'};
    const master=text.includes('#EXT-X-STREAM-INF');
    const uri=master?uris[0]:uris[Math.max(0,uris.length-2)];
    let media=await read(new URL(uri,result.url),master?512*1024:65536,true);
    if(!media.bytes)return {status:'failed',code:media.code,error:media.error};
    if(master){result=media;text=encoder.decode(media.bytes);continue;}
    const keyLine=lines.filter(l=>l.startsWith('#EXT-X-KEY')).at(-1);
    if(keyLine?.includes('METHOD=AES-128')) {
      const keyUri=keyLine.match(/URI="([^"]+)"/)?.[1];
      if(!keyUri)return {status:'unknown',reason:'key-missing'};
      const key=await read(new URL(keyUri,result.url),64,true);
      if(key.bytes?.length!==16)return {status:'failed',code:key.code,error:'key-failed'};
      const ivHex=keyLine.match(/IV=0x([a-f\d]+)/i)?.[1];
      const iv=ivHex?Buffer.from(ivHex.padStart(32,'0'),'hex'):Buffer.alloc(16);
      if(!ivHex)iv.writeBigUInt64BE(BigInt(Number(text.match(/#EXT-X-MEDIA-SEQUENCE:(\d+)/)?.[1]||0)+Math.max(0,uris.length-2)),8);
      try {const decipher=createDecipheriv('aes-128-cbc',key.bytes,iv);decipher.setAutoPadding(false);media.bytes=decipher.update(media.bytes.subarray(0,media.bytes.length-media.bytes.length%16));}
      catch {return {status:'unknown',reason:'encrypted-format'};}
    } else if(keyLine && !keyLine.includes('METHOD=NONE'))return {status:'unknown',reason:'drm'};
    return classify(media, true);
  }
  return classify(result,false);
}
function classify(media,hls) {
  const b=media.bytes,types=codecs(b);
  const transport=transportOffset(b)>=0;
  const mp4=b.length>16 && /ftyp|moof|styp/.test(b.subarray(4,16).toString());
  if(!transport&&!mp4)return {status:'unknown',reason:'non-media',code:media.code};
  return {status:'active',format:hls?'hls':transport?'ts':'mp4',code:media.code,codecs:types,
    browserVideo:types.includes(27)?'h264':types.includes(2)?'mpeg2':types.includes(36)?'hevc':'unknown',
    https:media.url.startsWith('https:'),cors:media.cors==='*'||media.cors==='https://hourtv.pages.dev'};
}
function parseM3u(text,source,genre,country) {
  const rows=[];let info;
  for(const line of text.split(/\r?\n/)) {
    if(line.startsWith('#EXTINF:')) {
      const attr=k=>line.match(new RegExp(k+'="([^"]*)"'))?.[1]||'';
      info={name:line.slice(line.lastIndexOf(',')+1).trim(),tvgId:attr('tvg-id'),logo:attr('tvg-logo'),source,genre,country:country||attr('tvg-id').match(/\.([a-z]{2})$/i)?.[1]||null};
    } else if(info && line.trim()&&!line.startsWith('#')) {rows.push({...info,url:line.trim()});info=null;}
  }
  return rows;
}
async function inventory() {
  const root='https://iptv-org.github.io/iptv';
  const sources=[...Object.entries({sports:'Deportes',news:'Noticias',kids:'Infantiles',animation:'Anime',movies:'Cine',series:'Series'}).map(([x,genre])=>({name:genre,genre,url:`${root}/categories/${x}.m3u`})),
    ...'co mx ar cl pe ve es ec uy py bo cr pa do gt pr us'.split(' ').map(country=>({name:country,genre:'Populares',country,url:`${root}/countries/${country}.m3u`})),
    {name:'Latinos',genre:'Populares',url:`${root}/languages/spa.m3u`},
    {name:'Free-TV',genre:'Populares',url:'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8'}];
  const old=[],seen=new Set();
  for(const s of sources) {
    const r=await read(s.url,12*1024*1024);
    if(!r.bytes){console.log(JSON.stringify({source:s.name,error:r.error||r.code}));continue;}
    for(const c of parseM3u(encoder.decode(r.bytes),s.name,s.genre,s.country))if(!seen.has(c.url)){seen.add(c.url);old.push(c);}
  }
  const base=process.env.IPTV_HOST,user=process.env.IPTV_USER,password=process.env.IPTV_PASSWORD;
  if(!base||!user||!password)throw new Error('Provider environment required');
  const api=async action=>{const u=new URL('/player_api.php',base);u.search=new URLSearchParams({username:user,password,action});const r=await read(u,16*1024*1024);if(!r.bytes)throw new Error('Provider API unavailable');return JSON.parse(encoder.decode(r.bytes));};
  const [streams,categories]=await Promise.all([api('get_live_streams'),api('get_live_categories')]);
  const cats=Object.fromEntries(categories.map(c=>[c.category_id,c.category_name]));
  const fresh=streams.map(c=>({name:c.name,id:String(c.stream_id),logo:c.stream_icon||'',tvgId:c.epg_channel_id||'',group:cats[c.category_id]||'',kind:'new',url:`${base.replace(/\/$/,'')}/live/${encodeURIComponent(user)}/${encodeURIComponent(password)}/${c.stream_id}.m3u8`}));
  // Private stream URLs stay only in this ignored working report.
  await fs.writeFile(new URL('inventory.private.json',folder),JSON.stringify({old,fresh}));
  console.log(JSON.stringify({old:old.length,fresh:fresh.length}));
}
async function audit(kind,concurrency) {
  const data=JSON.parse(await fs.readFile(new URL('inventory.private.json',folder),'utf8'));
  const rows=kind==='new'?data.fresh:data.old,path=new URL(`${kind}.jsonl`,folder);
  const previous=await fs.readFile(path,'utf8').catch(()=>'');
  const latest=new Map(previous.trim().split('\n').filter(Boolean).map(l=>{const r=JSON.parse(l);return [r.index,r];}));
  const done=new Set([...latest.values()].filter(r=>!(process.argv.includes('--recheck-unknown')&&r.status==='unknown')).map(r=>r.index));
  const groups=new Map();
  for(let i=0;i<rows.length;i++)if(!done.has(i)){
    let host;try{host=new URL(rows[i].url).hostname;}catch{host='invalid';}
    if(!groups.has(host))groups.set(host,[]);groups.get(host).push(i);
  }
  const pending=[];
  while(groups.size)for(const [host,items] of groups){pending.push(items.shift());if(!items.length)groups.delete(host);}
  const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
  async function providerCapacity() {
    const parts=new URL(data.fresh[0].url).pathname.split('/');
    const url=new URL('/player_api.php',new URL(data.fresh[0].url).origin);
    url.search=new URLSearchParams({username:decodeURIComponent(parts[2]),password:decodeURIComponent(parts[3])});
    const response=await read(url,65536);
    if(!response.bytes)return false;
    try {
      const info=JSON.parse(encoder.decode(response.bytes)).user_info;
      // Leave a slot available; an HLS probe can briefly occupy two sessions.
      return info.status==='Active' && Number(info.active_cons)<Math.max(1,Number(info.max_connections)-2);
    }catch{return false;}
  }
  let index=0,count=done.size;const totals={};
  const progress=setInterval(()=>console.log(JSON.stringify({kind,checked:count,total:rows.length,totals})),30000);
  try {await Promise.all(Array.from({length:concurrency},async()=>{
    while(index<pending.length) {
      const i=pending[index++];const c=rows[i];
      if(kind==='new')while(!await providerCapacity())await pause(15000);
      const first=await probe(c.url);let second;
      if(first.status==='failed')second=await probe(c.url);
      const result=second?.status==='active'?second:first;
      const confirmedDown=first.status==='failed'&&second?.status==='failed'&&
        (first.code===404||first.code===410||first.error==='empty-playlist')&&first.code===second.code&&first.error===second.error;
      const entry={index:i,name:c.name,id:c.id,checkedAt:new Date().toISOString(),...result,confirmedDown,second};
      await fs.appendFile(path,JSON.stringify(entry)+'\n');count++;totals[result.status]=(totals[result.status]||0)+1;
      if(kind==='new')await pause(1000);
    }
  }));}finally{clearInterval(progress);}
  console.log(JSON.stringify({kind,checked:count,total:rows.length,totals,complete:true}));
}
const mode=process.argv[2];
if(mode==='inventory')await inventory();
else if(mode==='old'||mode==='new')await audit(mode,mode==='new'?1:12);
