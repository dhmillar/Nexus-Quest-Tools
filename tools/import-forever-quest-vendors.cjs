"use strict";
const fs=require("node:fs"), path=require("node:path");
const [vendors,npcs,creatures,out]=process.argv.slice(2);
const read=n=>fs.readFileSync(path.join(out,n),"utf8");
const section=(s,key,tail=/\r?\n}/)=>(s.split(key,2)[1]??"").split(tail,1)[0];
const keys=s=>new Set([...s.matchAll(/^\s*\[(\d+)\]\s*=/gm)].map(m=>+m[1]));
const questSource=section(read("ForeverQuestFacts.lua"),"AT.ForeverQuestFacts={");
const facts=new Map([...questSource.matchAll(/^\s*\[(\d+)\]=\{\d+,\d+((?:,\{\d+,\d+\})*)\},\s*$/gm)]
 .map(m=>[+m[1],new Set([...m[2].matchAll(/\{(\d+),\d+\}/g)].map(x=>+x[1]))]));
const mobs=read("QuestMobData.lua"), rateSource=read("EverlootDrops.lua");
const anywhereDrops=new Set([...keys(section(rateSource,"  items={")), ...keys(section(mobs,"},dropMobs={"))]);
const pairDrops=new Set();
for(const s of [section(mobs,"AT.ObservedQuestCorpseSources={"),section(read("ClassicQuestDropReferences.lua"),"AT.ClassicQuestDropReferences={"),
 ...["ForeverPublicDropWindows","ForeverSoloQuestWindowSamples","ForeverGroupedQuestDropSamples","ForeverQuestDropSamples","ForeverReportedQuestDropReferences"]
  .map(k=>section(read("ForeverQuestFacts.lua"),"AT."+k+"={"))]){
 for(const row of s.split(/\r?\n/)){
  const m=row.match(/^\s*\[(\d+)\]\s*=\s*\{(.*)/);
  if(m) for(const p of m[2].matchAll(/\[(\d+)\]=/g))pairDrops.add(m[1]+":"+p[1]);
 }
}
const id=n=>Number.isSafeInteger(n)&&n>0;
const pos=p=>p&&id(p.uiMap)&&[0,1,2991].includes(p.instance)&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1;
const usableName=s=>typeof s==="string"&&s.length>0&&s.length<=100&&!/[\x00-\x1f;|\[\]]/.test(s);
function list(root,kind){
 return fs.readdirSync(root).filter(f=>new RegExp("^1\\.60\\.1\\.\\d+-"+kind+"\\.json$").test(f))
  .sort((a,b)=>+a.split(".")[3].split("-")[0]- +b.split(".")[3].split("-")[0]).map(f=>{
   const d=JSON.parse(fs.readFileSync(path.join(root,f),"utf8"));
   if(d.meta?.dataset!==kind || d.meta.product!=="wowf" || d.meta.license!=="CC BY 4.0" || d.meta.clientBuild!==f.split("-")[0])throw Error("Invalid source "+f);
   return d;
  });
}
const sideByNPC=new Map(),sideNumber={Alliance:1,Horde:2,Neutral:0};
for(const d of list(npcs,"npcs")){
 for(const [k,row] of Object.entries(d.npcs??{})){
  const side=sideNumber[row.side];
  if(side===undefined||!usableName(row.name)||!id(+k))continue;
  const key=k+":"+row.name;
  if(!sideByNPC.has(key))sideByNPC.set(key,side);
  else if(sideByNPC.get(key)!==side)sideByNPC.set(key,null);
 }
}
// The NPC interaction exports include world props implemented as invisible or
// non-targetable creatures. Only use independently verified humanoid actors.
const targetable=new Map();
for(const build of fs.readdirSync(creatures)){
 const file=path.join(creatures,build,"creature_details.enUS.json");
 if(!fs.existsSync(file))continue;
 const d=JSON.parse(fs.readFileSync(file,"utf8"));
 if(d.meta?.dataset!=="creature_details"||d.meta.license!=="CC BY 4.0"||
    d.meta.product!=="wowf"||d.meta.locale!=="enUS"||d.meta.clientBuild!==build)throw Error("Invalid creature details "+build);
 for(const [k,r] of Object.entries(d.creatures??{})){
  if(!id(+k)||!usableName(r.name))continue;
  const key=k+":"+r.name;
  const hasBody=r.displays?.some(m=>id(m.displayId)&&m.displayId!==11686&&m.displayId!==1126&&m.probability>0);
  const actor=r.type===7&&hasBody&&Number.isSafeInteger(r.flags?.[0])&&(r.flags[0]&0x02000000)===0;
  if(!targetable.has(key)||targetable.get(key))targetable.set(key,Boolean(actor));
 }
}
const index=new Map();
const vendorFiles=list(vendors,"vendors");
for(const d of vendorFiles)for(const [k,row] of Object.entries(d.vendors??{})){
 if(!usableName(row.name)||!id(+k)||targetable.get(k+":"+row.name)!==true)continue;
 const side=sideByNPC.get(k+":"+row.name);
 if(side===null||side===undefined)continue;
 const p=row.positions?.filter(pos)??[];
 if(!p.length || p.some(x=>x.uiMap!==p[0].uiMap||Math.hypot(x.mapX-p[0].mapX,x.mapY-p[0].mapY)>.02))continue;
 for(const [item,v] of Object.entries(row.entries??{})){
  if(item!=="item:"+v.itemId||!id(v.itemId)||!id(v.sources)||!(Object.values(v.costs??{}).some(id)))continue;
  const rows=index.get(v.itemId)??new Map();
  const key=k+":"+p[0].uiMap,old=rows.get(key);
  if(old&&Math.hypot(p[0].mapX-old[4],p[0].mapY-old[5])>.025) {rows.set(key,false);continue;}
  if(old===false)continue;
  rows.set(key,[+k,row.name,side,p[0].uiMap,+p[0].mapX.toFixed(4),+p[0].mapY.toFixed(4)]);
  index.set(v.itemId,rows);
 }
}
const selected=new Map(), mapping={};
let matchItems=0,dropPairs=0;
for(const [quest,items] of facts)for(const item of items){
 const rows=index.get(item);
 if(!rows||![...rows.values()].some(Boolean))continue;
 matchItems++;
 if(anywhereDrops.has(item)||pairDrops.has(quest+":"+item)) {dropPairs++;continue;}
 (mapping[quest]??=[]).push(item);
 selected.set(item,rows);
}
const L=["-- BEGIN NQTDB merchant facts (generated)",
 "-- Efficient Games vendor and NPC observations, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Exact quest/objective item without a known loot source; NPC must match the local map and faction.",
 "db.VendorObjectives={"];
for(const [q,items] of Object.entries(mapping))L.push(" ["+q+"]={"+items.sort((a,b)=>a-b).map(i=>"["+i+"]=true").join(",")+"},");
L.push("}","-- item -> {NPC ID, English name, faction, map, x, y}.","db.ObjectiveVendors={");
let count=0;
for(const [item,values] of [...selected].sort((a,b)=>a[0]-b[0])){
 const rows=[...values.values()].filter(Boolean).sort((a,b)=>a[3]-b[3]||a[0]-b[0]);
 count+=rows.length;
 L.push(" ["+item+"]={"+rows.map(r=>"{"+r.map(x=>typeof x==="string"?JSON.stringify(x):x).join(",")+"}").join(",")+"},");
}
L.push("}","-- END NQTDB merchant facts","");
const dest=path.join(out,"NQTDB.lua");
const orig=read("NQTDB.lua").replace(/\r\n/g,"\n");
const stripped=orig.replace(/-- BEGIN NQTDB merchant facts \(generated\)\r?\n[\s\S]*?-- END NQTDB merchant facts\r?\n/,"");
if(vendorFiles.length<10||selected.size<10||count<20)throw Error("Incomplete source set");
fs.writeFileSync(dest,stripped+L.join("\n"));
console.log(JSON.stringify({matchItems,dropPairs,quests:Object.keys(mapping).length,items:selected.size,merchantItem:count,questItem:Object.values(mapping).reduce((a,b)=>a+b.length,0),builds:vendorFiles.length,examples:Object.entries(mapping).slice(0,20)}));
