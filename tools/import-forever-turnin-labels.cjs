"use strict";
const fs=require("node:fs"),path=require("node:path"),zlib=require("node:zlib"),crypto=require("node:crypto");
const [npcDir,completionDir,classicFile,nqt]=process.argv.slice(2);
const text=f=>fs.readFileSync(path.join(nqt,f),"utf8").replace(/\r\n/g,"\n");
const marker="-- BEGIN NQTDB corroborated turn-in labels (generated)",tail="-- END NQTDB corroborated turn-in labels";
const db=text("NQTDB.lua"), base=db.replace(new RegExp(marker.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+tail+"\n"),"");
const known=new Set();
for(const [file,key] of [["ForeverTownPins.lua","AT.ObservedQuestTurnIns"],["ForeverVerifiedEndpoints.lua","AT.ForeverVerifiedEndpointReferences"],
  ["ForeverVerifiedEndpoints.lua","AT.ForeverSupplementalTurnInReferences"],["NQTDB.lua","db.TurnIns"],["NQTDB.lua","db.VerifiedCompletionTurnIns"]]){
 const section=text(file).split(key+"={")[1]?.split("\n}",1)[0]??"";
 for(const m of section.matchAll(/^\s*\[(\d+)\]\s*=/gm))known.add(+m[1]);
}
const guide=new Map([...text("LevelGuideData.lua").matchAll(/^\s*\[(\d+)\]=\{\d+,(-?\d+),-?\d+,\d+,"[^"]+",\d+,[\d.]+,\d+,("(?:\\.|[^"\\])*"),\{/gm)]
  .map(m=>[+m[1],{level:+m[2],name:JSON.parse(m[3])}]));
const packed=fs.readFileSync(classicFile);
if(crypto.createHash("sha256").update(packed).digest("hex")!=="4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0")throw Error("Unpinned Classic snapshot");
const classic=new Map(), touched=(map,k)=>map.get(k)??map.set(k,new Set()).get(k);
for(const l of zlib.gunzipSync(packed).toString().split("\n"))if(l.startsWith("INSERT INTO "+String.fromCharCode(96)+"creature_involvedrelation"+String.fromCharCode(96)+" VALUES "))
 for(const m of l.matchAll(/\((\d+),(\d+)\)/g))touched(classic,+m[2]).add(+m[1]);
function read(dir,f,ds){
 const d=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8"));
 if(d.meta?.dataset!==ds||d.meta.product!=="wowf"||d.meta.license!=="CC BY 4.0"||d.meta.clientBuild!==f.split("-")[0])throw Error("Unexpected source "+f);
 return d;
}
const side={Alliance:1,Horde:2};
const outdoor=p=>p&&[0,1,2991].includes(p.instance)&&Number.isFinite(p.worldX)&&Number.isFinite(p.worldY)&&p.uiMap>=1400&&p.uiMap<10000&&p.mapX>0&&p.mapX<1&&p.mapY>0&&p.mapY<1;
const close=(p,b)=>p.uiMap===b.uiMap&&p.instance===b.instance&&Math.hypot(p.worldX-b.worldX,p.worldY-b.worldY)<=22;
const witnessed=new Map(), profiles=new Map(), candidates=new Map();
const count={newNPCLinks:0,verifiedGPS:0,corroboratedDisplay:0,notQualified:0};
for(const f of fs.readdirSync(npcDir).filter(s=>s.endsWith("-npcs.json")).sort()){
 const d=read(npcDir,f,"npcs"), completion=read(completionDir,f.replace("-npcs","-turn_ins"),"turn_ins");
 for(const [kind,entries] of [[1,d.npcs],[2,d.objects]])for(const [raw,r] of Object.entries(entries??{})){
  const key=kind+":"+raw, pos=r.positions??[];
  const profile=profiles.get(key)??profiles.set(key,[]).get(key);profile.push({pos,side:side[r.side],name:r.name});
  for(const [q,t] of Object.entries(r.takes??{})){
   const want=guide.get(+q);
   if(known.has(+q)||!want)continue;
   touched(witnessed,+q).add(key);
   if(kind!==1||t.title!==want.name)continue;
   const cohort=completion.quests[q]??[], recorded=cohort.filter(x=>Number.isSafeInteger(x.sources)&&x.sources>0);
   if(recorded.some(x=>side[x.faction]!==side[r.side])||!side[r.side]||t.level!==want.level||!/^[^\x00-\x1f;|\[\]]{1,100}$/.test(r.name??"")||
      classic.get(+q)?.size!==1||!classic.get(+q).has(+raw)||pos.length===0||!pos.every(outdoor))continue;
   const list=candidates.get(+q)??candidates.set(+q,[]).get(+q);
   list.push({key,id:+raw,name:r.name,side:side[r.side],pos,build:d.meta.clientBuild,complete:recorded.length>0});
  }
 }
}
const out=[];
for(const [q,seen] of witnessed){
 count.newNPCLinks++;
 const batch=candidates.get(q), last=batch?.at(-1);
 if(!last||seen.size!==1){count.notQualified++;continue;}
 if(batch.some(r=>r.complete)){count.verifiedGPS++;continue;} // handled by the stricter completed-turn-in importer
 const p=last.pos.at(-1), distinct=new Set();
 for(const row of profiles.get(last.key)??[]){
  if(row.name!==last.name||row.side!==last.side||row.pos.some(pt=>!outdoor(pt)||!close(pt,p))){distinct.clear();break;}
  for(const pt of row.pos)distinct.add(pt.worldX+":"+pt.worldY);
 }
 if(distinct.size<2){count.notQualified++;continue;}
 out.push(" ["+q+"]={{"+[p.uiMap,p.mapX,p.mapY,1,last.id,last.side,JSON.stringify(last.name)].join(",")+"}}, -- "+last.build);
}
if(!out.length)throw Error("No qualifying display hints: "+JSON.stringify(count));
count.corroboratedDisplay=out.length;
const L=[marker,"-- Quest turn-in links and outdoor NPC locations: Efficient Games Forever, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Exact quest/recipient facts independently checked against CMaNGOS Classic DB, GPL-2.0.",
 "-- https://github.com/cmangos/classic-db/tree/04bc47631b680b99cdfeee88488dafb5e871c207",
 "-- No same-build actual completion witness; display or native POI map lookup only.",
 "db.CorroboratedTurnInLabels={",...out,"}",tail,""];
fs.writeFileSync(path.join(nqt,"NQTDB.lua"),base+L.join("\n"));
console.log(JSON.stringify(count));
