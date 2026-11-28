"use strict";
const fs=require("node:fs"),crypto=require("node:crypto"),path=require("node:path");
const [questFile,spotFile,addon="NQT"]=process.argv.slice(2);
function load(f,hash,tag){
 const b=fs.readFileSync(f,'utf8').replace(/\r\n/g,'\n');
 if(crypto.createHash("sha256").update(b).digest("hex")!==hash)throw Error("Unexpected pinned "+tag+" export");
 const d=JSON.parse(b);
 if(d.meta?.clientBuild!=="1.60.1.71139"||d.meta?.product!=="wowf"||d.meta?.license!=="CC BY 4.0"||d.meta?.dataset!==tag)throw Error("Unexpected "+tag+" metadata");
 return d;
}
const byQuest=load(questFile,"f9ae9af83c72285e024a83943cf365f1751545c8dce047d1359d30c295b4a621","quests").quests;
const observations=load(spotFile,"2fd6ea43823d3430d6988753a9be6559af47794d119d8b07c4bb2d8056491ab1","objectives").quests;
const baseline=fs.readFileSync(path.join(addon,"LevelGuideData.lua"),"utf8");
const catalog=new Map([...baseline.matchAll(/^\s*\[(\d+)\]=\{\d+,-?\d+,-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},/gm)].map(m=>[+m[1],[JSON.parse(m[2]),[...m[3].matchAll(/\{(\d+),(-?\d+),(\d+)\}/g)].map(n=>n.slice(1).map(Number))]]));
const dbPath=path.join(addon,"NQTDB.lua"),raw=fs.readFileSync(dbPath,"utf8");
const begin="-- BEGIN NQTDB exact duplicate approaches (generated)",end="-- END NQTDB exact duplicate approaches";
const data=raw.replace(/\r\n/g,'\n').replace(/-- BEGIN NQTDB exact duplicate approaches \(generated\)\n[\s\S]*?-- END NQTDB exact duplicate approaches\n/,"");
const known=new Map();
for(const match of data.split("db.ObjectiveSpots={")[1]?.split("\n}",1)[0].matchAll(/^ *\[(\d+)\]=\{(.*)/gm)??[])known.set(+match[1],new Set([...match[2].matchAll(/\[(\d+)\]=/g)].map(x=>+x[1])));
const typ={monster:1,item:2,object:3};
const id=v=>Number.isSafeInteger(v)&&v>0;
const good=p=>[0,1,2991].includes(p.instance)&&Number.isInteger(p.uiMap)&&p.uiMap>=1400&&p.uiMap<10000&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1;
const rows=[begin,"-- Observed player approach positions in the same Efficient Games Forever client build, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf/1.60.1.71139",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Exact typed/numbered raw objective corroborates each distinct creature/item; no exact spawn implied.",
 "db.ExactDuplicateApproaches={"];
let qCount=0,total=0,pts=0;
for(const [qs,rs] of Object.entries(observations)){
 const q=+qs,r=byQuest[q],c=catalog.get(q),packed=[];
 if(!r||!c||r.title!==c[0])continue;
 for(const [is,v] of Object.entries(rs)){
  const i=+is,a=r.objectives?.[i-1],e=c[1][i-1];
  if(known.get(q)?.has(i)||!a||!e||!id(a.objectId)||!id(a.id)||a.storageIndex!==i-1||
    !typ[a.type]||a.type!==v.type||a.amount!==v.required||v.gains<2||
    e[0]!==typ[a.type]||e[1]!==a.objectId||e[2]!==a.amount)continue;
  const siblings=r.objectives.filter(o=>o.type===a.type&&o.amount===a.amount);
  if(siblings.length<2||new Set(siblings.map(o=>o.objectId)).size!==siblings.length||
     siblings.some(o=>!Number.isInteger(o.storageIndex)||r.objectives[o.storageIndex]!==o))continue;
  const p=[...new Map((v.positions??[]).filter(good).map(p=>[p.uiMap+":"+p.mapX+":"+p.mapY,[p.uiMap,p.mapX,p.mapY]])).values()];
  if(p.length<2||new Set(p.map(x=>x[0])).size!==1)continue;
  packed.push("["+i+"]={"+[JSON.stringify(a.type),a.objectId,a.amount,"{"+p.map(x=>"{"+x.join(",")+"}").join(",")+"}"].join(",")+"}");total++;pts+=p.length;
 }
 if(packed.length){rows.push(" ["+q+"]={"+packed.join(",")+"},");qCount++;}
}
rows.push("}",end,"");
if(total<12)throw Error("Expected qualifying same-build objectives");
const result=data+rows.join("\n");
fs.writeFileSync(dbPath,raw.includes("\r\n")?result.replace(/\n/g,"\r\n"):result);
console.log(JSON.stringify({quests:qCount,objectives:total,positions:pts}));
