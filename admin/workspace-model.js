(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  else root.HourTVWorkspaceModel=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  const collections=['movies','series','sources'];
  const objectKeys=new WeakMap();let nextKey=1;
  function stable(value){
    if(Array.isArray(value))return '['+value.map(stable).join(',')+']';
    if(value&&typeof value==='object')return '{'+Object.keys(value).filter(k=>value[k]!==undefined).sort().map(k=>JSON.stringify(k)+':'+stable(value[k])).join(',')+'}';
    return JSON.stringify(value);
  }
  function entries(catalog){
    const result=[];
    for(const collection of collections){
      const items=Array.isArray(catalog&&catalog[collection])?catalog[collection]:[];
      const counts=new Map();const seen=new Map();
      for(const item of items)if(item&&typeof item==='object'&&item.id!=null)counts.set(String(item.id),(counts.get(String(item.id))||0)+1);
      items.forEach((item,index)=>{
        if(!item||typeof item!=='object'||Array.isArray(item))return;
        const id=item.id==null?null:String(item.id);
        const occurrence=seen.get(id)||0;seen.set(id,occurrence+1);
        const comparison=collection+':'+(id===null?'index:'+index:'id:'+JSON.stringify(id)+':'+occurrence);
        let key=collection+':id:'+JSON.stringify(id);
        if(id===null||counts.get(id)>1){
          if(!objectKeys.has(item))objectKeys.set(item,nextKey++);
          key=collection+':object:'+objectKeys.get(item)+':'+occurrence;
        }
        result.push({key,comparison,collection,index,item});
      });
    }
    return result;
  }
  function missing(item){
    const fields=[];
    if(!item.year)fields.push('año');
    if(!item.genre)fields.push('género');
    if(item.rating==null||item.rating==='')fields.push('rating');
    return fields;
  }
  function buildRows(catalog,baseline){
    const base=baseline?new Map(entries(baseline).map(r=>[r.comparison,r.item])):null;
    return entries(catalog).map(row=>({
      key:row.key,collection:row.collection,index:row.index,item:row.item,
      missing:row.collection==='sources'?[]:missing(row.item),
      change:!base?'unknown':!base.has(row.comparison)?'added':stable(row.item)===stable(base.get(row.comparison))?'unchanged':'modified'
    }));
  }
  function getView(rows,options){
    const o=options||{};const section=o.section||'catalog';const query=String(o.query||'').toLocaleLowerCase().trim();
    const filtered=rows.filter(row=>{
      if(section==='live'?row.collection!=='sources':row.collection==='sources')return false;
      if(section==='pending'&&!row.missing.length)return false;
      if(o.type&&o.type!=='all'&&row.collection!==o.type)return false;
      if(o.status==='complete'&&row.missing.length)return false;
      if(o.status==='incomplete'&&!row.missing.length)return false;
      if(o.status==='changed'&&!['added','modified'].includes(row.change))return false;
      return !query||String(row.item.title||row.item.name||'').toLocaleLowerCase().includes(query);
    });
    const requested=Number(o.pageSize);
    const pageSize=requested>100?100:[25,50,100].includes(requested)?requested:25;
    const pageCount=Math.max(1,Math.ceil(filtered.length/pageSize));
    const page=Math.min(pageCount,Math.max(1,Math.floor(Number(o.page)||1)));
    return {rows:filtered.slice((page-1)*pageSize,page*pageSize),total:filtered.length,page,pageCount,pageSize};
  }
  function summarizeChanges(catalog,baseline){
    if(!baseline)return {known:false,added:0,modified:0,removed:0,total:0};
    const local=entries(catalog),base=entries(baseline);
    const baseMap=new Map(base.map(r=>[r.comparison,r.item]));const localKeys=new Set(local.map(r=>r.comparison));
    let added=0,modified=0,removed=0;
    for(const row of local){if(!baseMap.has(row.comparison))added++;else if(stable(row.item)!==stable(baseMap.get(row.comparison)))modified++;}
    for(const row of base)if(!localKeys.has(row.comparison))removed++;
    return {known:true,added,modified,removed,total:added+modified+removed};
  }
  function resolveSelection(rows,key){return rows.find(row=>row.key===key)||null;}
  return {buildRows,getView,summarizeChanges,resolveSelection};
});
