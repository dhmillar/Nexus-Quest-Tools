"use strict";
const fs=require("node:fs"),path=require("node:path");
const [trainers,npcs,creatures,nqt]=process.argv.slice(2);
const read=(d,f)=>JSON.parse(fs.readFileSync(path.join(d,f),"utf8"));
const verify=(d,build,kind)=>{if(d.meta?.product!=="wowf"||d.meta.dataset!==kind||d.meta.clientBuild!==build||d.meta.license!=="CC BY 4.0")throw Error("Bad input "+build+" "+kind)};
const validName=s=>typeof s==="string"&&/^[^\x00-\x1f;|\[\]]{1,100}$/.test(s);
const targetable=d=>d.type===7&&Number.isSafeInteger(d.flags?.[0])&&(d.flags[0]&0x02000000)===0&&
    d.displays?.some(r=>r.displayId>0&&![11686,1126,52318].includes(r.displayId)&&r.scale>0);
const side={Alliance:1,Horde:2,Neutral:0};
const coords=p=>[0,1,2991].includes(p?.instance)&&Number.isSafeInteger(p.uiMap)&&p.uiMap>=1400&&p.uiMap<10000&&
    p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1&&Number.isFinite(p.worldX)&&Number.isFinite(p.worldY);
const classes=["death knight","demon hunter","warrior","paladin","hunter","rogue","priest","shaman","mage","warlock","druid","monk","evoker"];
const profs=["first aid","alchemy","blacksmithing","cooking","enchanting","engineering","fishing","herbalism","leatherworking","mining","skinning","tailoring","jewelcrafting","inscription"];
const titleRole=(title,roles)=>{
 const s=title?.toLowerCase()??"";
 return roles.find(role=>new RegExp("\\b"+role+"\\b").test(s));
};
const profiles=new Map(),rejected=new Set();
for(const build of fs.readdirSync(creatures).sort()){
 const f=path.join(build,"creature_details.enUS.json");if(!fs.existsSync(path.join(creatures,f)))continue;
 const d=read(creatures,f);verify(d,build,"creature_details");if(d.meta.locale!=="enUS")throw Error("Wrong profile locale");
 for(const [id,c] of Object.entries(d.creatures??{})){
  const old=profiles.get(id);
  if(!validName(c.name)||!targetable(c)||old&&(old.name!==c.name||old.title&&c.title&&old.title!==c.title)){rejected.add(id);continue;}
  profiles.set(id,{name:c.name,title:validName(c.title)?c.title:old?.title??""});
 }
}
const candidates=new Map();let exportsRead=0;
for(const f of fs.readdirSync(trainers).filter(x=>/^1\.60\.1\.\d+-trainers\.json$/.test(x)).sort()){
 const build=f.split("-")[0],nf=build+"-npcs.json";
 if(!fs.existsSync(path.join(npcs,nf)))continue;
 const d=read(trainers,f), n=read(npcs,nf);verify(d,build,"trainers");verify(n,build,"npcs");exportsRead++;
 for(const [id,t] of Object.entries(d.trainers??{})){
  const nPC=n.npcs?.[id], profile=profiles.get(id);
  if(!profile||rejected.has(id)||nPC?.name!==profile.name||t.name!==profile.name||side[nPC.side]===undefined||
     !nPC.interactions?.includes("Trainer")||!Object.values(t.services??{}).some(s=>Number.isSafeInteger(s.spellId)&&s.spellId>0&&s.sources>0))continue;
  let kind=t.trainerType===0&&t.tradeskill===false?4:t.trainerType===2&&t.tradeskill===true?5:null;
  if(!kind)continue;
  if(kind===4&&/\bweapon (master|trainer)\b/i.test(profile.title))kind=11;
  const specialty=titleRole(profile.title,kind===4?classes:profs);
  const skills=new Set(Object.values(t.services??{}).filter(s=>typeof s.skill==="string").map(s=>s.skill.trim().toLowerCase()).filter(v=>profs.includes(v)));
  if(kind===5&&specialty&&skills.size>0&&!skills.has(specialty))continue;
  const role=kind===11?"weapon":specialty??(kind===4?"class":skills.size===1?[...skills][0]:"profession");
  const pts=t.positions??[], nearby=nPC.positions?.filter(coords)??[];
  if(!pts.length||!pts.every(coords))continue;
  const finds=pts.filter(x=>nearby.some(y=>x.uiMap===y.uiMap&&x.instance===y.instance&&Math.hypot(x.worldX-y.worldX,x.worldY-y.worldY)<=20));
  if(!finds.length)continue;
  const list=candidates.get(id)??candidates.set(id,[]).get(id);
  for(const p of finds)list.push({p,name:profile.name,kind,role,side:side[nPC.side],build});
 }
}
const prior=new Map();
const section=fs.readFileSync(path.join(nqt,"LevelGuideGivers.lua"),"utf8").split("AT.LevelGuideNPCServices={")[1].split(/\r?\n}/)[0];
for(const l of section.split(/\r?\n/)){
 const m=l.match(/^\s*\[(\d+)\]=\{(.*)/);if(!m)continue;
 for(const x of m[2].matchAll(/\{(4|5|11),(\d+),([\d.]+),([\d.]+),("(?:\\.|[^"\\])*")\}/g)){
  const key=[+m[1],JSON.parse(x[5]),+x[1]].join(":");(prior.get(key)??prior.set(key,[]).get(key)).push([+x[3],+x[4]]);
 }
}
const start="-- BEGIN NQTDB exact trainer services (generated)",end="-- END NQTDB exact trainer services";
const out=[start,"-- Trainer windows, real NPC identities and positions from Efficient Games Forever, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Same-build trainer interaction and service evidence, targetable identity and matched position.",
 "db.VerifiedTrainerServices={"];
let ids=0,total=0,typed=0;const pins=new Map();
for(const [id,hits] of [...candidates].sort((a,b)=>+a[0]-+b[0])){
 const h=hits.at(-1),p=h.p;
 const specialty=new Set(hits.filter(x=>x.role!=="class"&&x.role!=="profession").map(x=>x.role));
 if(specialty.size>1||hits.some(x=>x.p.uiMap!==p.uiMap||x.p.instance!==p.instance||x.kind!==h.kind||x.side!==h.side||
   Math.hypot(x.p.worldX-p.worldX,x.p.worldY-p.worldY)>30))continue;
 const role=[...specialty][0]??h.role;
 ids++;if(specialty.size)typed++;
 out.push(" ["+id+"]={"+[JSON.stringify(h.name),JSON.stringify(role),h.side].join(",")+"},");
 if((prior.get([p.uiMap,h.name,h.kind].join(":"))??[]).some(([x,y])=>Math.hypot(x-p.mapX,y-p.mapY)<.018))continue;
 (pins.get(p.uiMap)??pins.set(p.uiMap,[]).get(p.uiMap)).push([h.kind,h.side,p.mapX,p.mapY,h.name,+id]);
 total++;
}
out.push("}","db.AdditionalGuideTrainerPins={");
for(const [m,r] of [...pins].sort((a,b)=>a[0]-b[0]))out.push(" ["+m+"]={"+r.map(x=>"{"+x.map(z=>typeof z==="string"?JSON.stringify(z):z).join(",")+"}").join(",")+"},");
out.push("}",end,"");
if(exportsRead<12||ids<20)throw Error("Incomplete trainer corpus: "+[exportsRead,ids]);
const f=path.join(nqt,"NQTDB.lua"),db=fs.readFileSync(f,"utf8").replace(/\r\n/g,"\n").replace(new RegExp(start.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+end+"\n"),"");
fs.writeFileSync(f,db+out.join("\n"));
console.log(JSON.stringify({exportsRead,trainerIDs:ids,exactSpecialty:typed,pins:total,maps:pins.size}));
