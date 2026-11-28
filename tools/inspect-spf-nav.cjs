"use strict";
const fs=require("node:fs"),path=require("node:path"),z=require("node:zlib");
const src=process.argv[2], dest=process.argv[3];
const kinds=["graph","grid","height","floor","terrain","ceiling"];
const chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
function leb(buf,c,end,base=128){
 let out=0,factor=1;
 for(let i=0;i<7&&c.p<end;i++){
  const raw=buf[c.p++],sym=base===128?raw:chars.indexOf(String.fromCharCode(raw));
  if(sym<0||sym>=base*2)throw Error("invalid encoded digit");
  out+=(sym%base)*factor;
  if(sym<base)return out;
  factor*=base;
 }
 throw Error("unterminated or oversized integer");
}
function graph(buf){
 const cursor={p:0};
 const count=leb(buf,cursor,buf.length);
 if(count>4096)throw Error("graph row count");
 const parts=Array.from({length:12},()=>leb(buf,cursor,buf.length));
 if(cursor.p+parts.reduce((sum,n)=>sum+n,0)!==buf.length)throw Error("graph stream lengths do not account for payload");
 return count;
}
function terrain(buf,cap){
 let last=-1,records=0;
 for(let p=0;p<buf.length;){
  const num=()=>{const v=chars.indexOf(String.fromCharCode(buf[p++]));if(v<0)throw Error("terrain symbol");return v};
  const d=num();
  last+=d===63?64+num()*4096+num()*64+num():1+d;
  const layer=num();
  if(last<0||last>=cap||layer>63)throw Error("terrain record range");
  records++;
 }
 return records;
}
function ceiling(buf,cap){
 const c={p:0};let id=-1,records=0,roof=0;
 while(c.p<buf.length){
  id+=leb(buf,c,buf.length,32);
  const v=leb(buf,c,buf.length,32);
  if(id<0||id>=cap*64)throw Error("ceiling slot range "+id);
  records++;
  roof+=v%2;
 }
 return [records,roof];
}
const report={};
for(const w of [0,1,2991]){
 const name="Nav"+w;
 const header=fs.readFileSync(path.join(src,name+".lua"),"utf8");
 const read=k=>+header.match(new RegExp("\\b"+k+"\\s*=\\s*(-?\\d+)\\s*,?"))?.[1];
 const [nx,ny,s]=["nx","ny","cells"].map(read);
 if(![nx,ny,s].every(Number.isInteger)||s!==67)throw Error("unexpected grid");
 const countBlock=header.match(/counts\s*=\s*\{[^}]+\}/)?.[0];
 if(!countBlock)throw Error("missing counts");
 const expected=Object.fromEntries(kinds.map(k=>[k,+countBlock.match(new RegExp("\\b"+k+"\\s*=\\s*(\\d+)"))?.[1]]));
 const stats=Object.fromEntries(kinds.map(k=>[k,{tiles:0,bytes:0,records:0,structureCeilings:0}]));
 const done=new Set();
 const files=fs.readdirSync(src).filter(f=>new RegExp("^"+name+"_[0-9]+\\.lua$").test(f));
 for(const fname of files){
  const body=fs.readFileSync(path.join(src,fname),"utf8");
  for(const m of body.matchAll(/^data\.packed\.(\w+)\[(\d+)\]\s*=\s*\{([^}]+)\}/gm)){
   const [,kind,index,payload]=m;
   if(!stats[kind]||+index<1||+index>nx*ny||done.has(kind+index))throw Error("unexpected packed tile "+kind+":"+index);
   const raw=Buffer.concat([...payload.matchAll(/"([A-Za-z0-9+/=]+)"/g)].map(s=>z.inflateSync(Buffer.from(s[1],"base64"),{maxOutputLength:8e6})));
   if(!raw.length)throw Error("empty stream");
   const row=stats[kind];row.tiles++;row.bytes+=raw.length;done.add(kind+index);
   if(kind==="graph")row.records+=graph(raw);
   if(kind==="terrain")row.records+=terrain(raw,s*s);
   if(kind==="ceiling"){
    const [total,roof]=ceiling(raw,s*s);
    row.records+=total;row.structureCeilings+=roof;
   }
  }
 }
 for(const k of kinds)if(stats[k].tiles!==expected[k])throw Error("stream count mismatch "+w+":"+k+" "+stats[k].tiles+"/"+expected[k]);
 report[w]={files:files.length,streams:stats};
}
const result=JSON.stringify(report,null,2);
console.log(result);
if(dest)fs.writeFileSync(dest,result+"\n");
