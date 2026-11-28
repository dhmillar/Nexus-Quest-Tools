"use strict";
const fs=require("node:fs"), z=require("node:zlib"), path=require("node:path");
const [src,out]=process.argv.slice(2);
const A="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const text=fs.readFileSync(path.join(src,"Nav2991.lua"),"utf8");
const readField=k=>+text.match(new RegExp("\\b"+k+"\\s*=\\s*(-?\\d+)\\s*,"))?.[1];
const [cx,cy,nx,ny,n,h]=["cx0","cy0","nx","ny","cells","zstep"].map(readField);
if(!text.includes("ShortestPathForeverPathData[2991]")||readField("format")!==4||readField("floorFormat")!==1||
 ![cx,cy,nx,ny,n,h].every(Number.isInteger)||n!==67)throw Error("unexpected grid revision");
const pack=fs.readFileSync(path.join(src,"Nav2991_1.lua"),"utf8");
const tiles={};
for(const m of pack.matchAll(/^data\.packed\.(grid|floor|height)\[(\d+)\]\s*=\s*\{([^}]+)\}/gm)){
 const t=tiles[m[2]]??={};
 if(t[m[1]])throw Error("duplicate field");
 const blocks=[...m[3].matchAll(/"([A-Za-z0-9+/=]+)"/g)].map(b=>z.inflateSync(Buffer.from(b[1],"base64"),{maxOutputLength:1e6}));
 if(!blocks.length)throw Error("empty compression block");
 t[m[1]]=Buffer.concat(blocks);
}
const cap=n*n, dx=[1,-1,0,0,1,1,-1,-1],dy=[0,0,1,-1,1,-1,1,-1],back=[1,0,3,2,7,6,5,4];
function cursor(s){
 let p=0;
 return {get offset(){return p},set offset(i){if(i<0||i>s.length)throw Error("stream range");p=i},
    get done(){return p>=s.length}, number(w=1){let v=0;while(w--){const a=A.indexOf(String.fromCharCode(s[p++]));if(a<0)throw Error("bad symbol "+p);v=v*64+a;}return v;},
    delta(){const x=this.number();return x===63?63+this.number(3):x;}};
}
function cells(t){
 const c=cursor(t.grid),len=c.number(),palette=Array.from({length:len},()=>c.number(2));
 const at=[];
 while(!c.done){
  const x=c.number();
  if(x>=48){if(!at.length)throw Error("repeat without previous");for(let i=0;i<x-47;i++)at.push(at.at(-1));}
  else{const value=x===47?c.number(2):palette[x];if(!Number.isInteger(value))throw Error("palette range");at.push(value);}
 }
 if(at.length!==cap)throw Error("wrong cell count "+at.length);
 return at;
}
function height(t,values){
 const c=cursor(t.height),heights=[];
 let last=0,delta=0,remaining=0;
 for(let k=0;k<cap;k++){
  if(values[k]>>8===0)continue;
  const pred=(k%n>0?heights[k-1]:undefined)??heights[k-n]??last;
  if(remaining){remaining--;last=pred+delta;}
  else{
   const v=c.number();
   if(v===47)last=c.number(2)-2048;
   else{
    if(v>=48)throw Error("unexpected repeat marker");
    delta=v-23;last=pred+delta;
    while(!c.done&&A.indexOf(String.fromCharCode(t.height[c.offset]))>=48)remaining+=c.number()-47;
   }
  }
  heights[k]=last;
 }
 if(!c.done||remaining)throw Error("height length mismatch");
 return heights;
}
function cut(t){
 const floors=new Map(),clear=Array(cap).fill(0);
 if(!t.floor||!t.floor.length)return {floors,clear};
 const c=cursor(t.floor),N=c.number(3),steps=[];
 let id=0;
 function note(node,mask,cell){steps.push({node,mask,cell});}
 for(let i=0;i<N;i++){
  id+=c.delta();if(id>=cap)throw Error("floor index");
  floors.set(id,(floors.get(id)||0)+1);
  c.number();c.number(2);note(cap+i,c.number(2),id);
 }
 const base=c.number(3);id=0;
 for(let i=0;i<base;i++){id+=c.delta();if(id>=cap)throw Error("base index");note(id,c.number(2),id);}
 const overrides=c.number(3);c.offset+=overrides; // skip the optional implicit-landing override stream
 for(const {node,mask,cell} of steps){
  const x=Math.floor(cell/n),y=cell%n;
  for(let d=0;d<8;d++)if(mask&(1<<d)){
   const X=x+dx[d],Y=y+dy[d],f=floors.get(X*n+Y);
   const implicit=X>=0&&X<n&&Y>=0&&Y<n&&(node<cap?f===1:!f);
   if(!implicit){let set=c.number();if(set===0){const count=c.number(2);for(let j=0;j<count;j++)c.number();}}
  }
 }
 const drops=c.number(3);c.offset+=drops*8;
 const marker=t.floor[c.offset],stride=cap+N;
 if(marker===126){
  c.offset++;
  if((t.floor.length-c.offset)%(2*stride+1))throw Error("bad clearance planes");
  for(let p=c.offset;p<t.floor.length;p+=2*stride+1)if(t.floor[p]===0){
   for(let i=0;i<cap;i++)clear[i]|=t.floor[p+1+i]|t.floor[p+1+i+stride];
  }
  c.offset=t.floor.length;
 }else{
  if(marker===33){
   c.offset++;
   for(let i=0;i<cap;i++)clear[i]|=t.floor[c.offset+i]|t.floor[c.offset+stride+i];
   c.offset+=2*stride;
  }
  let node=0;
  while(!c.done){
   node+=c.delta();const code=c.number(2);
   if(node<cap&&code%64===0)clear[node]|=1<<(Math.floor(code/64)%8);
  }
 }
 return {floors,clear};
}
for(const [key,t] of Object.entries(tiles)){
 if(!t.grid||!t.height||!t.floor)throw Error("incomplete tile "+key);
 t.values=cells(t);t.heights=height(t,t.values);
 Object.assign(t,cut(t));
}
const W=ny*n,H=nx*n;
function slot(X,Y){
 if(X<0||Y<0||X>=H||Y>=W)return;
 const tile=tiles[Math.floor(X/n)*ny+Math.floor(Y/n)+1],cell=X%n*n+Y%n;
 if(tile&&(tile.values[cell]>>8)===1&&!tile.floors.has(cell))return [tile,cell];
}
let edges=0,nodes=0;
const payload={};
for(const [key,t] of Object.entries(tiles)){
 const k=+key-1;const bin=Buffer.alloc(cap*3);
 for(let j=0;j<cap;j++){
  const x=Math.floor(k/ny)*n+Math.floor(j/n), y=(k%ny)*n+j%n;
  let mask=0;
  if(slot(x,y))for(let d=0;d<8;d++){
   const dest=slot(x+dx[d],y+dy[d]);
   if(!dest||!(t.values[j]&(1<<d))||(t.clear[j]&(1<<d)))continue;
   const [dt,at]=dest;
   if(!(dt.values[at]&(1<<back[d]))||(dt.clear[at]&(1<<back[d])))continue;
   if(Math.abs(t.heights[j]-dt.heights[at])>2)continue;
   mask|=1<<d;edges++;
  }
  if(mask){
   nodes++;
   bin[j*3]=mask;
   bin.writeInt16LE(t.heights[j]*h,j*3+1);
  }
 }
 payload[key]=bin;
}
if(Object.keys(payload).length!==25||edges<20000||nodes<4000)throw Error("unexpected converted coverage: "+[Object.keys(payload).length,nodes,edges]);
const lua=s=>'"'+[...s].map(b=>"\\"+String(b).padStart(3,"0")).join("")+'"';
const lines=["-- SPDX-License-Identifier: GPL-3.0-or-later","-- Derived from Shortest Path Forever v1.49.2 by cjber and contributors.",
 "-- https://github.com/cjber/shortest-path-forever ; source and license details in RouteData.Notice.md.",
 "-- NQT conversion: dry reciprocal base steps only. This module contains derived grid facts, not upstream code.",
 "local _,AT=...","AT.NQTDB=AT.NQTDB or {}","AT.NQTDB.RouteTiles={",
 " world=2991, cells="+n+", nx="+nx+", ny="+ny+", tx="+cx+", ty="+cy+",",
 " navigationBuild=71037, tiles={"];
for(const [key,b] of Object.entries(payload)){
 const fragments=[];
 for(let i=0;i<b.length;i+=1500)fragments.push(lua(b.subarray(i,i+1500)));
 lines.push(" ["+key+"]="+fragments.join("..\n")+",");
}
lines.push(" }}","");
fs.writeFileSync(out,lines.join("\n"));
console.log({tiles:Object.keys(payload).length,nodes,edges});
