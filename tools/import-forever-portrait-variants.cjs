"use strict";
const fs=require("node:fs"),path=require("node:path");
const [profiles,nqt]=process.argv.slice(2);
const read=f=>fs.readFileSync(path.join(nqt,f),"utf8").replace(/\r\n/g,"\n");
const quests=read("LevelGuideData.lua"), mobs=read("QuestMobData.lua"), db=read("NQTDB.lua");
const killIDs=new Set([...quests.matchAll(/\{1,(\d+),\d+\}/g)].map(m=>+m[1]));
const prior=new Map();
for(const l of mobs.split("\n")){
 const m=l.match(/^\s*\[(\d+)\]=\{("(?:\\.|[^"\\])*"),\d+,\d+,"[^"]*"(?:,(\d+))?\},/)
   ||l.match(/^AT\.QuestMobData\.creatures\[(\d+)\]=\{("(?:\\.|[^"\\])*"),\d+,\d+,"[^"]*"(?:,(\d+))?\}/);
 if(m)prior.set(+m[1],{name:JSON.parse(m[2]),display:+m[3]||0});
 const patch=l.match(/^AT\.QuestMobData\.creatures\[(\d+)\]\[5\]=(\d+)/);
 if(patch&&prior.has(+patch[1]))prior.get(+patch[1]).display=+patch[2];
}
const records=new Map(),id=v=>Number.isSafeInteger(v)&&v>0, conflicting=new Set();
const validName=n=>typeof n==="string"&&/^[^\x00-\x1f;|\[\]]{1,100}$/.test(n)&&!/(kill.?credit|placeholder|\bdebug\b|invisible|stalker|do not use)/i.test(n);
for(const build of fs.readdirSync(profiles).sort()){
 const f=path.join(profiles,build,"creature_details.enUS.json");
 if(!fs.existsSync(f))continue;
 const r=JSON.parse(fs.readFileSync(f,"utf8"));
 if(r.meta?.dataset!=="creature_details"||r.meta.locale!=="enUS"||r.meta.product!=="wowf"||r.meta.clientBuild!==build||r.meta.license!=="CC BY 4.0")throw Error("Unexpected "+f);
 for(const [key,p] of Object.entries(r.creatures??{})){
  const k=+key, old=prior.get(k);
  if(!id(k)||old?.display||!old&&!killIDs.has(k))continue;
  if(!validName(p.name)||old?.name&&old.name!==p.name||p.type===10||!Number.isSafeInteger(p.flags?.[0])||(p.flags[0]&0x02000000)!==0){conflicting.add(k);continue;}
  const variants=(p.displays??[]).filter(v=>id(v.displayId)&&v.displayId!==11686&&v.displayId!==1126&&v.displayId!==52318&&Number.isFinite(v.probability)&&v.probability>=0&&v.scale>0);
  const all=variants.length===(p.displays??[]).length;
  if(!all||!variants.length){conflicting.add(k);continue;}
  const top=Math.max(...variants.map(x=>x.probability));
  if(variants.length>1&&top===0){conflicting.add(k);continue;}
  const choices=new Set(variants.filter(v=>v.probability===top).map(v=>v.displayId));
  const seen=records.get(k);
  if(seen){
   if(seen.name!==p.name){conflicting.add(k);continue;}
   for(const n of seen.top)if(!choices.has(n))seen.top.delete(n);
  }else records.set(k,{name:p.name,top:choices});
 }
}
const start="-- BEGIN NQTDB creature portrait variants (generated)", end="-- END NQTDB creature portrait variants";
const out=[start,"-- Exact Forever creature profiles: Efficient Games, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- A representative of the common top-weight native variants, or one explicit model.",
 "-- Never override a base model, map to different creature IDs, or use hidden credit units.",
 "db.CreaturePortraitVariants={"];
let found=0,added=0;
for(const [k,r] of [...records].sort((a,b)=>a[0]-b[0])){
 if(conflicting.has(k)||!r.top.size)continue;
 const display=Math.min(...r.top);
 out.push(" ["+k+"]={"+JSON.stringify(r.name)+","+display+"},");
 found++;if(!prior.has(k))added++;
}
if(!found)throw Error("No qualified profiles");
out.push("}",end,"");
const base=db.replace(new RegExp(start.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+end+"\n"),"");
fs.writeFileSync(path.join(nqt,"NQTDB.lua"),base+out.join("\n"));
console.log(JSON.stringify({profiles:found,newNames:added,conflicts:conflicting.size}));
