"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const [audit,everloot,egLoot,egObjects,out]=process.argv.slice(2);
const gaps=fs.readFileSync(audit,"utf8").trim().split(/\r?\n/).slice(1)
 .map(line=>line.split("\t").map(Number)).filter(r=>r[2]===0&&r[3]===0&&r[4]===0);
if(gaps.length<2500)throw Error("Use the baseline runtime source-gap audit.");
const want=new Map(),id=x=>Number.isSafeInteger(x)&&x>0;
function add(map,k,v){(map.get(k)??map.set(k,[]).get(k)).push(v);}
for(const r of gaps)if(id(r[0])&&id(r[1]))add(want,r[1],r[0]);
const observed=new Map(),confirmed=new Set(),meta=new Map(),sha=crypto.createHash("sha256");
const read=(dir,f)=>JSON.parse(fs.readFileSync(path.join(dir,f),"utf8"));
function eg(dir,suffix,tag){
 return fs.readdirSync(dir).filter(f=>f.endsWith(suffix)).sort().map(f=>{
  const d=read(dir,f);
  if(d.meta?.dataset!==tag||d.meta.product!=="wowf"||d.meta.license!=="CC BY 4.0"||!f.startsWith(d.meta.clientBuild+"-"))throw Error("Invalid source file "+f);
  return d;
 });
}
const pages=fs.readdirSync(everloot).filter(f=>/^\d+\.json$/.test(f)).sort((a,b)=>parseInt(a)-parseInt(b));
let date,total,count=0,offset=0;
for(const f of pages){
 const text=fs.readFileSync(path.join(everloot,f));sha.update(text);
 const page=JSON.parse(text);
 if(page.unreachable||page.offset!==offset||page.attribution?.licence!=="CC BY-SA 4.0"||
    page.attribution?.credit!=="Data from Everloot (https://everloot.app), CC BY-SA 4.0.")throw Error("Invalid Everloot page.");
 date??=page.dataAsOf;total??=page.totalRates;
 if(date!==page.dataAsOf||total!==page.totalRates||page.limit!==500)throw Error("Mixed snapshot.");
 count+=page.rates.length;offset+=page.limit;
 for(const r of page.rates){
  const object=r.sourceObjectId,item=r.itemId;
  if(!id(object)||r.sourceNpcId||!want.has(item))continue;
  const wins=r.windowsWithItem??r.drops,total=r.lootWindows??r.kills,n=r.installReports??r.reporters;
  if(!id(wins)||!id(total)||wins>total||!id(n)||n>total)continue;
  const key=item+":"+object;
  if(r.public===true&&r.tier==="confirmed"&&n>=3&&wins>=3)confirmed.add(key);
 }
}
if(count!==total||total<4000||pages.length<10)throw Error("Incomplete Everloot snapshot.");
for(const d of eg(egLoot,"-loot.json","loot")){
 if(d.format!==3)throw Error("Unexpected loot format.");
 for(const [tag,r] of Object.entries(d.sources??{})){
  const m=tag.match(/^object:(\d+)(\|spell:\d+)?(\|quest)?(\|group)?$/);if(!m)continue;
  for(const [str,v] of Object.entries(r.items??{})){
   const i=+str;
   if(!want.has(i)||!id(v.drops)||!id(r.windows)||v.drops>r.windows||(v.shared??0)!==0)continue;
   const key=i+":"+m[1];
   if(!observed.has(key))observed.set(key,new Set());
   observed.get(key).add(d.meta.clientBuild);
  }
 }
}
for(const d of eg(egObjects,"-object_details.enUS.json","object_details")){
 if(d.meta.locale!=="enUS")throw Error("Unexpected profile locale.");
 for(const [oid,entry] of Object.entries(d.objects??{})){
  const name=entry.name;
  if(!id(+oid)||typeof name!=="string"||name.length<2||name.length>100||/[\x00-\x1f;|\[\]]/.test(name))continue;
  const prev=meta.get(+oid);
  if(prev===undefined)meta.set(+oid,name);
  else if(prev!==name)meta.set(+oid,false);
 }
}
const results=new Map();
for(const key of new Set([...confirmed,...observed.keys()])){
 const legacy=observed.get(key)?.size||0;
 if(!confirmed.has(key)&&legacy<2)continue;
 const [i,o]=key.split(":").map(Number),name=meta.get(o);
 if(!name)continue;
 for(const q of want.get(i)??[]){
  const qItems=results.get(q)??new Map();
  add(qItems,i,{id:o,name});
  results.set(q,qItems);
 }
}
const L=["-- BEGIN NQTDB named object pickups (generated)",
 "-- Everloot source-item witnesses, CC BY-SA 4.0 (adapted dataset retains that license).",
 "-- Data from Everloot (https://everloot.app), CC BY-SA 4.0.",
 "-- https://creativecommons.org/licenses/by-sa/4.0/",
 "-- Everloot public snapshot "+date+"; concatenated page SHA-256 "+sha.digest("hex"),
 "-- Independently observed source-item links and exact object names from Efficient Games, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- These are named loot sources, never a drop chance, route pin, or NPC targeting action.",
 "db.NamedObjectPickups={"];
let pairs=0,links=0;
for(const [q,m] of [...results].sort((a,b)=>a[0]-b[0])){
 const rows=[];
 for(const [item,entries] of [...m].sort((a,b)=>a[0]-b[0])){
  pairs++;links+=entries.length;
  rows.push("["+item+"]={"+entries.sort((a,b)=>a.id-b.id).map(r=>"{"+r.id+","+JSON.stringify(r.name)+"}").join(",")+"}");
 }
 L.push(" ["+q+"]={"+rows.join(",")+"},");
}
L.push("}","-- END NQTDB named object pickups","");
if(pairs<12)throw Error("Insufficient named witnesses: "+pairs);
const dest=path.join(out,"NQTDB.lua"),base=fs.readFileSync(dest,"utf8").replace(/\r\n/g,"\n")
 .replace(/-- BEGIN NQTDB named object pickups \(generated\)\n[\s\S]*?-- END NQTDB named object pickups\n/,"");
fs.writeFileSync(dest,base+L.join("\n"));
console.log(JSON.stringify({gapPairs:gaps.length,gapItems:want.size,quests:results.size,newObjectiveSources:pairs,links}));
