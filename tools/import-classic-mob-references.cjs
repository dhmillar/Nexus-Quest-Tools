// Generate the independently packaged Classic reference table from pinned upstream SQL.
// The generated numeric table is provided under that source's GPL-3.0 terms.
// Does not copy names, quest prose, SQL comments, or third-party addon tables.
"use strict";
const fs=require("fs"), zlib=require("zlib"), crypto=require("crypto");
const [sqlPath,factPath,outPath]=process.argv.slice(2);
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
const raw=fs.readFileSync(factPath,"utf8").split("AT.ForeverQuestFacts={")[1].split(/\r?\n}/)[0];
const current=new Map([...raw.matchAll(/^\s*\[(\d+)\]=\{\d+,\d+((?:,\{\d+,\d+\})*)\},\s*$/gm)].map(m=>[+m[1],new Set([...m[2].matchAll(/\{(\d+),\d+\}/g)].map(x=>+x[1]))]));
const compatible=new Map(), items=new Set();
const required=[1,2,3,4].map(i=>"ReqItemId"+i);
rows("quest_template",(v,c)=>{
 const q=+v[0], modern=current.get(q);if(!modern?.size)return;
 const matched=required.map(k=>+v[c.indexOf(k)]).filter(i=>modern.has(i));
 if(matched.length){compatible.set(q,matched);for(const i of matched) items.add(i);}
});

const [guidePath,mobPath]=process.argv.slice(5);
const guide=fs.readFileSync(guidePath,"utf8"), mobs=fs.readFileSync(mobPath,"utf8");
const modernKills=new Map();
for(const line of guide.split(/\r?\n/)){
 const m=line.match(/^\s*\[(\d+)\]=/); if(!m)continue;
 const ids=[...line.matchAll(/\{1,(\d+),\d+\}/g)].map(x=>+x[1]);
 if(ids.length)modernKills.set(+m[1],new Set(ids));
}
const publicMobs=new Map();
for(const line of mobs.split(/\r?\n/)){
 const m=line.match(/^\s*\[(\d+)\]=\{("(?:\\.|[^"\\])*"),\d+,\d+,"[^"]*"(?:,(\d+))?\},/);
 if(m)publicMobs.set(+m[1],{name:JSON.parse(m[2]),model:+m[3]||0});
 const patch=line.match(/^AT\.QuestMobData\.creatures\[(\d+)\]\[5\]=(\d+)/);
 if(patch&&publicMobs.has(+patch[1]))publicMobs.get(+patch[1]).model=+patch[2];
 const newer=line.match(/^AT\.QuestMobData\.creatures\[(\d+)\]=\{("(?:\\.|[^"\\])*"),0,0,"",(\d+)\}/);
 if(newer)publicMobs.set(+newer[1],{name:JSON.parse(newer[2]),model:+newer[3]});
}
const neededNpcs=new Set(),killMatches={},questLootByTemplate=new Map();
rows("quest_template",(v,c)=>{
 const q=+v[0], live=modernKills.get(q);
 if(!live)return;
 const matched=[1,2,3,4].map(i=>+v[c.indexOf("ReqCreatureOrGOId"+i)]).filter(i=>i>0&&live.has(i));
 if(matched.length){killMatches[q]=[...new Set(matched)];for(const i of matched)neededNpcs.add(i);}
});
rows("creature_loot_template",(v)=>{
 const [entry,item,chance,group,min,max,c]=v.slice(0,7).map(Number);
 if(!items.has(item)||chance>=0||chance < -100||group!==0||min<1||max<min||c!==0)return;
 const found=questLootByTemplate.get(entry)||new Set();found.add(item);questLootByTemplate.set(entry,found);
});
const byItem={}, profiles={};
rows("creature_template",(v,c)=>{
 const field=k=>v[c.indexOf(k)], npc=+field("Entry"), loot=questLootByTemplate.get(+field("LootId"));
 if(!neededNpcs.has(npc)&&!loot?.size)return;
 const raw=field("Name");
 if(!raw?.startsWith("'"))return;
 const name=raw.slice(1,-1).replace(/\\(['"\\])/g,"$1");
 if(!name||name.length>100||/[\x00-\x1f;|\[\]\\]/.test(name))return;
 const current=publicMobs.get(npc);
 if(current&&current.name.toLowerCase()!==name.toLowerCase())return; // no same-ID renamed creature
 const ids=[...new Set([1,2,3,4].map(i=>+field("ModelId"+i)).filter(i=>i>0))];
 const model=ids.length===1&&ids[0]!==11686&&ids[0]!==1126?ids[0]:0;
 if(!current||!current.model&&model)profiles[npc]=[current?.name||name,+field("MinLevel"),+field("MaxLevel"),model];
 if(loot)for(const i of loot)(byItem[i]??=[]).push(npc);
});
const classicCollect={};
for(const [q,x] of compatible)for(const item of new Set(x))if(byItem[item]?.length)(classicCollect[q]??={})[item]=byItem[item];
const d=["-- SPDX-License-Identifier: GPL-3.0-only","-- Adapted from CMaNGOS Classic-DB, pinned SQL revision and license as in ClassicQuestDropReferences.lua.",
 "-- Only exact quest/objective IDs shared by Classic and Forever. Classic corpse sources are quest-only rows.",
 "-- Preserve existing Forever display IDs; Classic display IDs require one unambiguous model.","local _,AT=..."];
function simple(name,rows){d.push("AT."+name+"={");for(const [k,r] of Object.entries(rows))d.push(" ["+k+"]={"+r.join(",")+"},");d.push("}");}
simple("ClassicQuestKillNPCs",killMatches);
d.push("AT.ClassicQuestCreatureProfiles={");
for(const [k,r] of Object.entries(profiles))d.push(" ["+k+"]={"+JSON.stringify(r[0])+","+r[1]+","+r[2]+',"",'+(r[3]||"nil")+"},");
d.push("}","AT.ClassicQuestCollectNPCs={");
for(const [k,r] of Object.entries(classicCollect))d.push(" ["+k+"]={"+Object.entries(r).map(([i,list])=>"["+i+"]={"+list.join(",")+"}").join(",")+"},");
d.push("}","");
fs.writeFileSync(outPath,d.join("\n"));
console.log({killQuests:Object.keys(killMatches).length,collectQuests:Object.keys(classicCollect).length,profiles:Object.keys(profiles).length,modelReferences:Object.values(profiles).filter(r=>r[3]).length});
