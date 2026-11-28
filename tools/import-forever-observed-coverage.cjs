"use strict";
const fs=require("fs"), path=require("path");
const [input,N]=process.argv.slice(2);
const read=f=>fs.readFileSync(path.join(N,f),"utf8");
const catalogue=new Map();
for(const line of read("LevelGuideData.lua").split(/\r?\n/)){
 const m=line.match(/^\s*\[(\d+)\]=\{\d+,\d+,-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},/);
 if(m){try{catalogue.set(+m[1],{title:JSON.parse(m[2]),objectives:[...m[3].matchAll(/\{(\d+),(-?\d+),(\d+)\}/g)].map(x=>x.slice(1).map(Number))});}catch{}}
}
if(catalogue.size<5000)throw Error("bad Forever catalogue");
const listed=(s,keys)=>new Set(keys.flatMap(k=>[...(s.split("AT."+k+"={")[1]??"").split(/\r?\n}/)[0].matchAll(/^\s*\[(\d+)\]\s*=/gm)].map(r=>+r[1])));
const guide=read("LevelGuideGivers.lua"),facts=read("ForeverQuestFacts.lua"),verified=read("ForeverVerifiedEndpoints.lua");
const haveStart=listed(guide,["LevelGuideQuestGivers","LevelGuideMoreOffers","LevelGuideItemStarts"]);
const haveEnd=new Set([...listed(verified,["ForeverVerifiedEndpointReferences","ForeverSupplementalTurnInReferences"]),
 ...listed(facts,["ForeverQuestNPCReferences","ForeverATTQuestNPCReferences"]),...listed(read("ForeverTownPins.lua"),["ObservedQuestTurnIns"])]);
