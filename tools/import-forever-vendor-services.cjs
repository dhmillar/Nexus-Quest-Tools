"use strict";
const fs=require("node:fs"),path=require("node:path");
const [vendors,npcs,creatures,nqt]=process.argv.slice(2);
const read=(d,f)=>JSON.parse(fs.readFileSync(path.join(d,f),"utf8"));
const requireDoc=(d,build,tag)=>{
 if(d.meta?.dataset!==tag||d.meta?.clientBuild!==build||d.meta?.product!=="wowf"||d.meta?.license!=="CC BY 4.0")throw Error("Bad source "+build+" "+tag);
};
const validName=s=>typeof s==="string"&&/^[^\x00-\x1f;|\[\]]{1,100}$/.test(s);
const body=d=>d.type===7&&Number.isSafeInteger(d.flags?.[0])&&(d.flags[0]&0x02000000)===0
    &&d.displays?.some(r=>r.displayId>0&&![11686,1126,52318].includes(r.displayId)&&r.scale>0);
const profile=new Map(), rejected=new Set();
for(const build of fs.readdirSync(creatures).sort()){
 const file=path.join(build,"creature_details.enUS.json");if(!fs.existsSync(path.join(creatures,file)))continue;
 const d=read(creatures,file);requireDoc(d,build,"creature_details");if(d.meta.locale!=="enUS")throw Error("Bad locale");
 for(const [k,r] of Object.entries(d.creatures??{})){
  if(!validName(r.name)||!body(r)||/\b(basket|crate|container|bottle|chest|pouch|barrel)\b.*\b(supplies|goods|stock|tools)\b/i.test(r.name)){rejected.add(k);continue;}
  const old=profile.get(k);
  if(old&&(old.name!==r.name||old.title&&r.title&&old.title!==r.title)){rejected.add(k);continue;}
  profile.set(k,{name:r.name,title:validName(r.title)?r.title:old?.title??""});
 }
}
const side={Neutral:0,Alliance:1,Horde:2};
const outdoors=p=>[0,1,2991].includes(p?.instance)&&Number.isSafeInteger(p.uiMap)&&p.uiMap>=1400&&p.uiMap<10000
  &&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1&&Number.isFinite(p.worldX)&&Number.isFinite(p.worldY);
const gap=new Map();
for(const file of fs.readdirSync(vendors).filter(f=>f.endsWith("-vendors.json")).sort()){
 const build=file.split("-")[0], npcFile=build+"-npcs.json";
 if(!fs.existsSync(path.join(npcs,npcFile)))continue;
 const d=read(vendors,file), n=read(npcs,npcFile);requireDoc(d,build,"vendors");requireDoc(n,build,"npcs");
 for(const [k,dv] of Object.entries(d.vendors??{})){
  const p=profile.get(k),r=n.npcs?.[k];
  if(rejected.has(k)||!p||r?.name!==p.name||dv.name!==p.name||side[r.side]===undefined||!r.interactions?.includes("Merchant")||
      typeof dv.repairs!=="boolean"||!Number.isSafeInteger(dv.visits)||dv.visits<1)continue;
  if(!dv.repairs&&!Object.values(dv.entries??{}).some(e=>e.itemId>0&&e.sources>0&&Object.values(e.costs??{}).some(c=>Number.isSafeInteger(c)&&c>0)))continue;
  const pos=dv.positions??[], nearby=r.positions?.filter(outdoors)??[];
  if(pos.length===0||pos.some(x=>!outdoors(x)))continue;
  const samples=pos.filter(x=>nearby.some(y=>x.uiMap===y.uiMap&&x.instance===y.instance&&Math.hypot(x.worldX-y.worldX,x.worldY-y.worldY)<=20));
  if(!samples.length)continue;
  const hits=gap.get(k)??gap.set(k,[]).get(k);
  for(const pnt of samples)hits.push({p:pnt,side:side[r.side],repair:dv.repairs,build});
 }
}
const dbPath=path.join(nqt,"NQTDB.lua");
const db=fs.readFileSync(dbPath,"utf8").replace(/\r\n/g,"\n");
const prev=new Map(), locs=new Map();
for(const l of fs.readFileSync(path.join(nqt,"LevelGuideGivers.lua"),"utf8").split("AT.LevelGuideNPCServices={")[1].split(/\r?\n}/)[0].split(/\r?\n/)){
 const m=l.match(/^\s*\[(\d+)\]=\{(.*)/);if(!m)continue;
 for(const x of m[2].matchAll(/\{([36]),(\d+),([\d.]+),([\d.]+),("(?:\\.|[^"\\])*")\}/g)){
  const key=[+m[1],JSON.parse(x[5]),+x[1]].join(":");(prev.get(key)??prev.set(key,[]).get(key)).push([+x[3],+x[4]]);
 }
}
const a="-- BEGIN NQTDB exact vendor services (generated)",b="-- END NQTDB exact vendor services";
const L=[a,"-- Efficient Games Forever merchant and interaction observations, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Exact creature ID, known faction, targetable body and two agreeing position datasets.",
 "db.VerifiedVendorServices={"];let ids=0,total=0;
for(const [k,hits] of [...gap].sort((a,b)=>+a[0]-+b[0])){
 const last=hits.at(-1), p=last.p, meta=profile.get(k);
 if(hits.some(x=>x.p.uiMap!==p.uiMap||x.p.instance!==p.instance||x.side!==last.side||x.repair!==last.repair||
   Math.hypot(x.p.worldX-p.worldX,x.p.worldY-p.worldY)>30))continue;
 L.push(" ["+k+"]={"+[JSON.stringify(meta.name),JSON.stringify(meta.title),last.side,String(last.repair)].join(",")+"},");
 ids++;
 for(const kind of last.repair?[3,6]:[6]){
  if((prev.get([p.uiMap,meta.name,kind].join(":"))??[]).some(([x,y])=>Math.hypot(x-p.mapX,y-p.mapY)<.018))continue;
  const map=locs.get(p.uiMap)??locs.set(p.uiMap,[]).get(p.uiMap);map.push([kind,last.side,p.mapX,p.mapY,meta.name,+k]);total++;
 }
}
L.push("}","db.AdditionalGuideNPCServicePins={");
for(const [map,pins] of [...locs].sort((a,b)=>a[0]-b[0]))L.push(" ["+map+"]={"+pins.map(r=>"{"+r.map(x=>typeof x==="string"?JSON.stringify(x):x).join(",")+"}").join(",")+"},");
L.push("}",b,"");
if(ids<25||total<3)throw Error("Incomplete or insufficient service evidence");
fs.writeFileSync(dbPath,db.replace(new RegExp(a.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+b+"\n"),"")+L.join("\n"));
console.log(JSON.stringify({vendorIds:ids,mapPins:total,maps:locs.size}));
