"use strict";
const fs=require("node:fs"),crypto=require("node:crypto"),path=require("node:path");
const [dir,nqt="NQT"]=process.argv.slice(2);
const read=(f,k)=>{const raw=fs.readFileSync(path.join(dir,f)),d=JSON.parse(raw);
 if(d.meta?.dataset!==k||d.meta.clientBuild!==f.split("-")[0]||d.meta.product!=="wowf"||d.meta.license!=="CC BY 4.0")
   throw Error("Unrecognized licensed source "+f);
 return [d,crypto.createHash("sha256").update(raw).digest("hex")];
};
const [qdata,sha]=read("1.60.1.71139-quests.json","quests");
if(qdata.meta.locale!=="enUS"||sha!=="f9ae9af83c72285e024a83943cf365f1751545c8dce047d1359d30c295b4a621")throw Error("Wrong pinned quest cache");
const pins=fs.readFileSync(path.join(nqt,"ForeverTownPins.lua"),"utf8").split("AT.ObservedQuestTurnIns={")[1].split("\n}",1)[0];
const missing=new Map();
for(const m of pins.matchAll(/^ \[(\d+)\]=\{\n([^\r\n]+)\r?\n \},/gm)){
 const a=m[2].match(/^\s*\{(\d+),([\d.]+),([\d.]+),1,(\d+),(\d+),""\},$/);
 if(a)missing.set(+m[1],a.slice(1).map(Number));
}
const dmap=new Map(),hashes={};
const publicName=v=>typeof v==="string"&&v.length>0&&v.length<=100&&/^[\x20-\x7e]+$/.test(v)&&!/[;|<>\[\]]/.test(v);
for(const f of fs.readdirSync(dir).filter(f=>/^1\.60\.1\.\d+-npcs\.json$/.test(f)).sort()){
 const [d,h]=read(f,"npcs");hashes[f]=h;
 for(const [npc,row] of Object.entries(d.npcs??{}))for(const [id,event] of Object.entries(row.takes??{})){
  const q=+id,m=missing.get(q);if(!m||qdata.quests[q]?.title!==event.title)continue;
  const [map,x,y,entity,faction]=m;
  const info=dmap.get(q)??{evidence:[],conflict:false};
  dmap.set(q,info);
  if(+npc!==entity){info.conflict=true;continue;}
  if(!publicName(row.name))continue;
  if(faction===1&&row.side==="Horde"||faction===2&&row.side==="Alliance")continue;
  const near=(row.positions??[]).find(p=>[0,1,2991].includes(p.instance)&&p.uiMap===map&&Math.hypot(p.mapX-x,p.mapY-y)<.008);
  if(near)info.evidence.push({q,entity,name:row.name,map,x:near.mapX,y:near.mapY,build:d.meta.clientBuild});
 }
}
const entries=[...dmap.values()].filter(v=>!v.conflict&&v.evidence.length&&new Set(v.evidence.map(x=>x.name)).size===1).map(v=>v.evidence).sort((a,b)=>a[0].q-b[0].q);
if(entries.length<18||Object.keys(hashes).length!==17)throw Error("Unexpected witnesses / incomplete corpus");
const dest=path.join(nqt,"NQTDB.lua");
const base=fs.readFileSync(dest,"utf8").replace(/-- BEGIN NQTDB named observed hand-ins \(generated\)\n[\s\S]*?-- END NQTDB named observed hand-ins\n/,"");
const lines=["-- BEGIN NQTDB named observed hand-ins (generated)",
 "-- Efficient Games Forever quest-giver takes observations, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Add only the exact name of the existing observed finisher; do not change coordinates or faction.",
 "db.ObservedTurnInNames={"];
for(const [a] of entries)lines.push(" ["+a.q+"]={"+a.entity+","+JSON.stringify(a.name)+"},");
lines.push("}","-- END NQTDB named observed hand-ins","");
fs.writeFileSync(dest,base+lines.join("\n"));
console.log(JSON.stringify({sourceHashes:hashes,verified:entries.length,evidence:entries}));
