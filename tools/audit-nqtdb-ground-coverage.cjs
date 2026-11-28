"use strict";
const fs=require("node:fs"),p=require("node:path");
const [source,addon="NQT",dest]=process.argv.slice(2);
const n=67,T=1600/3;
const alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const amount=/^-?\d+$/;
function readWorld(w){
 const text=fs.readFileSync(p.join(addon,w===2991?"NQTDBRouteTiles.lua":"NQTDBRouteWorld"+w+".lua"),"utf8");
 const read=k=>+text.match(new RegExp("\\b"+k+"=(-?\\d+)"))?.[1];
 const [tx,ty,nx,ny,cells]=["tx","ty","nx","ny","cells"].map(read);
 if(cells!==n||![tx,ty,nx,ny].every(Number.isSafeInteger))throw Error("Invalid grid header");
 const tiles=new Map();
 for(const m of text.matchAll(/^ \[(\d+)\]=(.*?),\r?$/gms)){
  const tile=Buffer.alloc(n*n);
  if(w===2991){
   const cells=[...m[2].matchAll(/\\(\d{3})/g)].map(a=>+a[1]);
   if(cells.length!==3*n*n)throw Error("Invalid Zephras payload");
   for(let i=0;i<n*n;i++)tile[i]=cells[i*3];
  }else{
   const encoded=m[2].match(/^"([A-Za-z0-9+/]+)"$/)?.[1];
   if(!encoded)throw Error("Invalid continent tile");
   let pos=0,cell=0;
   while(pos<encoded.length){
    const a=alphabet.indexOf(encoded[pos++]),b=alphabet.indexOf(encoded[pos++]),c=alphabet.indexOf(encoded[pos++]);
    if(a===0)cell+=b*64+c;
    else {tile[cell++]=(a-1)*64+b;if(c===63)pos+=3;}
   }
   if(cell!==n*n||pos!==encoded.length)throw Error("Invalid tile length");
  }
  tiles.set(+m[1],tile);
 }
 if(!tiles.size)throw Error("No terrain");
 return {tx,ty,nx,ny,tiles};
}
const W=new Map([0,1,2991].map(w=>[w,readWorld(w)]));
function status(v){
 const w=W.get(v.instance);
 if(!w)return "otherWorld";
 const x=Math.floor(v.worldX/T*n-w.tx*n), y=Math.floor(v.worldY/T*n-w.ty*n);
 if(x<0||y<0||x>=w.nx*n||y>=w.ny*n)return "beyondGrid";
 const t=w.tiles.get(Math.floor(x/n)*w.ny+Math.floor(y/n)+1);
 if(!t)return "noDryTile";
 if(t[x%n*n+y%n])return "dryCell";
 return "maskedCell";
}
const seen=new Map();
for(const file of fs.readdirSync(source).filter(f=>/^1\.60\.1\.\d+-(npcs|objectives)\.json$/.test(f))){
 const kind=file.endsWith("npcs.json")?"npcs":"objectives";
 const data=JSON.parse(fs.readFileSync(p.join(source,file),"utf8"));
 if(data.meta?.dataset!==kind||data.meta?.license!=="CC BY 4.0"||data.meta?.product!=="wowf")throw Error("Unexpected source "+file);
 const note=(id,label,positions)=>{
  for(const v of positions??[]){
   if(!Number.isInteger(v.uiMap)||!Number.isInteger(v.instance)||!Number.isFinite(v.worldX)||!Number.isFinite(v.worldY))continue;
   const key=kind+":"+id+":"+v.instance+":"+v.uiMap+":"+v.worldX+":"+v.worldY;
   seen.set(key,{kind,id,label,world:v.instance,map:v.uiMap,raw:[v.worldX,v.worldY],status:status(v)});
  }
 };
 if(kind==="npcs"){
  for(const [id,r] of Object.entries(data.npcs??{}))if(amount.test(id))note(id,r.name,r.positions);
 }else{
  for(const [qid,rows] of Object.entries(data.quests??{}))
   for(const [index,r] of Object.entries(rows))note(qid+":"+index,r.type,r.positions);
 }
}
const rollup={},mapCounts={};
function count(bucket,r){bucket[r.status]=(bucket[r.status]??0)+1;}
for(const row of seen.values()){
 count(rollup[row.kind]??={},row);
 count(mapCounts[row.kind+":"+row.world+":"+row.map]??={},row);
}
const summary={total:seen.size,rollup,mapCounts};
console.log(JSON.stringify({total:summary.total,rollup},null,2));
if(dest)fs.writeFileSync(dest,JSON.stringify({...summary,evidence:[...seen.values()].filter(r=>r.status!=="dryCell")},null,2));