const validId=n=>Number.isSafeInteger(n)&&n>0;
const nameOK=n=>typeof n==="string"&&n.length>0&&n.length<=100&&!/[\x00-\x1f;|\[\]]/.test(n);
const round=n=>+n.toFixed(4);
const coord=p=>p&&validId(p.uiMap)&&[0,1,2991].includes(p.instance)&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1;
const starts={},ends={},uses={},spots={};
const objectiveTypes={monster:1,item:2,object:3};
for(const file of fs.readdirSync(input).filter(f=>/-((npcs)|(item_uses)|(objectives))\.json$/.test(f)).sort((a,b)=>+a.split(/[.-]/)[3]- +b.split(/[.-]/)[3])){
 const data=JSON.parse(fs.readFileSync(path.join(input,file),"utf8")),tag=data.meta?.dataset;
 if(data.meta?.product!=="wowf"||data.meta?.license!=="CC BY 4.0"||!tag)continue;
 if(tag==="npcs"){
  for(const [kind,entities] of [[1,data.npcs],[2,data.objects]]){
   for(const [id,npc] of Object.entries(entities||{})){
    if(!validId(+id)||!nameOK(npc.name))continue;
    let p=npc.positions?.filter(coord)||[];
    if(!p.length||p.some(x=>x.uiMap!==p[0].uiMap||Math.hypot(x.mapX-p[0].mapX,x.mapY-p[0].mapY)>.012))continue;
    const a=p[0],side=npc.side==="Alliance"?1:npc.side==="Horde"?2:0;
    for(const [part,dest,prior] of [["offers",starts,haveStart],["takes",ends,haveEnd]]){
     if(kind===2&&part==="offers")continue;
     for(const [q,rel] of Object.entries(npc[part]||{})){
      if(prior.has(+q)||catalogue.get(+q)?.title!==rel.title)continue;
      const next=[a.uiMap,round(a.mapX),round(a.mapY),kind,+id,side,npc.name];
      const old=dest[q];
      if(old===false)continue;
      if(old&&(old[0]!==next[0]||old[3]!==kind||old[4]!==+id||Math.hypot(old[1]-next[1],old[2]-next[2])>.012)){dest[q]=false;continue;}
      dest[q]=next;
     }
    }
   }
  }
 }else if(tag==="item_uses"){
  for(const [q,items] of Object.entries(data.quests||{})){
   if(!catalogue.has(+q))continue;
   for(const [item,u] of Object.entries(items||{})){
    if(!validId(+item)||!validId(u.spellId)||!validId(u.progressed)||!(Object.keys(u.objectives||{}).length))continue;
    const r=uses[q]??={};
    r[item]=r[item]===undefined||r[item]===u.spellId?u.spellId:false;
   }
  }
 }else if(tag==="objectives"){
  for(const [q,objectives] of Object.entries(data.quests||{})){
   const c=catalogue.get(+q);
   if(!c)continue;
   for(const [index,o] of Object.entries(objectives||{})){
    const k=objectiveTypes[o.type],expected=c.objectives[+index-1];
    if(!k||!expected||expected[0]!==k||expected[2]!==o.required||!validId(expected[1])||o.gains<2)continue;
    if(c.objectives.filter(a=>a[0]===k&&a[2]===o.required).length!==1)continue;
    const positions=o.positions?.filter(coord)||[];
    if(!positions.length)continue;
    const r=spots[q]??={},a=r[index]??={type:o.type,target:expected[1],required:o.required,points:new Map()};
    if(a.type!==o.type||a.target!==expected[1]||a.required!==o.required)throw Error("conflicting objective joins");
    for(const p of positions){
     const key=[p.uiMap,Math.floor(p.mapX*50),Math.floor(p.mapY*50)].join(":");
     if(!a.points.has(key)&&a.points.size<10)a.points.set(key,[p.uiMap,round(p.mapX),round(p.mapY)]);
    }
   }
  }
 }
}
const qstr=s=>JSON.stringify(s);
function lua(v){return Array.isArray(v)?"{"+v.map(lua).join(",")+"}":typeof v==="string"?qstr(v):String(v);}
function table(name,rows){return ["AT."+name+"={",...Object.entries(rows).filter(([,v])=>v).map(([q,v])=>" ["+q+"]="+lua(v)+","),"}"];}
const rows={};
const oldUse=listed(facts,["ForeverObservedQuestUses","ForeverProvidedQuestUses","ForeverInstructedQuestUses"]);
for(const [q,rs] of Object.entries(uses)){
 const exact=Object.entries(rs).filter(([i,s])=>s).map(([i,s])=>[+i,s]);
 if(exact.length&&!oldUse.has(+q))rows[q]=exact;
}
const L=["-- Adapted from Efficient Games Forever observations, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- www.efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Exact observations only; preserve native and bundled sources before these fallbacks.",
 "local _,AT=...",
 ...table("ForeverIndependentStarts",Object.fromEntries(Object.entries(starts).filter(([,p])=>p).map(([q,p])=>[q,[[p[0],p[1],p[2],p[5],p[4],p[6],0]]]))),
 ...table("ForeverIndependentTurnIns",Object.fromEntries(Object.entries(ends).filter(([,p])=>p).map(([q,p])=>[q,[p]]))),
 ...table("ForeverIndependentQuestUses",rows),"AT.ForeverIndependentObjectiveSpots={"];
for(const [q,rs] of Object.entries(spots))L.push(" ["+q+"]={"+Object.entries(rs).map(([idx,a])=>"["+idx+"]="+lua([a.type,a.target,a.required,[...a.points.values()]] )).join(",")+"},");
L.push("}","");
const result={starts:Object.values(starts).filter(Boolean).length,ends:Object.values(ends).filter(Boolean).length,uses:Object.keys(rows).length,objectiveQuests:Object.keys(spots).length,objectiveRows:Object.values(spots).reduce((a,b)=>a+Object.keys(b).length,0)};
if(result.ends+result.starts+result.uses+result.objectiveRows<25)throw Error("insufficient verified data");

const generated=L.join("\n").replace("local _,AT=...","local _,AT=...\nlocal db={}\nAT.NQTDB=db")
    .replace(/AT\.ForeverIndependent(Starts|TurnIns|QuestUses|ObjectiveSpots)/g,"db.$1");
const catalogBindings=[
 "db.Quests=AT.ForeverLevelGuideQuests",
 "db.QuestFacts=AT.ForeverQuestFacts",
 "db.Creatures=AT.QuestMobData and AT.QuestMobData.creatures",
 "db.CorpseSources=AT.ObservedQuestCorpseSources",
 "db.ClassicDropRefs=AT.ClassicQuestDropReferences",
 "db.ClassicCreatureRefs=AT.ClassicQuestCreatureProfiles",
];
fs.writeFileSync(path.join(N,"NQTDB.lua"),generated+"\n"+catalogBindings.join("\n")+"\n");
console.log(result);

