"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const [file,addon]=process.argv.slice(2);
const raw=fs.readFileSync(file);
if(crypto.createHash("sha256").update(raw).digest("hex")!=="8048fa65bb8ac0ec088b47a6fcd2ee000df05664535ab32a49a52dd80ca6994b")throw Error("Unpinned build 71139");
const d=JSON.parse(raw);
if(d.meta?.dataset!=="quests"||d.meta?.product!=="wowf"||d.meta?.license!=="CC BY 4.0"||d.meta?.locale!=="enUS"||d.meta?.clientBuild!=="1.60.1.71139")throw Error("Invalid source metadata");
const read=f=>fs.readFileSync(path.join(addon,f),"utf8").replace(/\r\n/g,"\n");
const existing=new Set([...read("LevelGuideData.lua").matchAll(/^\s*\[(\d+)\]=/gm)].map(r=>+r[1]));
const valid=v=>Number.isSafeInteger(v)&&v>0;
const safe=(v,min,max)=>Number.isSafeInteger(v)&&v>=min&&v<=max;
function pairs(rs,id,k){
 if(!rs)return;
 if(!rs.length||!rs.every(r=>valid(r[id])&&valid(r[k])))throw Error("Invalid reward records");
 return rs.map(r=>[r[id],r[k]]);
}
const lua=v=>Array.isArray(v)?"{"+v.map(lua).join(",")+"}":typeof v==="string"?JSON.stringify(v):String(v);
const start="-- BEGIN NQTDB native-only quest details (generated)",end="-- END NQTDB native-only quest details";
const out=[start,"-- Efficient Games World of Warcraft: Forever build 71139, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/blob/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf/1.60.1.71139/quests.enUS.json",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- These IDs are native-only: no quest-giver, availability or automatic route asserted.",
 "db.NativeQuestDetails={"];const facts=[],rewards=[];let itemPairs=0;
for(const id of [8951,9008,9012,9205,84196]){
 const r=d.quests[id];
 if(!r||existing.has(id)||!safe(r.level,1,60)||!safe(r.minLevel,1,r.level)||!valid(r.zoneAreaId)||
  !valid(r.sources)||!/^[a-z]/i.test(r.title)||!/[a-f0-9]{16}$/i.test(r.raceMask)||
  !Array.isArray(r.objectives)||!r.objectives.every(o=>o.type==="item"&&valid(o.objectId)&&valid(o.amount)))throw Error("Invalid exact native quest "+id);
 const pack=r.rewards, obj=r.objectives.map(o=>[o.objectId,o.amount]), mask=r.classMask??0;
 if(!safe(mask,0,Number.MAX_SAFE_INTEGER)||!safe(pack.xpDifficulty,0,10)||!safe(pack.xpMultiplier,0,10))throw Error("Unusable metadata "+id);
 out.push(" ["+id+"]="+lua([r.minLevel,r.level,r.zoneAreaId,r.questInfoId??0,r.raceMask,pack.xpDifficulty,pack.xpMultiplier,mask,r.title,obj.map(r=>[2,...r])])+",");
 facts.push(" ["+id+"]="+lua([r.minLevel,r.level,...obj])+",");itemPairs+=obj.length;
 const fields={2:pairs(pack.items,"itemId","count"),3:pairs(pack.choices,"itemId","count"),5:pairs(pack.reputation,"factionId","tier")};
 rewards.push(" ["+id+"]={"+Object.entries(fields).filter(([k,v])=>v).map(([k,v])=>"["+k+"]="+lua(v)).join(",")+"},");
}
out.push("}","db.NativeQuestItemFacts={",...facts,"}","db.NativeQuestRewards={",...rewards,"}",end,"");
const data=read("NQTDB.lua").replace(new RegExp(start.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+end+"\n"),"");
fs.writeFileSync(path.join(addon,"NQTDB.lua"),data+out.join("\n"));
console.log(JSON.stringify({nativeQuestIDs:facts.length,itemPairs}));
