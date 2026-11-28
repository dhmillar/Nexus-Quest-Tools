"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const [input,addon]=process.argv.slice(2);
const src=path.join(addon,"EverlootDrops.lua"),original=fs.readFileSync(src,"utf8");
const normalize=s=>s.replace(/\r\n/g,"\n");
const facts=fs.readFileSync(path.join(addon,"ForeverQuestFacts.lua"),"utf8").split("AT.ForeverQuestFacts={")[1].split(/\r?\n}/)[0];
const objectivePairs=new Map(),want=new Set();
for(const row of facts.matchAll(/^\s*\[(\d+)\]=\{\d+,\d+((?:,\{\d+,\d+\})*)\},\s*$/gm)){
 const items=[...row[2].matchAll(/\{(\d+),\d+\}/g)].map(x=>+x[1]);
 for(const item of new Set(items)){
  want.add(item);const q=objectivePairs.get(item)??[];q.push(+row[1]);objectivePairs.set(item,q);
 }
}
if(want.size<2000)throw Error("Expected known Forever objective item catalog.");
const d=normalize(original).match(/^(.*?\n)  dates=\{([^\n]+)\},\n  items=\{\n([\s\S]*?)\n  \},?\n\}\s*$/s);
if(!d)throw Error("Unknown Everloot drop package layout");
const dates=JSON.parse("["+d[2]+"]");
const old=new Map(),sameKeys=new Set(),beforeItems=new Set(),npcBefore=new Set();
for(const line of d[3].split("\n")){
 const m=line.match(/^\s*\[(\d+)\]=\{(.*)\},$/);
 if(!m)throw Error("Invalid row "+line);
 const item=+m[1];
 beforeItems.add(item);
 for(const pair of m[2].matchAll(/\{(\d+),(\d+),(\d+),(\d+),(\d+),(0|1)\}/g)){
  const a=pair.slice(1).map(Number);
  const key=[item,a[5],a[0]].join(":");
  if(old.has(key))throw Error("Duplicate existing loot pair.");
  old.set(key,{item,a});sameKeys.add(key);
  if(a[5]===0)npcBefore.add(item);
 }
}
if(old.size<1600)throw Error("Expected published baseline.");
const files=fs.readdirSync(input).filter(n=>/^\d+\.json$/.test(n)).sort((a,b)=>parseInt(a)-parseInt(b));
let when,total,totalPage,rowsRead=0,zeros=0,nextOffset=0,sha=crypto.createHash("sha256"),qualified=0,added=0,updated=0;
const seen=new Set(),newItems=new Set(),newSources=new Set(),ret=new Map(old);
const integer=(v,min=1)=>Number.isSafeInteger(v)&&v>=min;
for(const file of files){
 const text=fs.readFileSync(path.join(input,file));sha.update(text);
 const page=JSON.parse(text);
 if(page.unreachable||page.offset!==nextOffset||parseInt(file)!==nextOffset||
    page.attribution?.licence!=="CC BY-SA 4.0"||page.attribution.credit!=="Data from Everloot (https://everloot.app), CC BY-SA 4.0."||
    !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(page.dataAsOf))throw Error("Invalid public snapshot "+file);
 when??=page.dataAsOf;total??=page.totalRates;totalPage??=page.total;
 if(page.dataAsOf!==when||page.totalRates!==total||page.total!==totalPage||page.limit!==500)throw Error("Mixed snapshots.");
 const display=when.slice(0,16).replace("T"," ")+" UTC";
 if(!dates.includes(display))dates.push(display);
 const at=dates.indexOf(display)+1;
 rowsRead+=page.rates.length;zeros+=page.measuredZeros.length;nextOffset+=page.limit;
 for(const r of page.rates){
  const item=r.itemId,object=r.sourceObjectId,entity=r.sourceNpcId??object;
  if(!integer(item)||!integer(entity)||Boolean(r.sourceNpcId)===Boolean(object))throw Error("Malformed source");
  const key=[item,object?1:0,entity].join(":");
  if(seen.has(key))throw Error("Repeated snapshot row "+key);
  seen.add(key);
  if(!want.has(item)||r.public!==true||r.tier!=="confirmed")continue;
  const n=r.lootWindows??r.kills,k=r.windowsWithItem??r.drops,installs=r.installs??r.reporters;
  if(!integer(n,12)||!integer(k,2)||!integer(installs,3)||k>n||installs>n)continue;
  if(typeof r.rate==="number"&&Math.abs(k/n-r.rate)>.000001)throw Error("Inconsistent loot window rate "+key);
  qualified++;
  const prior=old.get(key)?.a;
  if(prior&&(prior[2]>n||prior[3]>installs))continue;
  const a=[entity,k,n,installs,at,object?1:0];
  if(prior&&prior[1]===k&&prior[2]===n&&prior[3]===installs)continue;
  if(!prior){added++;if(!object&&!npcBefore.has(item))newSources.add(item);}
  else updated++;
  if(!beforeItems.has(item))newItems.add(item);
  ret.set(key,{item,a});
 }
 const next=page.next;
 if(next&&next!=="https://everloot.app/api/rollups/drops?limit=500&offset="+nextOffset)throw Error("Unexpected next link");
 if(Boolean(next)!==(nextOffset<totalPage))throw Error("Truncated or inconsistent snapshot.");
}
if(rowsRead!==total||rowsRead+zeros!==totalPage||total<1000||qualified<100)throw Error("Incomplete or changed format.");
const grouped=new Map();
for(const {item,a} of ret.values()){
 const list=grouped.get(item)??[];list.push(a);grouped.set(item,list);
}
const dataSha=sha.digest("hex");
const out=[...grouped].sort((a,b)=>a[0]-b[0]).map(([item,aa])=>
 "    ["+item+"]={"+aa.sort((a,b)=>a[5]-b[5]||a[0]-b[0]).map(a=>"{"+a.join(",")+"}").join(",")+"},");
const heading=d[1].replace(/^-- Focused snapshot .+\n/mg,"");
const provenance="-- Focused snapshot "+when+"; exact Forever objective item IDs, at least 12 loot windows and 3 installs. SHA-256 of concatenated JSON pages: "+dataSha+"\n";
fs.writeFileSync(src,heading.replace("local _,AT=...\n",provenance+"local _,AT=...\n")+"  dates={"+dates.map(x=>JSON.stringify(x)).join(", ")+"},\n  items={\n"+out.join("\n")+"\n  },\n}\n");
const affected=items=>[...items].reduce((total,item)=>total+objectivePairs.get(item).length,0);
console.log(JSON.stringify({when,rowsRead,qualified,added,updated,newItems:[...newItems].sort((a,b)=>a-b),newItemObjectives:affected(newItems),
 newNpcSourceItems:[...newSources].sort((a,b)=>a-b),newNpcSourceObjectives:affected(newSources),oldSources:sameKeys.size,storedSources:ret.size,dataSha}));
