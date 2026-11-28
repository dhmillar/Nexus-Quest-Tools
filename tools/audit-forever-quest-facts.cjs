"use strict";
const fs=require("node:fs"), path=require("node:path"), crypto=require("node:crypto");
const [input,addon]=process.argv.slice(2);
const raw=fs.readFileSync(input);
const sha=crypto.createHash("sha256").update(raw).digest("hex");
if(sha!=="8048fa65bb8ac0ec088b47a6fcd2ee000df05664535ab32a49a52dd80ca6994b")throw Error("Expected pinned Nov 27 Efficient Games snapshot");
const data=JSON.parse(raw);
const m=data.meta;
if(m?.product!=="wowf"||m.dataset!=="quests"||m.locale!=="enUS"||
   m.clientBuild!=="1.60.1.71139"||m.license!=="CC BY 4.0")throw Error("Expected validated Forever quest metadata");
const read=f=>fs.readFileSync(path.join(addon,f),"utf8").replace(/\r\n/g,"\n");
const slice=(s,k)=>s.split("AT."+k+"={\n")[1]?.split("\n}",1)[0]??"";
const internal=s=>/^\s*(?:<(?:nyi|unused|test|txt|dnt|ph|deprecated)>|\[(?:nyi|unused|test|txt|dnt|ph|deprecated)\]|test quest|qa[\s:_]|unused[:\s]|deprecated[:\s])/i.test(s??"");
const guide=new Map(),facts=new Map(),issues=[];
const add=(map,k,o,which)=>{if(map.has(k))issues.push([k,"duplicate "+which]);map.set(k,o);};
const pairs=items=>items.map(([id,n])=>[+id,+n]).sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
for(const l of slice(read("LevelGuideData.lua"),"ForeverLevelGuideQuests").split("\n")){
 if(!/^\s*\[\d+\]/.test(l))continue;
 const r=l.match(/^\s*\[(\d+)\]=\{(\d+),(-?\d+),(-?\d+),(\d+),"([a-fA-F0-9]+)",(\d+),([\d.]+),(\d+),("(?:\\.|[^"\\])*"),\{(.*)\}\},$/);
 if(!r)throw Error("Unreadable guide row "+l.slice(0,42));
 const title=JSON.parse(r[10]),items=pairs([...r[11].matchAll(/\{2,(\d+),(\d+)\}/g)].map(o=>o.slice(1)));
 add(guide,+r[1],{title,min:+r[2],level:+r[3],area:+r[4],race:r[6].toLowerCase(),class:BigInt(r[9]),items}, "guide");
}
for(const l of slice(read("ForeverQuestFacts.lua"),"ForeverQuestFacts").split("\n")){
 if(!/^\s*\[\d+\]/.test(l))continue;
 const r=l.match(/^\s*\[(\d+)\]=\{(\d+),(-?\d+)((?:,\{\d+,\d+\})*)\},$/);
 if(!r)throw Error("Unreadable quest facts row "+l.slice(0,42));
 const items=pairs([...r[4].matchAll(/\{(\d+),(\d+)\}/g)].map(o=>o.slice(1)));
 add(facts,+r[1],{min:+r[2],level:+r[3],items}, "quest facts");
}
if(guide.size<5500||facts.size<5500)throw Error("Wrong audit baseline");
let audited=0, auditedItems=0, sourceOnly=0, sourceInternal=0, internalGuide=0, packItemPairs=0;
for(const [q,v] of guide){
 const isInternal=internal(v.title)||q<=3;
 if(isInternal)internalGuide++;
 const f=facts.get(q);
 if(!f&&isInternal)continue; // a placeholder has no gameplay fact set
 if(!f||f.min!==v.min||f.level!==v.level||!same(f.items,v.items))issues.push([q,"guide/facts disagreement"]);
 packItemPairs+=v.items.length;
}
for(const [id,v] of Object.entries(data.quests??{})){
 const q=+id,g=guide.get(q);
 if(!g){sourceOnly++;if(internal(v.title)||!(v.level>0))sourceInternal++;continue;}
 audited++;
 if(g.title!==v.title)issues.push([q,"guide/current title",g.title,v.title]);
 if(g.min!==v.minLevel)issues.push([q,"guide/current minimum level",g.min,v.minLevel]);
 if(g.level!==v.level)issues.push([q,"guide/current quest level",g.level,v.level]);
 if(g.area!==(v.zoneAreaId??0))issues.push([q,"guide/current area",g.area,v.zoneAreaId]);
 if(g.race!==(v.raceMask??"ffffffffffffffff").toLowerCase())issues.push([q,"guide/current race mask"]);
 if(!Number.isSafeInteger(v.classMask??0)||g.class!==BigInt(v.classMask??0))issues.push([q,"guide/current class mask"]);
 const items=pairs((v.objectives??[]).filter(r=>r.type==="item"&&r.amount>0&&r.objectId>0).map(r=>[r.objectId,r.amount]));
 if(!same(g.items,items))issues.push([q,"guide/current item counts",g.items,items]);
 auditedItems+=items.length;
}
const stats={guide:guide.size,packItemPairs,factRows:facts.size,internalGuide,currentIdentitiesAudited:audited,currentItemPairsAudited:auditedItems,
  sourceOnly,sourceInternal,sourceOnlyNonplaceholderUnverified:sourceOnly-sourceInternal,issues:issues.length};
console.log(JSON.stringify(stats));
for(const i of issues)console.log(JSON.stringify(i));
if(audited<3300||issues.length)process.exitCode=1;
