"use strict";
const fs=require("node:fs"),path=require("node:path");
const [source,out]=process.argv.slice(2);
const file=path.join(out,"NQTDB.lua"),data=JSON.parse(fs.readFileSync(source,"utf8"));
if(data.meta?.dataset!=="quests"||data.meta.product!=="wowf"||data.meta.locale!=="enUS"||
 data.meta.license!=="CC BY 4.0"||data.meta.clientBuild!=="1.60.1.71139")throw Error("Wrong licensed client export");
const catalog=new Map(),read=n=>fs.readFileSync(path.join(out,n),"utf8");
for(const line of read("LevelGuideData.lua").split(/\r?\n/)){
 const m=line.match(/^\s*\[(\d+)\]=\{\d+,(-?\d+),-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{/);
 if(m)catalog.set(+m[1],{title:JSON.parse(m[3]),level:+m[2]});
}
if(catalog.size<5000)throw Error("Wrong Forever catalogue");
const id=n=>Number.isSafeInteger(n)&&n>0&&n<1e8;
const count=n=>Number.isSafeInteger(n)&&n>0&&n<1e7;
const integer=(n,cap)=>Number.isSafeInteger(n)&&n>=0&&n<=cap;
function list(rows,idKey,numKey,isNum){
 if(!Array.isArray(rows)||rows.length<1||rows.length>20)return;
 const ids=new Set();
 const arr=[];
 for(const r of rows){
   if(!id(r[idKey])||!isNum(r[numKey])||ids.has(r[idKey]))return;
   ids.add(r[idKey]);arr.push([r[idKey],r[numKey]]);
 }
 return arr;
}
function lua(v){return Array.isArray(v)?"{"+v.map(lua).join(",")+"}":String(v);}
const L=["-- BEGIN NQTDB reward facts (generated)",
 "-- Adapted numeric reward facts from Efficient Games (https://efficient.games), CC BY 4.0.",
 "-- https://creativecommons.org/licenses/by/4.0/",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/blob/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf/1.60.1.71139/quests.enUS.json",
 "-- Record: [1]=money copper; [2]=guaranteed item/count pairs; [3]=choice item/count pairs;",
 "-- [4]=currency/count pairs; [5]=reputation faction/tier pairs; [6]=reward spell ID;",
 "-- [7]=display spell/type pairs; [8]=XP difficulty tier; [9]=XP multiplier (not XP amount).",
 "db.Rewards={"];
const counts={matched:0,rewardRows:0,money:0,items:0,choices:0,currencies:0,reputation:0,spells:0,displaySpells:0,xpDifficulty:0};
for(const [qid,q] of Object.entries(data.quests??{})){
 const known=catalog.get(+qid);
 // Never attach the rewards of a stale or repurposed quest ID to a current quest.
 if(!known||q.title!==known.title||q.level!==known.level||!count(q.sources))continue;
 const r=q.rewards;
 counts.matched++;
 if(!r||typeof r!=="object")continue;
 const money=id(r.money)?r.money:null;
 const fields=[money,list(r.items,"itemId","count",count),list(r.choices,"itemId","count",count),
 list(r.currencies,"currencyId","amount",count),list(r.reputation,"factionId","tier",n=>integer(n,20)),
 id(r.spellId)?r.spellId:null,list(r.displaySpells,"spellId","type",n=>integer(n,50)),
 integer(r.xpDifficulty,50)?r.xpDifficulty:null,
 typeof r.xpMultiplier==="number"&&Number.isFinite(r.xpMultiplier)&&r.xpMultiplier>=0&&r.xpMultiplier<=25?r.xpMultiplier:null];
 const row=fields.flatMap((value,i)=>value!==null&&value!==undefined?["["+(i+1)+"]="+lua(value)]:[]);
 if(row.length){
  counts.rewardRows++;counts.money+=!!fields[0];counts.items+=!!fields[1];counts.choices+=!!fields[2];counts.currencies+=!!fields[3];
  counts.reputation+=!!fields[4];counts.spells+=!!fields[5];counts.displaySpells+=!!fields[6];counts.xpDifficulty+=fields[7]!==null;
  L.push(" ["+qid+"]={"+row.join(",")+"},");
 }
}
if(counts.rewardRows<2000||counts.items<300)throw Error("Incomplete exact reward data: "+JSON.stringify(counts));
L.push("}","-- END NQTDB reward facts","");
const orig=read("NQTDB.lua").replace(/\r\n/g,"\n").replace(/-- BEGIN NQTDB reward facts \(generated\)\n[\s\S]*?-- END NQTDB reward facts\n/,"");
fs.writeFileSync(file,orig+L.join("\n"));
console.log(JSON.stringify(counts));
