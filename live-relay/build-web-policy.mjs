// Mechanical export of audited metadata. Never copies credentials into assets.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
const folder=new URL('./.wrangler/channel-audit/',import.meta.url);
const inv=JSON.parse(await fs.readFile(new URL('inventory.private.json',folder),'utf8'));
async function report(kind) {
  const text=await fs.readFile(new URL(`${kind}.jsonl`,folder),'utf8');
  return new Map(text.trim().split('\n').filter(Boolean).map(l=>{const r=JSON.parse(l);return [r.index,r];}));
}
const [old,newReport]=await Promise.all([report('old'),report('new')]);
const sha=value=>createHash('sha256').update(value).digest('hex');
const normalize=value=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase()
  .replace(/\([^)]*\)|\[[^\]]*\]/g,' ')
  .replace(/\b(?:fhd|uhd|hd|sd|4k|8k|hevc|opc\.?\s*\d+|op\.?\s*\d+)\b/g,' ')
  .replace(/^canal\s+/,'').replace(/[^a-z\d+]+/g,' ').trim();
const country=row=>row.tvgId?.match(/\.([a-z]{2})(?:@[^.]+)?$/i)?.[1]?.toLowerCase()||
  (/totalplay|izzi|mexico/.test(normalize(row.group||''))?'mx':null)||
  Object.entries({colombia:'co',mexico:'mx',argentina:'ar',chile:'cl',peru:'pe',venezuela:'ve',ecuador:'ec',uruguay:'uy',paraguay:'py',bolivia:'bo',brasil:'br',espana:'es',guatemala:'gt',honduras:'hn',salvador:'sv',nicaragua:'ni',panama:'pa','costa rica':'cr',dominicana:'do'})
    .find(([name])=>normalize(row.group||'').includes(name))?.[1] || row.country || null;
const category=row=>{
  const text=normalize(row.group||'');
  if(/xxx|adult|playboy|penthouse/.test(text))return 'Adultos';
  if(/kids|infantil|nino/.test(text))return 'Infantiles';
  if(/deporte|sport|espn/.test(text))return 'Deportes';
  if(/noticia|news/.test(text))return 'Noticias';
  if(/anime|animacion/.test(text))return 'Anime';
  if(/cine|movie|premium/.test(text))return 'Cine';
  if(/cultura|documental/.test(text))return 'Documentales';
  return 'Populares';
};
const compatible=[...newReport.values()].filter(r=>r.status==='active'&&r.browserVideo==='h264').map(r=>inv.fresh[r.index]);
const byId=new Map(compatible.map(c=>[c.id,c]));
const additions=[...byId.values()];
const byName=new Map();
for(const c of additions){const key=normalize(c.name);if(!byName.has(key))byName.set(key,[]);byName.get(key).push(c);}
const excluded=[],replacements={},changes=[];
const includeBlocked=process.argv.includes('--include-blocked');
const removeOnly=process.argv.includes('--remove-only');
for(const r of old.values()) {
  const blocked=includeBlocked&&r.status==='failed'&&[401,403].includes(r.code)&&r.second?.code===r.code;
  if(!r.confirmedDown&&!blocked)continue;
  const channel=inv.old[r.index],hash=sha(channel.url);
  // Match conservatively: same normalized identity and known, equal country.
  const candidates=(byName.get(normalize(channel.name))||[]).filter(c=>!country(c)||!country(channel)||country(c)===country(channel));
  const picked=removeOnly?null:candidates.length===1?candidates[0]:candidates.find(c=>country(c)&&country(c)===country(channel));
  if(picked)replacements[hash]=`https://hourtv-live-relay.hourtv-release-20261002.workers.dev/live/iptv-${picked.id}.m3u8`;
  else excluded.push(hash);
  changes.push({name:channel.name,country:country(channel),reason:blocked?'access-blocked':'down',httpCode:r.code,replacement:picked?{id:picked.id,name:picked.name}:null});
}
const providerUrl=new URL(inv.fresh[0].url),parts=providerUrl.pathname.split('/');
const credentials=[decodeURIComponent(parts[2]),decodeURIComponent(parts[3])];
const cleanLogo=value=>{try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password&&!credentials.some(c=>value.includes(c))?value:null;}catch{return null;}};
const channels=(removeOnly?[]:additions).map(c=>({name:c.name,url:`https://hourtv-live-relay.hourtv-release-20261002.workers.dev/live/iptv-${c.id}.m3u8`,
  tvgId:c.tvgId||`paid:${c.id}${country(c)?'.'+country(c):''}`,logo:cleanLogo(c.logo),genre:category(c),group:category(c),categories:[c.group,category(c)]}));
const policy={version:1,checkedAt:new Date().toISOString(),auditedOld:old.size,totalOld:inv.old.length,checkedNew:newReport.size,totalNew:inv.fresh.length,excludedUrlHashes:excluded,replacements,channels};
await fs.writeFile(new URL('../assets/data/web_live_policy.json',import.meta.url),JSON.stringify(policy,null,2)+'\n');
await fs.writeFile(new URL('./audited-streams.mjs',import.meta.url),'// Generated audited allowlist. No upstream URLs or credentials.\nexport default '+JSON.stringify(additions.map(c=>({id:c.id,name:c.name})))+';\n');
await fs.writeFile(new URL('../docs/web-live-audit.json',import.meta.url),JSON.stringify({checkedAt:policy.checkedAt,auditedOld:old.size,totalOld:inv.old.length,checkedNew:newReport.size,totalNew:inv.fresh.length,removed:excluded.length,replaced:Object.keys(replacements).length,added:channels.length,changes},null,2)+'\n');
await fs.writeFile(new URL('provider-secret.private.json',folder),JSON.stringify({IPTV_XTREAM:JSON.stringify({host:providerUrl.origin,username:credentials[0],password:credentials[1]})}));
console.log(JSON.stringify({auditedOld:old.size,totalOld:inv.old.length,removed:excluded.length,replaced:Object.keys(replacements).length,added:channels.length}));
