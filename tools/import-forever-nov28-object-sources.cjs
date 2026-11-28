"use strict";
// A bounded source-label patch from the November 28 build-71139 snapshot.
// Run from the checkout: node tools/import-forever-nov28-object-sources.cjs SOURCE_DIR [NQT]
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const [input,nqt="NQT"]=process.argv.slice(2);
const pin={
 "quests.enUS":["quests","a32f4cd30311c9e32223a84228c87fcb017042e251abea866dd7bc524c00ae47"],
 "object_details.enUS":["object_details","9fbbd8a681f46f5479bb4668630c0d362685b7cd2c1bf71bc6ed6472c774707c"],
 loot:["loot","0d3d8ccdf5d200be42469cd87237caab80be01423501ad7372550ba8df3b77d8"],
 objectives:["objectives","d36dc859d52a5aa2f4b4aadd5bad0f8da7968e768549706281ba9c868afcf165"],
};
function load(file){
 const b=fs.readFileSync(path.join(input,file+".json"));
 const [tag,hash]=pin[file];
 if(crypto.createHash("sha256").update(b).digest("hex")!==hash)throw Error("Wrong pinned "+file);
 const d=JSON.parse(b),m=d.meta;
 if(m?.dataset!==tag||m?.clientBuild!=="1.60.1.71139"||m?.license!=="CC BY 4.0"||m?.product!=="wowf"||
    m?.collectedOn?.last!=="2026-11-28"||(file.endsWith(".enUS")&&m.locale!=="enUS")||(tag==="loot"&&d.format!==3))
   throw Error("Unexpected snapshot metadata: "+file);
 return d;
}
const {quests}=load("quests.enUS"),{objects}=load("object_details.enUS"),{sources}=load("loot"),{quests:observed}=load("objectives");
const shortlist=[
 [99130,286214,694855],[7850,19071,179922],[99127,286205,694772],[99143,286209,694785],
 [98197,279822,670774],[93160,257128,613238],[94485,265105,619450],[94896,266433,623295],
 [2641,8526,141853],[4787,12402,175889],[7849,19070,179914],[7849,19069,179915],[207,2008,54],
 [98197,279821,670771],[98197,279821,670773],[98208,279915,670962],[1598,6785,83763],
];
const pos=n=>Number.isSafeInteger(n)&&n>0;
const coord=p=>{
 if(!Number.isSafeInteger(p?.instance)||p.instance<0||!pos(p.uiMap)||!Number.isFinite(p.worldX)||
    !Number.isFinite(p.worldY)||!Number.isFinite(p.mapX)||!Number.isFinite(p.mapY)||
    p.mapX<=0||p.mapX>=1||p.mapY<=0||p.mapY>=1)return null;
 return [p.instance,p.uiMap,p.worldX,p.worldY,p.mapX,p.mapY].join(":");
};
const baselineFile=path.join(nqt,"NQTDB.lua");
const original=fs.readFileSync(baselineFile,"utf8");
const normalized=original.replaceAll("\r\n","\n");
const begin="-- BEGIN NQTDB November 28 exact object witnesses (generated)";
const end="-- END NQTDB November 28 exact object witnesses";
const start=normalized.indexOf(begin),finish=normalized.indexOf(end);
if((start<0)!==(finish<0)||start>=0&&finish<start)throw Error("Broken existing generated section");
const base=start<0?normalized:normalized.slice(0,start)+normalized.slice(finish+end.length+1);
const existing=new Set();
for(const table of ["NamedObjectPickups","WitnessedObjectPickups"]){
 const body=base.split("db."+table+"={\n")[1]?.split("\n}",1)[0];
 if(!body)throw Error("No baseline "+table);
 for(const m of body.matchAll(/^\s*\[(\d+)\]=\{(.+)\},?$/gm)){
  for(const item of m[2].matchAll(/\[(\d+)\]=/g))existing.add(+m[1]+":"+item[1]);
 }
}
const guide=new Map();
const guideFile=fs.readFileSync(path.join(nqt,"LevelGuideData.lua"),"utf8");
const guideTable=guideFile.replaceAll("\r\n","\n").split("AT.ForeverLevelGuideQuests={\n")[1]?.split("\n}",1)[0];
if(!guideTable)throw Error("No Level Guide catalog");
for(const m of guideTable.matchAll(/^\s*\[(\d+)\]=\{\d+,-?\d+,-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},$/gm)){
 guide.set(+m[1],{title:JSON.parse(m[2]),items:[...m[3].matchAll(/\{2,(\d+),(\d+)\}/g)].map(a=>[+a[1],+a[2]])});
}
const owners=new Map();
for(const [qid,quest] of Object.entries(quests))for(const objective of quest.objectives??[]){
 if(objective.type==="item"&&pos(objective.objectId)){
  const o=owners.get(objective.objectId)??[];
  o.push(+qid);
  owners.set(objective.objectId,o);
 }
}
const results=new Map(),held=new Map();
const hold=(q,i,o,why)=>held.set(q+":"+i+":"+o,why);
for(const [q,i,o] of shortlist){
 const key=q+":"+i,d=objects[o],quest=quests[q],g=guide.get(q),owner=owners.get(i);
 if(existing.has(key)){hold(q,i,o,"already shipped");continue;}
 if(!d||d.type!==3||typeof d.name!=="string"||d.name.length<2||d.name.length>100||/[|\x00-\x1f]/.test(d.name)||
    !d.questItems?.includes(i)){hold(q,i,o,"no exact labeled object template");continue;}
 if(!quest||!g||owner?.length!==1||owner[0]!==q||quest.title!==g.title||quest.startItemId===i){hold(q,i,o,"quest identity");continue;}
 const target=quest.objectives.filter(x=>x.type==="item"&&x.objectId===i);
 if(target.length!==1||!pos(target[0].amount)||g.items.filter(x=>x[0]===i&&x[1]===target[0].amount).length!==1){
  hold(q,i,o,"exact item count");continue;
 }
 const required=target[0].amount, events=Object.entries(observed[q]??{});
 const qualified=events.flatMap(([index,event])=>event.type==="item"&&event.required===required?
  [[index,new Set(event.positions.map(coord).filter(Boolean))]]:[]);
 const hits=new Map();
 let windows=0; const positions=new Set();
 for(const [tag,src] of Object.entries(sources)){
  if(+tag.match(/^object:(\d+)(?:\|spell:\d+)?(?:\|quest)?(?:\|group)?$/)?.[1]!==o)continue;
  const v=src.items?.[i];
  if(v?.quest!==true||!pos(v.drops)||!pos(src.windows)||v.drops!==src.windows||(v.shared??0)!==0)continue;
  const look=new Set(src.positions?.map(coord).filter(Boolean));
  for(const [index,exact] of qualified){
   const match=[...look].filter(p=>exact.has(p));
   if(!match.length)continue;
   for(const p of match)positions.add(p);
   hits.set(index,true);
   windows+=src.windows;
  }
 }
 // Quest authoring storageIndex and the observed UI objective numbers are
 // not interchangeable. Only the unique current count+coordinate match wins.
 if(hits.size!==1||!positions.size){hold(q,i,o,"no unique map/world objective witness");continue;}
 const out=results.get(key)??{q,i,evidence:[]};
 out.evidence.push({object:o,name:d.name,objective:[...hits.keys()][0],required,windows,coordinates:[...positions].sort()});
 results.set(key,out);
}
for(const [key,row] of results){
 const competing=Object.entries(sources).flatMap(([tag,source])=>{
  const id=+tag.match(/^object:(\d+)/)?.[1],i=row.i;
  return pos(id)&&source.items?.[i]?.quest===true&&pos(source.items[i].drops)?[id]:[];
 });
 const names=new Set(row.evidence.map(p=>p.name));
 const ids=new Set(row.evidence.map(p=>p.object));
 if(names.size!==1||competing.some(id=>!ids.has(id))){
  for(const p of row.evidence)hold(row.q,row.i,p.object,"unresolved alternative source");
  results.delete(key);
 }
}
if(results.size!==10||held.size!==6)throw Error("Pinned expected 10 verified objectives and 6 skipped leads; got "+results.size+"/"+held.size);
const lines=[begin,
 "-- Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0.",
 "-- https://creativecommons.org/licenses/by/4.0/",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/62b0bbc6786fb719ace03c57b39f3255e908f06f/data/wowf/1.60.1.71139",
 "-- Source labels only; no manufactured percentages, map pins, route points, or NPC targets.",
 "do"];
const keyed=new Map();
for(const row of results.values()){
 const rows=keyed.get(row.q)??[];
 rows.push(row);
 keyed.set(row.q,rows);
}
for(const [q,rows] of [...keyed].sort((a,b)=>a[0]-b[0])){
 lines.push(" local row=db.WitnessedObjectPickups["+q+"] or {}");
 for(const r of rows.sort((a,b)=>a.i-b.i)){
  const i=r.i,id=r.evidence.length===1?r.evidence[0].object:0;
  lines.push(" row["+i+"]=row["+i+"] or {"+id+","+JSON.stringify(r.evidence[0].name)+"}");
 }
 lines.push(" db.WitnessedObjectPickups["+q+"]=row");
}
lines.push("end",end,"");
const generated=base+lines.join("\n");
fs.writeFileSync(baselineFile,original.includes("\r\n")?generated.replaceAll("\n","\r\n"):generated);
for(const row of results.values())console.log(JSON.stringify(row));
for(const [skipped,reason] of held)console.log(JSON.stringify({skipped,reason}));
