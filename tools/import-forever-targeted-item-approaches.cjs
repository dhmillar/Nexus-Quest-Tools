"use strict";
const fs=require("node:fs"),path=require("node:path");
const [uses,quests,nqt]=process.argv.slice(2);
const read=f=>fs.readFileSync(path.join(nqt,f),"utf8").replace(/\r\n/g,"\n");
const db=read("NQTDB.lua"), mk="-- BEGIN NQTDB targeted item approaches (generated)", end="-- END NQTDB targeted item approaches";
const base=db.replace(new RegExp(mk.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+end+"\n"),"");
const id=x=>Number.isSafeInteger(x)&&x>0;
const valid=(d,tag,build)=>d.meta?.product==="wowf"&&d.meta.license==="CC BY 4.0"&&d.meta.dataset===tag&&d.meta.clientBuild===build;
const catalog=new Map();
for(const l of read("LevelGuideData.lua").split("\n")){
 const m=l.match(/^\s*\[(\d+)\]=\{\d+,(-?\d+),-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},/);
 if(m)catalog.set(+m[1],{title:JSON.parse(m[3]),level:+m[2],obj:[...m[4].matchAll(/\{(\d+),(-?\d+),(\d+)\}/g)].map(x=>x.slice(1).map(Number))});
}
const cur=JSON.parse(fs.readFileSync(quests,"utf8"));
if(!valid(cur,"quests","1.60.1.71139")||cur.meta.locale!=="enUS"||catalog.size<5000)throw Error("Invalid current Forever quest catalog");
const prior=new Set();
for(const kind of ["ObjectiveSpots","ObjectPickupApproaches"]) {
 const s=db.split("db."+kind+"={")[1]?.split("\n}",1)[0]??"";
 for(const l of s.matchAll(/^\s*\[(\d+)\]=\{(.*)/gm))
  for(const m of l[2].matchAll(/\[(\d+)\]=/g))prior.add(l[1]+":"+m[1]);
}
const coords=p=>p&&[0,1,2991].includes(p.instance)&&id(p.uiMap)&&p.uiMap>=1400&&p.uiMap<10000&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1&&Number.isFinite(p.worldX)&&Number.isFinite(p.worldY);
const seen=new Map();let files=0;
for(const f of fs.readdirSync(uses).filter(x=>/^1\.60\.1\.\d+-item_uses\.json$/.test(x)).sort()){
 const d=JSON.parse(fs.readFileSync(path.join(uses,f),"utf8")),build=f.split("-")[0];
 if(!valid(d,"item_uses",build))throw Error("Invalid use export "+f);
 files++;
 for(const [q,items] of Object.entries(d.quests??{})){
  const live=cur.quests[q],want=catalog.get(+q);
  if(!live||!want||live.title!==want.title||live.level!==want.level)continue;
  for(const [item,row] of Object.entries(items??{})){
   if(!id(+item)||!id(row.spellId)||!id(row.sources)||!id(row.progressed)||row.progressed!==row.uses)continue;
   const obj=Object.entries(row.objectives??{}), targets=Object.entries(row.targets??{});
   if(obj.length!==1||obj[0][1]!==row.progressed||targets.length!==1||targets[0][1]!==row.uses)continue;
   const idx=+obj[0][0],key=q+":"+idx,r=live.objectives?.[idx-1],w=want.obj[idx-1];
   if(prior.has(key)||!r||!w||!id(r.amount)||w[2]!==r.amount||!id(r.objectId))continue;
   const kind=r.type==="gameObject"&&w[0]===3?"object":r.type==="monster"&&w[0]===1?"monster":null;
   const exact=kind==="object"?"object:":kind==="monster"?"npc:":null;
   if(!kind||targets[0][0]!==exact+r.objectId||w[1]!==0&&w[1]!==r.objectId)continue;
   const ps=row.positions??[];
   if(!ps.length||!ps.every(coords))continue;
   const prev=seen.get(key)??seen.set(key,{q:+q,idx,kind,target:r.objectId,amount:r.amount,item:+item,spell:row.spellId,places:new Map(),builds:new Set()}).get(key);
   if(prev.item!==+item||prev.spell!==row.spellId){prev.conflict=true;continue;}
   prev.builds.add(build);
   for(const p of ps)prev.places.set([p.uiMap,p.mapX,p.mapY].join(":"),p);
  }
 }
}
const out=[mk,"-- Exact quest objective and successful targeted item casts: Efficient Games Forever, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Source must successfully use one item against that exact objective entity, across multiple builds.",
 "-- Locations are actual player approach points, not the target's exact placement.",
 "db.TargetedItemApproaches={"];let objectives=0,total=0;
const result=new Map();
for(const r of [...seen.values()].sort((a,b)=>a.q-b.q||a.idx-b.idx)){
 if(r.conflict||r.builds.size<2||r.places.size<2)continue;
 const points=[...r.places.values()].sort((a,b)=>a.uiMap-b.uiMap||a.mapX-b.mapX||a.mapY-b.mapY);
 if(points[0].uiMap!==points.at(-1).uiMap)continue;
 const size=Math.min(points.length,8);
 const selected=Array.from({length:size},(_,i)=>points[Math.round(i*(points.length-1)/(size-1))]);
 (result.get(r.q)??result.set(r.q,[]).get(r.q)).push("["+r.idx+"]={"+JSON.stringify(r.kind)+","+r.target+","+r.amount+",{"+selected.map(p=>"{"+[p.uiMap,p.mapX,p.mapY].join(",")+"}").join(",")+"},"+r.item+"}");
 objectives++;total+=size;
}
for(const [q,rs] of result)out.push(" ["+q+"]={"+rs.join(",")+"},");
out.push("}",end,"");
if(files<14||objectives===0)throw Error("No exact repeat approached");
fs.writeFileSync(path.join(nqt,"NQTDB.lua"),base+out.join("\n"));
console.log(JSON.stringify({files,quests:result.size,objectives,points:total}));
