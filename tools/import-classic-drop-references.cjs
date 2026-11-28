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
const record=new Map(), seen=new Set();
for(const [table,kind] of [["creature_loot_template","npc"],["gameobject_loot_template","object"]]){
 rows(table,(v,c)=>{
  const [entry,item,chance,group,min,max,condition]=v.slice(0,7).map(Number);
  if(!items.has(item)||group!==0||min<1||max<min||condition!==0||!Number.isFinite(chance)||!chance||Math.abs(chance)>100)return;
  const k=[kind,entry,item].join(":");if(seen.has(k))throw Error("ambiguous source roll "+k);seen.add(k);
  const rate=Math.abs(chance), old=record.get(item);
  if(old){old[0]=Math.min(old[0],rate);old[1]=Math.max(old[1],rate);}
  else record.set(item,[rate,rate]);
 });
}
const lines=[
 "-- SPDX-License-Identifier: GPL-3.0-only",
 "-- Classic-DB (CMaNGOS contributors), numeric references adapted by Nexus Quest Tools.",
 "-- https://github.com/cmangos/classic-db/tree/04bc47631b680b99cdfeee88488dafb5e871c207",
 "-- Pinned SQL SHA-256: "+digest,
 "-- Source/rebuild: tools/import-classic-drop-references.cjs in the tagged NQT repository.",
 "-- Independently rolled, unconditional direct loots only; grouped/conditional/reference rolls omitted.",
 "-- Match both exact quest ID and required item ID in Classic and Forever.",
 "-- Lower and upper Classic percentages; these are estimates, not Forever observations.",
 "local _,AT=...",
 "AT.ClassicQuestDropReferences={"
];
let quests=0,pairs=0;
for(const [q,targets] of [...compatible].sort((a,b)=>a[0]-b[0])){
 const ref=[...new Set(targets)].sort((a,b)=>a-b).filter(i=>record.has(i));
 if(!ref.length)continue;
 quests++;pairs+=ref.length;
 lines.push(" ["+q+"]={"+ref.map(i=>"["+i+"]={"+record.get(i).join(",")+"}").join(",")+"},");
}
if(quests<100||pairs<100)throw Error("Unexpectedly small classification");
lines.push("}","");
fs.writeFileSync(outPath,lines.join("\n"));
console.log({quests,pairs,rolls:seen.size});
