"use strict";
const fs=require("node:fs"),p=require("node:path");
const [root="NQT",output="NQT/NQTDBDryComponents.lua"]=process.argv.slice(2);
const alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const nxD=[1,-1,0,0,1,1,-1,-1],nyD=[0,0,1,-1,1,-1,1,-1],rev=[1,0,3,2,7,6,5,4];
const code=(n,d)=>Array.from({length:d},(_,i)=>alphabet[(n>>(6*(d-1-i)))&63]).join("");
function decode(w,content){
 const header=k=>+content.match(new RegExp("\\b"+k+"=(-?\\d+)"))?.[1];
 const C=header("cells"),nx=header("nx"),ny=header("ny");
 if(C!==67||!Number.isInteger(nx)||!Number.isInteger(ny)||nx<1||ny<1||nx*ny>10000)throw Error("grid header");
 const tiles=[];
 for(const m of content.matchAll(/^ \[(\d+)\]=(.*?),\r?$/gms)){
  const id=+m[1]-1;
  if(id<0||id>=nx*ny||tiles[id])throw Error("tile key");
  const v=new Uint8Array(C*C);
  if(w===2991){
   const bytes=[...m[2].matchAll(/\\(\d{3})/g)].map(m=>+m[1]);
   if(bytes.length!==3*C*C)throw Error("tile length");
   for(let i=0;i<v.length;i++)v[i]=bytes[3*i];
  }else{
   const s=m[2].match(/^"([A-Za-z0-9+/]+)"$/)?.[1];
   if(!s)throw Error("tile encoding");
   let k=0,j=0;
   while(k<s.length){
    const a=alphabet.indexOf(s[k++]),b=alphabet.indexOf(s[k++]),c=alphabet.indexOf(s[k++]);
    if(c<0)throw Error("bad packed mask");
    if(a===0){const len=b*64+c;if(len<1)throw Error("empty run");j+=len}
    else{const mask=(a-1)*64+b;if(mask<=0||mask>255)throw Error("mask");v[j++]=mask;if(c===63)k+=3}
    if(j>v.length)throw Error("overrun");
   }
   if(j!==v.length||k!==s.length)throw Error("tile length");
  }
  tiles[id]=v;
 }
 return {C,nx,ny,tiles};
}
function components({C,nx,ny,tiles}){
 const stride=ny*C, n=nx*C*stride,mask=new Uint8Array(n),found=new Uint32Array(n);
 let valid=0;
 for(const [k,v] of tiles.entries())if(v){
  const x=Math.floor(k/ny)*C,y=k%ny*C;
  for(let i=0;i<v.length;i++)if(v[i]){mask[(x+Math.floor(i/C))*stride+y+i%C]=v[i];valid++}
 }
 const queue=new Uint32Array(valid);
 let total=0,largest=0;
 for(let k=0;k<n;k++)if(mask[k]&&!found[k]){
  total++;let at=0,end=1;queue[0]=k;found[k]=total;
  while(at<end){
   const j=queue[at++],x=Math.floor(j/stride),y=j%stride;
   for(let d=0;d<8;d++)if(mask[j]&(1<<d)){
    const X=x+nxD[d],Y=y+nyD[d],v=X*stride+Y;
    if(X<0||X>=nx*C||Y<0||Y>=stride||!(mask[v]&(1<<rev[d])))throw Error("non-reciprocal "+j+":"+d);
    if(!found[v]){found[v]=total;queue[end++]=v;}
    else if(found[v]!==total)throw Error("inconsistent component");
   }
  }
  largest=Math.max(end,largest);
 }
 if(total>262143)throw Error("too many components");
 const packed=[];
 for(const [k,v] of tiles.entries())if(v){
  const X=Math.floor(k/ny)*C,Y=k%ny*C;
  const runs=[];
  let previous=-1,count=0;
  for(let i=0;i<v.length;i++){
   const label=found[(X+Math.floor(i/C))*stride+Y+i%C];
   if(label===previous&&count<4095)count++;
   else{if(count)runs.push(code(count,2)+code(previous,3));previous=label;count=1;}
  }
  if(count)runs.push(code(count,2)+code(previous,3));
  packed.push("  ["+(k+1)+"]="+JSON.stringify(runs.join(""))+",");
 }
 return {packed,valid,total,largest};
}
module.exports={decode};
if(require.main===module){
let lines=["-- SPDX-License-Identifier: GPL-3.0-or-later","-- Reachability labels derived from NQTDB's verified dry edges.","local _,AT=...","AT.NQTDB.DryComponents={"];
for(const w of [0,1,2991]){
 const fn=w===2991?"NQTDBRouteTiles.lua":"NQTDBRouteWorld"+w+".lua";
 const d=decode(w,fs.readFileSync(p.join(root,fn),"utf8"));
 const r=components(d);
 console.log(JSON.stringify({world:w,tiles:r.packed.length,traversable:r.valid,components:r.total,largest:r.largest}));
 lines.push(" ["+w+"]={",...r.packed," },");
}
lines.push("}","");
fs.writeFileSync(output,lines.join("\n"));
}
