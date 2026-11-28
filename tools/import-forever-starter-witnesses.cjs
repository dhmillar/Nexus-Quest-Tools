// Generate the independently packaged Classic reference table from pinned upstream SQL.
// The generated numeric table is provided under that source's GPL-3.0 terms.
// Does not copy names, quest prose, SQL comments, or third-party addon tables.
"use strict";
const fs=require("fs"), zlib=require("zlib"), crypto=require("crypto");
const [sqlPath,questPath,lootDir,out,auditPath]=process.argv.slice(2);
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
const source=f=>fs.readFileSync(path.join(out,f),"utf8");
const readBlock=(s,k)=>(s.split(k+"={")[1]??"").split(/\r?\n}/,1)[0];
const tableIds=(s,k)=>[...readBlock(s,k).matchAll(/^\s*\[(\d+)\]=/gm)].map(m=>+m[1]);
const noGuess=n=>Number.isSafeInteger(n)&&n>0;
const guide=source("LevelGuideGivers.lua"),db=source("NQTDB.lua");
const legacyStarts=new Map();
rows("item_template",(v,c)=>{
 const q=+v[c.findIndex(x=>x.toLowerCase()==="startquest")];
 if(q>0)legacyStarts.set(+v[0],q);
});
const starts=new Map([...readBlock(guide,"AT.LevelGuideItemStarts").matchAll(/^\s*\[(\d+)\]=\{(\d+),(\{.*)$/gm)]
 .map(m=>[+m[1],{item:+m[2],rows:m[3],mapped:[...m[3].matchAll(/\{(\d+),([.\d]+),([.\d]+),/g)]
  .some(x=>+x[1]>0&&+x[2]>0&&+x[2]<1&&+x[3]>0&&+x[3]<1)}]));
const namedGiver=new Set([...tableIds(guide,"AT.LevelGuideQuestGivers"),...tableIds(guide,"AT.LevelGuideMoreOffers"),
 ...tableIds(db,"db.Starts"),...tableIds(db,"db.ClassicStarts"),
 ...[...readBlock(source("ForeverTownPins.lua"),"AT.ObservedQuestStarts").matchAll(/^\s*\{(\d+),/gm)].map(m=>+m[1])]);
const catalog=new Map([...source("LevelGuideData.lua").matchAll(/^\s*\[(\d+)\]=\{\d+,(-?\d+),(-?\d+),\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{/gm)]
 .map(m=>[+m[1],{name:JSON.parse(m[4]),level:+m[2],area:+m[3]}]));
if(catalog.size<5000||starts.size<1200)throw Error("Expected current Forever baseline");
const live=JSON.parse(fs.readFileSync(questPath,"utf8"));
if(live.meta?.dataset!=="quests"||live.meta?.license!=="CC BY 4.0"||live.meta.product!=="wowf"||live.meta.locale!=="enUS")throw Error("Invalid quest source.");
const witnesses=new Map(),namedCreatures=new Map();
for(const line of source("QuestMobData.lua").split(/\r?\n/)){
 const m=line.match(/^\s*(?:AT\.QuestMobData\.creatures)?\[(\d+)\]=\{("(?:\\.|[^"\\])*"),\d+,\d+,"[^"]*"(?:,\d+)?\}/);
 if(m)namedCreatures.set(+m[1],JSON.parse(m[2]));
}
const lootFiles=fs.readdirSync(lootDir).filter(f=>/^1\.60\.1\.\d+-loot\.json$/.test(f)).sort();
if(lootFiles.length<12)throw Error("Incomplete loot input.");
for(const file of lootFiles){
 const d=JSON.parse(fs.readFileSync(path.join(lootDir,file),"utf8"));
 if(d.format!==3||d.meta?.dataset!=="loot"||d.meta?.license!=="CC BY 4.0"||d.meta.product!=="wowf"||file.split("-")[0]!==d.meta.clientBuild)
   throw Error("Invalid drop evidence "+file);
 for(const [key,r] of Object.entries(d.sources??{})){
  const x=key.match(/^(npc|object):(\d+)(\|quest)?(\|group)?$/);
  if(!x||!noGuess(r.windows))continue;
  for(const [sid,v] of Object.entries(r.items??{})){
   const i=+sid,q=v.quest;
   if(!noGuess(q)||!noGuess(v.drops)||v.drops>r.windows||(v.shared??0)!==0||starts.get(q)?.item!==i)continue;
   const e=x[1]+":"+x[2],prev=witnesses.get(q)??new Map(), prior=prev.get(e);
   const points=(r.positions??[]).filter(p=>[0,1,2991].includes(p.instance)&&p.uiMap>=1400&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1);
   prev.set(e,{k:x[1],id:+x[2],build:d.meta.clientBuild,points:[...(prior?.points??[]),...points]});
   witnesses.set(q,prev);
  }
 }
}
const maps=new Map(),neededMobs=new Set();
const audited=new Map();
for(const [q,r] of starts){
 const c=catalog.get(q),current=live.quests[q],classic=legacyStarts.get(r.item)===q;
 const liveFlag=current?.startItemId===r.item&&current?.title===c?.name&&current?.level===c?.level;
 if(!c)continue;
 const where=witnesses.get(q);
 const kind=where?.size===1?[...where.values()][0]:null;
 if(kind?.k==="npc" && !r.mapped && !namedGiver.has(q) && classic && liveFlag)neededMobs.add(kind.id);
 audited.set(q,{r,c,classic,liveFlag,where,kind});
}
rows("creature",(v,c)=>{
 const e=+v[c.indexOf("id")];if(!neededMobs.has(e))return;
 const map=+v[c.indexOf("map")];
 const list=maps.get(e)??new Set();list.add(map);maps.set(e,list);
});
const spec=new Map([[2057,{id:289,name:"Scholomance"}]]); // Verified instance pair; no outdoor substitute.
const outRows=[];
const counts={};
let audit=["quest_id\titem_id\tstate\tpublic_cache_flag\tclassic_starter_match\tnamed_source\tdocumented_instance"];
for(const [q,x] of audited){
 const {r,c,classic,liveFlag,kind,where}=x;
 const single=kind?.k==="npc"&&namedCreatures.get(kind.id);
 const instance=spec.get(c.area);
 const inDungeon=instance&&maps.get(kind?.id)?.size===1&&maps.get(kind?.id).has(instance.id);
 let state;
 if(r.mapped)state="mapped_pickup";
 else if(namedGiver.has(q))state="named_giver_takes_priority";
 else if(!r.rows.startsWith("{}"))state="bundled_source_without_pin";
 else if(!liveFlag||!classic)state="starter_identity_not_verified";
 else if(where?.size>1)state="ambiguous_pickup_source";
 else if(kind&&kind.points.length)state="pickup_observed_with_coordinates_needs_review";
 else if(single&&inDungeon){
   state="verified_instance_pickup_no_map_pin";
   outRows.push({q,item:r.item,id:kind.id,name:single,instance,build:kind.build});
 }else if(kind)state="observed_pickup_no_map_pin";
 else state="verified_starter_missing_pickup_witness";
 counts[state]=(counts[state]??0)+1;
 audit.push([q,r.item,state,liveFlag?1:0,classic?1:0,single||"",inDungeon?instance.name:""].join("\t"));
}
// Show newly seen cache hints in the audit even when the package does not
// use them. A static cache field alone is not proof that clicking starts a quest.
for(const [q,r] of Object.entries(live.quests??{})){
 if(starts.has(+q)||!catalog.has(+q)||!noGuess(r.startItemId))continue;
 const state=namedGiver.has(+q)?"named_giver_takes_priority":"cache_only_unverified";
 counts[state]=(counts[state]??0)+1;
 audit.push([q,r.startItemId,state,1,legacyStarts.get(r.startItemId)===+q?1:0,"",""].join("\t"));
}
if(!outRows.length)throw Error("No named independently corroborated starter witnesses.");
const L=["-- BEGIN NQTDB unmappable starter witnesses (generated)",
 "-- Quest-linked loot witnesses and Forever creature identities from Efficient Games, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Numeric starter and instance comparisons: pinned CMaNGOS Classic-DB, GPL-3.0-only.",
 "-- https://github.com/cmangos/classic-db/tree/04bc47631b680b99cdfeee88488dafb5e871c207",
 "-- SQL SHA-256 "+digest+"; notices in ClassicDB.COPYRIGHT.md and ClassicDB.LICENSE.md.",
 "-- A witnessed pickup without a confirmed location is never a route point or a probability.",
 "db.ItemStarterWitnesses={"];
for(const r of outRows.sort((a,b)=>a.q-b.q))L.push(" ["+r.q+"]={"+[r.item,1,r.id,JSON.stringify(r.name),JSON.stringify(r.instance.name),r.instance.id].join(",")+"}, -- "+r.build);
L.push("}","-- END NQTDB unmappable starter witnesses","");
const dest=path.join(out,"NQTDB.lua"),old=db.replace(/\r\n/g,"\n").replace(/-- BEGIN NQTDB unmappable starter witnesses \(generated\)\n[\s\S]*?-- END NQTDB unmappable starter witnesses\n/,"");
fs.writeFileSync(dest,old+L.join("\n"));
if(auditPath)fs.writeFileSync(auditPath,audit.join("\n")+"\n");
console.log(JSON.stringify({catalog:catalog.size,baselineStarterRows:starts.size,markerLinked:witnesses.size,lootFiles:lootFiles.length,counts,newNamedWitnesses:outRows.map(x=>x.q)}));
