"use strict";
const fs=require("fs"),path=require("path");
const [copies,loot,output]=process.argv.slice(2);
const mobPath=path.join(output,"QuestMobData.lua"), original=fs.readFileSync(mobPath,"utf8");
const factPath=path.join(output,"ForeverQuestFacts.lua");
const facts=new Map([...fs.readFileSync(factPath,"utf8").split("AT.ForeverQuestFacts={")[1].split(/\r?\n}/)[0]
 .matchAll(/^\s*\[(\d+)\]=\{\d+,\d+((?:,\{\d+,\d+\})*)\},\s*$/gm)].map(m=>[+m[1],new Set([...m[2].matchAll(/\{(\d+),\d+\}/g)].map(x=>+x[1]))]));
const old=new Map([...original.split("AT.QuestMobData={ creatures={")[1].split(/\r?\n},killLabels=/)[0].matchAll(/^\s*\[(\d+)\]=\{("(?:[^"\\]|\\.)*"),\d+,\d+,"[^"]*"(?:,(\d+))?\},/gm)].map(m=>[+m[1],{name:JSON.parse(m[2]),display:+m[3]||0}]));
if(old.size<8000)throw Error("Unexpected original catalog");
const valid=(d,t)=>d.meta?.product==="wowf"&&d.meta?.dataset===t&&d.meta?.license==="CC BY 4.0";
const eligibleName=n=>typeof n==="string"&&n.length>0&&n.length<=100&&!/[\x00-\x1f;|\[\]]/.test(n);
const id=n=>Number.isSafeInteger(n)&&n>0;
const known=new Map();
for(const f of fs.readdirSync(copies).sort((a,b)=>+a.split(".").at(-1)- +b.split(".").at(-1))){
 const p=path.join(copies,f,"creature_details.enUS.json");if(!fs.existsSync(p))continue;
 const d=JSON.parse(fs.readFileSync(p,"utf8"));if(!valid(d,"creature_details")||d.meta.locale!=="enUS")continue;
 for(const [key,r] of Object.entries(d.creatures||{})){
  if(!eligibleName(r.name)||!id(+key))continue;
  const prev=old.get(+key);
  if(prev&&prev.name!==r.name)continue;
  const displays=(r.displays||[]).filter(x=>id(x.displayId)&&x.displayId!==11686&&x.displayId!==1126&&x.probability>0).sort((a,b)=>b.probability-a.probability);
  if(displays.length===1||displays[0]&&displays[0].probability>displays[1].probability){
    known.set(+key,{name:r.name,display:displays[0].displayId,build:d.meta.clientBuild});
  }
 }
}
const links={}, npcs=new Set();
for(const f of fs.readdirSync(loot).filter(s=>/^1\.60\.1\.\d+-loot\.json$/.test(s))){
 const d=JSON.parse(fs.readFileSync(path.join(loot,f),"utf8"));if(!valid(d,"loot")||d.format!==3)continue;
 for(const [key,r] of Object.entries(d.sources||{})){
  const hit=key.match(/^npc:(\d+)\|quest(?:\|group)?$/);if(!hit)continue;
  const npc=+hit[1];if(!(old.has(npc)||known.has(npc)))continue;
  for(const [q,rec] of Object.entries(r.quests||{})){
   const wanted=facts.get(+q);
   if(!wanted?.size)continue;
   for(const [item,stats] of Object.entries(rec.items||{})){
    if(!wanted.has(+item)||!id(stats.drops)||stats.drops>rec.windows||(stats.shared||0)!==0)continue;
    const byQuest=links[q]??={}, list=byQuest[item]??=new Set();
    list.add(npc);npcs.add(npc);
   }
  }
 }
}
let added=0,filled=0,linkCount=0;
const data=["","-- Supplemental observed creature portraits and exact quest/item corpse sources.","-- Efficient Games (https://efficient.games), CC BY 4.0 https://creativecommons.org/licenses/by/4.0/.","-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/main/data/wowf"];
for(const [npc,r] of [...known].sort((x,y)=>x[0]-y[0])){
 const orig=old.get(npc);
 if(orig?.display)continue;
 if(orig){filled++;data.push("AT.QuestMobData.creatures["+npc+"][5]="+r.display);}
 else if(npcs.has(npc)){added++;data.push("AT.QuestMobData.creatures["+npc+"]={"+JSON.stringify(r.name)+',0,0,"",'+r.display+"}");}
}
data.push("AT.ObservedQuestCorpseSources={");
for(const [q,items] of Object.entries(links)){
 const rows=[];
 for(const [item,ids] of Object.entries(items)){
  const ds=[...ids].sort((a,b)=>a-b);
  if(ds.length){linkCount++;rows.push("["+item+"]={"+ds.join(",")+"}");}
 }
 if(rows.length)data.push(" ["+q+"]={"+rows.join(",")+"},");
}
data.push("}","");
if(original.includes("AT.ObservedQuestCorpseSources=")||filled<1||linkCount<50)throw Error("Unexpected coverage");
fs.appendFileSync(mobPath,data.join("\n"));
console.log(JSON.stringify({filled,added,linkCount,quests:Object.keys(links).length}));
