"use strict";
const fs=require("node:fs"),path=require("node:path");
const [npcDir,completeDir,out]=process.argv.slice(2);
const read=f=>fs.readFileSync(path.join(out,f),"utf8");
const sec=(f,k)=>((read(f).split(k+"={")[1]??"").split(/\r?\n}/,1)[0]);
const table=(f,k)=>new Set([...sec(f,k).matchAll(/^\s*\[(\d+)\]\s*=/gm)].map(x=>+x[1]));
const already=new Set([...table("ForeverTownPins.lua","AT.ObservedQuestTurnIns"),
 ...table("ForeverVerifiedEndpoints.lua","AT.ForeverVerifiedEndpointReferences"),
 ...table("ForeverVerifiedEndpoints.lua","AT.ForeverSupplementalTurnInReferences"),
 ...table("NQTDB.lua","db.TurnIns")]);
const catalog=new Map([...read("LevelGuideData.lua").matchAll(/^\s*\[(\d+)\]=\{\d+,(-?\d+),-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{/gm)]
 .map(m=>[+m[1],{name:JSON.parse(m[3]),level:+m[2]}]));
if(catalog.size<5000||already.size<4000)throw Error("Unexpected NQTDB baseline.");
const side={Alliance:1,Horde:2};
const id=v=>Number.isSafeInteger(v)&&v>0;
const name=v=>typeof v==="string"&&v.length>0&&v.length<=100&&!/[\x00-\x1f;|\[\]]/.test(v);
const coord=p=>p&&[0,1,2991].includes(p.instance)&&p.uiMap>=1400&&p.uiMap<10000&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1;
const close=(a,b)=>a.uiMap===b.uiMap&&Math.hypot(a.mapX-b.mapX,a.mapY-b.mapY)<=.02;
const add=(m,k,v)=>(m.get(k)??m.set(k,[]).get(k)).push(v);
function samples(dir,type){
 return fs.readdirSync(dir).filter(f=>new RegExp("^1\\.60\\.1\\.\\d+-"+type+"\\.json$").test(f))
  .sort((a,b)=>+a.split(".")[3].split("-")[0]- +b.split(".")[3].split("-")[0]).map(f=>{
   const d=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8"));
   if(d.meta?.clientBuild!==f.split("-")[0]||d.meta.dataset!==type||d.meta.schemaVersion!==1||d.meta.product!=="wowf"||d.meta.license!=="CC BY 4.0")throw Error("Unexpected source: "+f);
   return d;
  });
}
const witnessed=new Map(),positions=new Map(),matches=new Map();
const completions=new Map(samples(completeDir,"turn_ins").map(d=>[d.meta.clientBuild,d.quests]));
for(const d of samples(npcDir,"npcs")){
 const build=d.meta.clientBuild;
 for(const [kind,entries] of [[1,d.npcs],[2,d.objects]])for(const [raw,r] of Object.entries(entries??{})){
  const e=+raw;
  if(!id(e))continue;
  const key=kind+":"+raw, pts=r.positions?.filter(coord)??[];
  if(pts.length)add(positions,key,{points:pts,side:side[r.side]});
  for(const [rawQ,t] of Object.entries(r.takes??{})){
   const q=+rawQ,want=catalog.get(q);
   if(!want || already.has(q))continue;
   // Even compared records in a different client locale are evidence that
   // a second entity may exist, so they can disqualify an apparent match.
   add(witnessed,q,key);
   if(kind!==1 || t.title!==want.name || !name(r.name))continue;
   const c=completions.get(build)?.[rawQ]?.filter(x=>id(x.sources)&&side[x.faction]);
   const sides=new Set(c?.map(x=>side[x.faction])??[]);
   if(!pts.length||sides.size!==1)continue;
   const faction=[...sides][0];
   if(side[r.side]&&side[r.side]!==faction)continue;
   add(matches,q,{entity:key,id:e,name:r.name,side:faction,points:pts,build});
  }
 }
}
const outRows=[];
for(const [q,rs] of matches){
 const last=rs.at(-1),p=last.points.at(-1);
 if(new Set(witnessed.get(q)).size!==1 || rs.some(r=>r.side!==last.side||r.name!==last.name))continue;
 // Reject wandering or phase-dependent entities rather than average maps.
 if((positions.get(last.entity)??[]).some(r=>r.points.some(at=>!close(at,p))||r.side&&r.side!==last.side))continue;
 outRows.push({q,id:last.id,name:last.name,side:last.side,loc:p,build:last.build});
}
outRows.sort((a,b)=>a.q-b.q);
if(outRows.length<4)throw Error("No independently corroborated additions.");
const prefix=[
 "-- BEGIN NQTDB completed turn-ins (generated)",
 "-- Efficient Games NPC hand-in observations and same-build recorded quest completions, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Use only for held quests ready to hand in; WoW's own marker always wins.",
 "db.VerifiedCompletionTurnIns={"
];
for(const {q,id,name,side,loc,build} of outRows){
 prefix.push(" ["+q+"]={{"+[loc.uiMap,+loc.mapX.toFixed(4),+loc.mapY.toFixed(4),1,id,side,JSON.stringify(name)].join(",")+"}}, -- "+build);
}
prefix.push("}","-- END NQTDB completed turn-ins","");
const dest=path.join(out,"NQTDB.lua");
const orig=read("NQTDB.lua").replace(/\r\n/g,"\n").replace(/-- BEGIN NQTDB completed turn-ins \(generated\)\n[\s\S]*?-- END NQTDB completed turn-ins\n/,"");
fs.writeFileSync(dest,orig+prefix.join("\n"));
console.log(JSON.stringify({catalog:catalog.size,priorRouting:already.size,qualified:outRows.map(r=>r.q)}));
