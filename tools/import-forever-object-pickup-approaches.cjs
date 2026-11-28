"use strict";
const fs=require('node:fs'), path=require('node:path');
const [source,nqt]=process.argv.slice(2);
const read=(d,f)=>JSON.parse(fs.readFileSync(path.join(d,f),"utf8"));
const lua=f=>fs.readFileSync(path.join(nqt,f),"utf8").replace(/\r\n/g,"\n");
const start="-- BEGIN NQTDB object pickup approaches (generated)",end="-- END NQTDB object pickup approaches";
const db=lua("NQTDB.lua"), base=db.replace(new RegExp(start.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+end+"\n"),"");
const section=k=>db.split("\n"+k+"={\n")[1]?.split("\n}",1)[0]??"";
const check=(d,f,tag)=>{
  if(d.meta?.dataset!==tag||d.meta?.clientBuild!==f.split("-")[0]||d.meta?.license!=="CC BY 4.0"||d.meta?.product!=="wowf")throw Error("Bad metadata: "+f);
};
const qf="1.60.1.71139-quests.enUS.json", current=read(source,qf);
check(current,qf,"quests");
if(current.meta.locale!=="enUS")throw Error("Unexpected locale");
const id=v=>Number.isSafeInteger(v)&&v>0;
const catalog=new Map();
for(const line of lua("LevelGuideData.lua").split("\n")){
 const m=line.match(/^\s*\[(\d+)\]=\{\d+,(-?\d+),-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},/);
 if(m)catalog.set(+m[1],{level:+m[2],title:JSON.parse(m[3]),objectives:[...m[4].matchAll(/\{(\d+),(-?\d+),(\d+)\}/g)].map(x=>x.slice(1).map(Number))});
}
const old=new Map();
for(const l of section("db.ObjectiveSpots").split("\n")){
 const m=l.match(/^\s*\[(\d+)\]=\{(.*)/);
 if(m)old.set(+m[1],new Set([...m[2].matchAll(/\[(\d+)\]=/g)].map(x=>+x[1])));
}
const owners=new Map();
for(const raw of Object.values(current.quests))for(const item of new Set((raw.objectives??[]).filter(o=>o.type==="item").map(o=>o.objectId)))
 owners.set(item,(owners.get(item)??0)+1);
const byItem=new Map();
for(const l of section("db.NamedObjectPickups").split("\n")){
 const m=l.match(/^\s*\[(\d+)\]=\{(.*)/);if(!m)continue;
 const q=+m[1], c=catalog.get(q), raw=current.quests[q];
 if(!c||!raw||raw.title!==c.title||raw.level!==c.level)continue;
 for(const e of m[2].matchAll(/\[(\d+)\]=\{((?:\{\d+,"(?:\\.|[^"\\])*"\},?)+)\}/g)){
  const item=+e[1], matches=c.objectives.filter(x=>x[0]===2&&x[1]===item);
  if(matches.length!==1||raw.startItemId===item)continue;
  const index=c.objectives.indexOf(matches[0])+1, amt=matches[0][2], exact=raw.objectives?.[index-1];
  if(old.get(q)?.has(index)||!id(amt)||exact?.type!=="item"||exact?.objectId!==item||exact?.amount!==amt)continue;
  const target={q,item,index,amt,objects:new Set([...e[2].matchAll(/\{(\d+),/g)].map(x=>+x[1])),samples:new Map()};
  (byItem.get(item)??byItem.set(item,[]).get(item)).push(target);
 }
}
const valid=p=>p&&[0,1,2991].includes(p.instance)&&id(p.uiMap)&&p.uiMap>=1400&&p.uiMap<10000&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1&&Number.isFinite(p.worldX)&&Number.isFinite(p.worldY);
let sources=0;
for(const f of fs.readdirSync(source).filter(f=>f.endsWith("-loot.json")).sort()){
 const d=read(source,f);check(d,f,"loot");
 if(d.format!==3)throw Error("Unexpected loot format");
 sources++;
 for(const [k,row] of Object.entries(d.sources??{})){
  const m=k.match(/^object:(\d+)(\|spell:\d+)?(\|quest)?(\|group)?$/);if(!m)continue;
  const pairs=Object.entries(row.items??{});if(pairs.length!==1)continue;
  const [i,r]=pairs[0], idItem=+i;
  if(!id(row.windows)||r.drops!==row.windows||(r.shared??0)!==0||r.quest!==true&&!id(r.quest))continue;
  const points=row.positions?.filter(valid)??[];
  if(points.length===0)continue;
  for(const target of byItem.get(idItem)??[]){
   if(id(r.quest)&&r.quest!==target.q||!target.objects.has(+m[1]))continue;
   // A Boolean quest status cannot discriminate two quests using the same item.
   if(r.quest===true&&owners.get(idItem)!==1)continue;
   const s=target.samples.get(+m[1])??{builds:new Set(),points:new Map()};
   s.builds.add(d.meta.clientBuild);
   for(const p of points)s.points.set(p.uiMap+":"+p.mapX+":"+p.mapY,[p.uiMap,p.mapX,p.mapY]);
   target.samples.set(+m[1],s);
  }
 }
}
if(sources<15||catalog.size<5000)throw Error("Missing expected corpus");
const L=[start,"-- Efficient Games Forever loot approach observations, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Sole guaranteed quest item in each sampled object window; same object observed across builds.",
 "-- These are player approach samples, not exact object pins or general movement guarantees.",
 "db.ObjectPickupApproaches={"];
const out=new Map();
let objectives=0,total=0;
for(const target of [...byItem.values()].flat().sort((a,b)=>a.q-b.q||a.index-b.index)){
 const points=new Map();
 for(const s of target.samples.values())if(s.builds.size>=2&&s.points.size>=2)for(const [k,p] of s.points)points.set(k,p);
 if(!points.size)continue;
 // Bound output and reject multi-zone objects rather than send across the wrong scene.
 const all=[...points.values()].sort((a,b)=>a[0]-b[0]||a[1]-b[1]||a[2]-b[2]);
 if(all[0][0]!==all.at(-1)[0])continue;
 const pick=new Set();
 // Spread sample points over the observed track instead of extrapolating.
 for(let j=0,n=Math.min(all.length,6);j<n;j++)pick.add(all[Math.round(j*(all.length-1)/(n-1))]);
 if(pick.has(undefined))throw Error("Unexpected singleton");
 (out.get(target.q)??out.set(target.q,[]).get(target.q)).push("["+target.index+"]={\"item\","+target.item+","+target.amt+",{"+[...pick].map(p=>"{"+p.join(",")+"}").join(",")+"}}");
 objectives++;total+=pick.size;
}
for(const [q,r] of out)L.push(" ["+q+"]={"+r.join(",")+"},");
L.push("}",end,"");
if(!objectives)throw Error("No qualifying approaches");
fs.writeFileSync(path.join(nqt,"NQTDB.lua"),base+L.join("\n"));
console.log(JSON.stringify({candidateItems:byItem.size,quests:out.size,objectives,points:total}));
