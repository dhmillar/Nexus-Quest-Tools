// Generate the independently packaged Classic reference table from pinned upstream SQL.
// The generated numeric table is provided under that source's GPL-3.0 terms.
// Does not copy names, quest prose, SQL comments, or third-party addon tables.
"use strict";
const fs=require("fs"), zlib=require("zlib"), crypto=require("crypto");
const [sqlPath,npcs,out]=process.argv.slice(2);
const gz=fs.readFileSync(sqlPath);
const digest=crypto.createHash("sha256").update(gz).digest("hex");
if(digest!=="4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0")throw Error("wrong Classic-DB SQL revision");
const sql=zlib.gunzipSync(gz).toString("utf8");
const field=String.raw`(?:'(?:[^'\\]|\\[\s\S]|'')*'|[^,();]+)`;
const row=new RegExp("\\(("+field+"(?:,"+field+")*)\\)(?:,|;)","g");
const token=new RegExp(field,"g");
function rows(table,fn){
 const create=sql.indexOf("CREATE TABLE "+String.fromCharCode(96)+table+String.fromCharCode(96));
 if(create<0)throw Error("missing schema for "+table);
 const cols=[...sql.slice(create,sql.indexOf("\n)",create)).matchAll(/^\s*`([^`]+)`\s/mg)].map(x=>x[1]);
 const key="INSERT INTO "+String.fromCharCode(96)+table+String.fromCharCode(96)+" VALUES ";
 let i=sql.indexOf(key,create),count=0;
 while(i>=0 && i<sql.indexOf("\nUNLOCK TABLES",create)){
  row.lastIndex=i+key.length;
  while(true){
   const next=row.lastIndex,m=row.exec(sql);
   if(!m||m.index!==next)throw Error("unexpected SQL row "+table+" at "+next);
   const fields=m[1].match(token);
   if(fields.length!==cols.length)throw Error("columns changed "+table+" "+fields.length+" vs "+cols.length);
   fn(fields,cols); count++;
   if(m[0].endsWith(";"))break;
  }
  i=sql.indexOf(key,row.lastIndex);
 }
 if(!count)throw Error("no source rows for "+table);
}
const path=require("node:path");
// Classic relation provenance is independent of any private comparison database.
const source=f=>fs.readFileSync(path.join(out,f),"utf8");
const section=(s,key)=>(s.split(key,2)[1]??"").split(/\r?\n}/,1)[0];
const listed=(s,ks)=>new Set(ks.flatMap(k=>[...section(s,k+"={").matchAll(/^\s*\[(\d+)\]=/gm)].map(m=>+m[1])));
const guide=source("LevelGuideGivers.lua"),db=source("NQTDB.lua");
const oldStart=new Set([...listed(guide,["AT.LevelGuideQuestGivers","AT.LevelGuideMoreOffers"]),...listed(db,["db.Starts"])]);
const recordedStarts=new Set([...section(source("ForeverTownPins.lua"),"AT.ObservedQuestStarts={")
 .matchAll(/^\s*\{(\d+),/gm)].map(m=>+m[1]));
// Audit exclusions: these legacy relations are conflicting, ambiguous or
// have changed since Classic. Do not name a historical NPC as their starter.
const reviewedAmbiguous=new Set([26,566,940,1823,1883,1959,5634,5637,5643,5656,5658,5663,5672,5928,6066,6068,6722,8229]);
const itemStarts=new Set([...section(guide,"AT.LevelGuideItemStarts={").matchAll(/^\s*\[(\d+)\]=\{\d+,\{\{/gm)].map(m=>+m[1]));
const catalog=new Map([...source("LevelGuideData.lua").matchAll(/^\s*\[(\d+)\]=\{\d+,(-?\d+),-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{/gm)]
 .map(m=>[+m[1],{name:JSON.parse(m[3]),level:+m[2]}]));
function str(s){return s[0]==="'" ? s.slice(1,-1).replace(/''/g,"'").replace(/\\(.)/g,"$1"):s;}
const classical=new Set(),names=[null,new Map(),new Map()];
rows("quest_template",(v,c)=>{const q=+v[0],r=catalog.get(q);if(r&&r.name===str(v[c.indexOf("Title")])&&r.level===+v[c.indexOf("QuestLevel")])classical.add(q);});
for(const [kind,table] of [[1,"creature_template"],[2,"gameobject_template"]]){
 rows(table,(v,c)=>{const i=c.findIndex(x=>x.toLowerCase()==="name");if(i<0)throw Error("Name");names[kind].set(+v[0],str(v[i]));});
}
const pos=[null,new Map(),new Map()], sides={Alliance:1,Horde:2,Neutral:0};
const coordinates=row=>row.positions?.filter(p=>[0,1,2991].includes(p.instance)&&p.uiMap>=1400&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1)??[];
for(const f of fs.readdirSync(npcs).filter(f=>f.endsWith("-npcs.json")).sort((a,b)=>+a.split(".")[3].split("-")[0]- +b.split(".")[3].split("-")[0])){
 const d=JSON.parse(fs.readFileSync(path.join(npcs,f),"utf8"));
 if(d.meta?.license!=="CC BY 4.0"||d.meta?.dataset!=="npcs"||d.meta?.clientBuild!==f.split("-npcs")[0])throw Error(f);
 for(const [kind,entries] of [[1,d.npcs],[2,d.objects]]) for(const [key,row] of Object.entries(entries??{})){
  if(names[kind].get(+key)!==row.name||!row.name||row.name.length>90||/[\x00-\x1f;|\[\]]/.test(row.name))continue;
  const pp=coordinates(row),side=sides[row.side];
  if(!pp.length)continue;
  const rec=pos[kind].get(+key)??{side:null,points:[],builds:new Set()};
  if(side!==undefined){if(rec.side===null)rec.side=side;else if(rec.side!==side)rec.side=false;}
  for(const p of pp)rec.points.push([p.uiMap,+p.mapX.toFixed(4),+p.mapY.toFixed(4)]);
  rec.builds.add(d.meta.clientBuild);
  pos[kind].set(+key,rec);
 }
}
const starts=[];
const oldStartsRelations=new Map();
for(const [kind,table] of [[1,"creature_questrelation"],[2,"gameobject_questrelation"]]){
 rows(table,v=>{
  const [e,q]=v.map(Number),map=oldStartsRelations;
  (map.get(q)??map.set(q,[]).get(q)).push([kind,e]);
 });
}
function qualify(q,parts,output){
 if(parts.length!==1)return;
 const [kind,e]=parts[0],r=pos[kind].get(e);
 if(!r||r.points.length<1||r.side===false||(kind===1&&r.side===null))return;
 const p=r.points.at(-1);
 if(r.points.some(x=>x[0]!==p[0]||Math.hypot(x[1]-p[1],x[2]-p[2])>.016))return;
 output.push({q,kind,e,p,side:r.side??0,name:names[kind].get(e),builds:r.builds.size});
}
for(const q of classical){
 if(!oldStart.has(q)&&!recordedStarts.has(q)&&!itemStarts.has(q)&&!reviewedAmbiguous.has(q)
  &&oldStartsRelations.has(q))qualify(q,oldStartsRelations.get(q),starts);
}
if(starts.length<250)throw Error("Unexpectedly small start coverage: "+starts.length);
const notice=[
 "-- BEGIN NQTDB classic start references (generated)",
 "-- Classic quest-source relationships adapted from CMaNGOS Classic-DB, GPL-3.0-only.",
 "-- https://github.com/cmangos/classic-db/tree/04bc47631b680b99cdfeee88488dafb5e871c207",
 "-- Source SQL SHA-256: "+digest+"; see ClassicDB.LICENSE.md and ClassicDB.COPYRIGHT.md.",
 "-- Forever entity names and locations from Efficient Games, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Location corroborates the NPC/object, not a live offer. Never overrides native data.",
 "db.ClassicStarts={"
];
for(const {q,kind,e,p,side,name} of starts.sort((a,b)=>a.q-b.q)){
 notice.push(" ["+q+"]={{"+p.join(",")+","+[side,e,JSON.stringify(name),kind===2?1:0].join(",")+"}},");
}
notice.push("}","-- END NQTDB classic start references","");
const dest=path.join(out,"NQTDB.lua");
const original=db.replace(/\r\n/g,"\n").replace(/-- BEGIN NQTDB classic start references \(generated\)\n[\s\S]*?-- END NQTDB classic start references\n/,"");
fs.writeFileSync(dest,original+notice.join("\n"));
console.log({catalog:catalog.size,knownGivers:oldStart.size,knownMapOffers:recordedStarts.size,mappedItemStarts:itemStarts.size,classicMatches:classical.size,newStarts:starts.length});
