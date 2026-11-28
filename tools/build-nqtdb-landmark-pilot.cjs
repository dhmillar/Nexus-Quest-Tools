"use strict";
// Experimental admissible lower bounds from intra-region landmark intervals.
// This does not supply route geometry or alter existing walkability.
const fs=require("node:fs"), path=require("node:path");
const {decode}=require("./build-nqtdb-dry-components.cjs");
const [root="NQT",target="landmark-candidate-local.lua",worldArg]=process.argv.slice(2);
const alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const Xd=[1,-1,0,0,1,1,-1,-1],Yd=[0,0,1,-1,1,-1,1,-1];
const TILE=16, UNSEEN=0xffffffff;
const flag=i=>1<<i;
function char64(s,k){const d=alphabet.indexOf(s[k]);if(d<0)throw Error("non-Base64");return d}
function regionMask(d,w,index){
 const height=d.nx*d.C,width=d.ny*d.C, size=width*height;
 const labels=new Uint16Array(size),mask=new Uint8Array(size);
 const part=index.split(" ["+w+"]={")[1]?.split("\n },")[0];
 const packed=new Map([...part.matchAll(/^  \[(\d+)\]="([^"]+)"/gm)].map(r=>[+r[1]-1,r[2]]));
 const stats=new Map(),seed=new Map();
 for(const [k,v] of d.tiles.entries())if(v){
  const row=packed.get(k);
  if(!row)throw Error("missing component tile "+k);
  let offset=0;
  for(let p=0;p<row.length;p+=5){
   const span=char64(row,p)*64+char64(row,p+1);
   const id=char64(row,p+2)*4096+char64(row,p+3)*64+char64(row,p+4);
   if(id>65535)throw Error("unexpected label range");
   if(id)stats.set(id,(stats.get(id)??0)+span);
   for(let i=offset;i<offset+span;i++){
    const X=Math.floor(k/d.ny)*d.C+Math.floor(i/d.C),Y=k%d.ny*d.C+i%d.C, pos=X*width+Y;
    mask[pos]=v[i];labels[pos]=id;
    if(id&&!seed.has(id))seed.set(id,pos);
   }
   offset+=span;
  }
  if(offset!==v.length)throw Error("bad component tile "+k);
 }
 const [id,count]=[...stats].sort((a,b)=>b[1]-a[1])[0];
 return {width,height,mask,labels,id,count,start:seed.get(id)};
}
function find(g,root){
 const distance=new Uint32Array(g.mask.length);distance.fill(UNSEEN);distance[root]=0;
 const heap=[],pri=[];
 function push(k,c){
  let i=heap.length;
  while(i>0){const p=(i-1)>>1;if(pri[p]<=c)break;heap[i]=heap[p];pri[i]=pri[p];i=p;}
  heap[i]=k;pri[i]=c;
 }
 push(root,0);
 while(heap.length){
  const k=heap[0],c=pri[0],id=heap.pop(),cost=pri.pop();
  if(heap.length){
   let i=0;
   while(i*2+1<heap.length){
    let j=i*2+1;if(j+1<heap.length&&pri[j+1]<pri[j])j++;
    if(cost<=pri[j])break;
    heap[i]=heap[j];pri[i]=pri[j];i=j;
   }
   heap[i]=id;pri[i]=cost;
  }
  if(c!==distance[k])continue;
  for(let i=0;i<8;i++)if(g.mask[k]&flag(i)){
   const to=k+Xd[i]*g.width+Yd[i];
   if(g.labels[to]!==g.id)throw Error("component index not exact");
   const alt=c+(i<4?1000:1414); // no greater than deployed edge weights
   if(alt<distance[to]){distance[to]=alt;push(to,alt);}
  }
 }
 return distance;
}
function axis(hash,axes){
 const x=Math.floor(hash/axes.width),y=hash%axes.width;
 return Math.floor(x/TILE)*axes.groups+Math.floor(y/TILE)+1;
}
const index=fs.readFileSync(path.join(root,"NQTDBDryComponents.lua"),"utf8");
const lines=["-- SPDX-License-Identifier: GPL-3.0-or-later","-- Lower bounds from NQTDB exact dry walking topology.","local _,AT=...","AT.NQTDB.DryLandmarks={"];
for(const world of (worldArg?[+worldArg]:[0,1])){
 const raw=fs.readFileSync(path.join(root,"NQTDBRouteWorld"+world+".lua"),"utf8");
 const g=regionMask(decode(world,raw),world,index);
 g.groups=Math.ceil(g.width/TILE);
 const ranges=new Map(),nearest=new Uint32Array(g.mask.length);nearest.fill(UNSEEN);
 let home=g.start;
 const used=[];
 for(let j=0;j<4;j++){
  const ds=find(g,home);
  used.push(home);
  let high=-1,next=home,visited=0;
  for(let i=0;i<ds.length;i++)if(g.labels[i]===g.id){
   const t=ds[i];
   if(t===UNSEEN)throw Error("landmark misses a confirmed node");
   const k=axis(i,g);let a=ranges.get(k);
   if(!a){a=[];ranges.set(k,a);}
   a[2*j]=Math.min(a[2*j]??Infinity,t);
   a[2*j+1]=Math.max(a[2*j+1]??0,t);
   nearest[i]=Math.min(nearest[i],t);
   if(nearest[i]>high){high=nearest[i];next=i;}
   visited++;
  }
  if(visited!==g.count)throw Error("source index count");
  home=next;
 }
 console.log({world,component:g.id,count:g.count,regions:ranges.size,landmarks:used});
 lines.push(" ["+world+"]={component="+g.id+",step="+TILE+",groups="+g.groups+",ranges={");
 for(const k of [...ranges.keys()].sort((a,b)=>a-b)){
  const a=ranges.get(k);
  if(a.length!==8)throw Error("incomplete interval");
  lines.push("  ["+k+"]={"+a.join(",")+"},");
 }
 lines.push(" }},");
}
lines.push("}","");
fs.writeFileSync(target,lines.join("\n"));
