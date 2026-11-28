"use strict";
const fs=require("node:fs"),crypto=require("node:crypto");
const [dir,nqt="NQT"]=process.argv.slice(2);
const base=dir+"/1.60.1.71139-";
function read(src,hash,tag){
 const b=fs.readFileSync(base+src+".json");
 if(crypto.createHash("sha256").update(b).digest("hex")!==hash)throw Error("Unexpected "+src+" input");
 const d=JSON.parse(b);
 if(d.meta?.dataset!==tag||d.meta?.product!=="wowf"||d.meta?.clientBuild!=="1.60.1.71139"||d.meta?.license!=="CC BY 4.0")throw Error("Invalid input "+src);
 return d;
}
const quests=read("quests","f9ae9af83c72285e024a83943cf365f1751545c8dce047d1359d30c295b4a621","quests").quests;
const objects=read("object_details.enUS","5b76217601e46bfa33f06a8cf110459deb331045a892db6119bdb2fb5dc4f2a5","object_details").objects;
const files=fs.readdirSync(dir).filter(f=>/^1\.60\.1\.\d+-loot\.json$/.test(f)).sort();
if(files.length!==17)throw Error("Expected all 17 pinned loot exports");
const loots=files.map(f=>{
 const d=JSON.parse(fs.readFileSync(dir+"/"+f));
 if(d.meta?.dataset!=="loot"||d.meta.clientBuild!==f.split("-")[0]||d.meta.product!=="wowf"||d.meta.license!=="CC BY 4.0"||d.format!==3)
  throw Error("Invalid pinned "+f);
 return d;
});
const raw=fs.readFileSync(nqt+"/NQTDB.lua","utf8");
const data=raw.replace(/-- BEGIN NQTDB object template witnesses \(generated\)\n[\s\S]*?-- END NQTDB object template witnesses\n/,"");
const catalogue=fs.readFileSync(nqt+"/LevelGuideData.lua","utf8");
const catalog=new Map([...catalogue.matchAll(/^\s*\[(\d+)\]=\{\d+,-?\d+,-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},/gm)].map(m=>[+m[1],[JSON.parse(m[2]),[...m[3].matchAll(/\{(\d+),(-?\d+),(\d+)\}/g)].map(x=>x.slice(1).map(Number))]]));
const section=k=>data.split("db."+k+"={")[1]?.split("\n}",1)[0]??"";
const nested=k=>new Map([...section(k).matchAll(/^ *\[(\d+)\]=\{(.+)/gm)].map(m=>[+m[1],new Set([...m[2].matchAll(/\[(\d+)\]=/g)].map(x=>+x[1]))]));
const known=nested("NamedObjectPickups");
const id=v=>Number.isSafeInteger(v)&&v>0;
const owners=new Map();
for(const [qs,r] of Object.entries(quests))for(const [idx,o] of (r.objectives??[]).entries()){
 if(o.type==="item"&&id(o.objectId))(owners.get(o.objectId)??owners.set(o.objectId,[]).get(o.objectId)).push([+qs,r,idx,o]);
}
const names=new Map(),provenance=[];
for(const loot of loots)for(const [key,r] of Object.entries(loot.sources??{})){
 const object=+key.match(/^object:(\d+)(?:\|spell:\d+)?$/)?.[1],d=objects[object];
 if(!d||d.type!==3||typeof d.name!=="string"||/[|\x00-\x1f]/.test(d.name)||!d.name||!id(r.windows))continue;
 for(const [it,l] of Object.entries(r.items)){
  const item=+it,uses=owners.get(item);
  if(!d.questItems?.includes(item)||uses?.length!==1||l.quest!==true||!id(l.drops)||l.drops!==r.windows||(l.shared??0)!==0)continue;
  const [q,v,idx,o]=uses[0],c=catalog.get(q),p=c?.[1]?.[idx];
  if(!p||v.title!==c[0]||v.startItemId===item||o.storageIndex!==idx||!id(o.amount)||p[0]!==2||p[1]!==item||p[2]!==o.amount||known.get(q)?.has(item))continue;
  const rows=names.get(q)??names.set(q,new Map()).get(q);
  const ids=rows.get(item)??rows.set(item,new Map()).get(item);
  ids.set(object,d.name);
  provenance.push({quest:q,item,object,name:d.name,windows:r.windows,build:loot.meta.clientBuild});

 }
}
for(const [q,items] of names)for(const [item,ids] of items){
 const pairs=[...ids].sort((a,b)=>a[0]-b[0]);
 if(new Set(pairs.map(x=>x[1])).size!==1)items.delete(item);
 else items.set(item,[pairs.length===1?pairs[0][0]:0,pairs[0][1]]);
}
const lua=x=>Array.isArray(x)?"{"+x.map(lua).join(",")+"}":JSON.stringify(x);
const lines=["-- BEGIN NQTDB object template witnesses (generated)",
 "-- Efficient Games English object templates and observed Forever loot windows, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf/1.60.1.71139",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Verified object labels, never a drop rate, exact spawn or targetable NPC."];
for(const [key,rows] of [["WitnessedObjectPickups",names]]){
 lines.push("db."+key+"={");
 for(const [q,m] of [...rows].sort((a,b)=>a[0]-b[0]))lines.push(" ["+q+"]={"+[...m].map(([k,x])=>"["+k+"]="+lua(x)).join(",")+"},");
 lines.push("}");
}
if(names.size<18)throw Error("Insufficient exact source matches "+names.size);
lines.push("-- END NQTDB object template witnesses","");
fs.writeFileSync(nqt+"/NQTDB.lua",data+lines.join("\n"));
for(const p of provenance)console.log(JSON.stringify(p));
