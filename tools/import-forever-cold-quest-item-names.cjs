"use strict";
const fs=require("node:fs"),crypto=require("node:crypto");
const [questFile,itemFile,addon="NQT"]=process.argv.slice(2);
const parse=(file,sha,dataset)=>{
 const b=fs.readFileSync(file);
 if(crypto.createHash("sha256").update(b).digest("hex")!==sha)throw Error("Unrecognized pinned "+dataset+" input");
 const d=JSON.parse(b),m=d.meta;
 if(m?.dataset!==dataset||m.product!=="wowf"||m.clientBuild!=="1.60.1.71139"||m.license!=="CC BY 4.0"||m.locale!=="enUS")throw Error("Unexpected source metadata");
 return d;
};
const qs=parse(questFile,"f9ae9af83c72285e024a83943cf365f1751545c8dce047d1359d30c295b4a621","quests").quests;
const items=parse(itemFile,"6fb35f4b9c759fe512490150a61d4f5b1379771bcb9e11e9ef8288476830820a","item_hotfixes").items;
const files=n=>fs.readFileSync(addon+"/"+n,"utf8");
const catalog=new Map([...files("LevelGuideData.lua").matchAll(/^\s*\[(\d+)\]=\{\d+,-?\d+,-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{(.*)\}\},/gm)].map(m=>[+m[1],[JSON.parse(m[2]),[...m[3].matchAll(/\{2,(\d+),(\d+)\}/g)].map(x=>x.slice(1).map(Number))]]));
const facts=files("ForeverQuestFacts.lua");
const existing=new Set([...facts.split("AT.ForeverQuestItemNames={")[1].split("\n}",1)[0].matchAll(/^ *\[(\d+)\]=/gm)].map(x=>+x[1]));
const picked=new Map(),evidence=[];
for(const [id,r] of Object.entries(qs)){
 const c=catalog.get(+id);
 if(!c||c[0]!==r.title||!c[1])continue;
 for(const o of r.objectives??[]){
  const i=o.objectId,v=items[i];
  if(o.type!=="item"||!c[1].some(a=>a[0]===i&&a[1]===o.amount)||existing.has(i)
   ||v?.status!=="valid"||!(v.sources>=2)||typeof v.name!=="string"||!v.name||/[|\x00-\x1f<>]/.test(v.name))continue;
  picked.set(i,v.name);evidence.push({quest:+id,item:i,amount:o.amount,name:v.name,sources:v.sources});
 }
}
if(picked.size<75)throw Error("Unexpected remaining candidate count "+picked.size);
const dest=addon+"/NQTDB.lua",prev=files("NQTDB.lua").replace(/-- BEGIN NQTDB current cold item names \(generated\)\n[\s\S]*?-- END NQTDB current cold item names\n/,"");
const out=["-- BEGIN NQTDB current cold item names (generated)",
 "-- Identical item and quantity in the Forever quest and valid English hotfix caches (CC BY 4.0).",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf/1.60.1.71139",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "db.CurrentColdQuestItemNames={"];
for(const [i,name] of [...picked].sort((a,b)=>a[0]-b[0]))out.push(" ["+i+"]="+JSON.stringify(name)+",");
out.push("}","-- END NQTDB current cold item names","");
fs.writeFileSync(dest,prev+out.join("\n"));
console.log(JSON.stringify({items:picked.size,questItems:evidence.length}));
for(const e of evidence)console.log(JSON.stringify(e));
