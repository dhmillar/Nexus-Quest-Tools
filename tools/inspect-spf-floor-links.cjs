"use strict";
const fs=require("node:fs"), path=require("node:path"), zlib=require("node:zlib");
const [nav,output]=process.argv.slice(2);
const digits="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const n=67,cap=n*n,dx=[1,-1,0,0,1,1,-1,-1],dy=[0,0,1,-1,1,-1,1,-1];
function reader(bytes,start=0,end=bytes.length){
 let p=start;
 return {get next(){return p},get done(){return p===end},jump(to){
  if(!Number.isInteger(to)||to<p||to>end)throw Error("invalid stream cursor");p=to;
 },read(width=1){
  let out=0;
  while(width--){if(p>=end)throw Error("short stream");const q=digits.indexOf(String.fromCharCode(bytes[p++]));if(q<0)throw Error("invalid digit");out=64*out+q;}
  return out;
 },delta(){const i=this.read();return i<63?i:63+this.read(3)}};
}
function landingList(r){
 const mask=r.read();
 if(mask===0){
  const count=r.read(2);
  if(count<1||count>64)throw Error("invalid count of landings");
  return Array.from({length:count},()=>r.read());
 }
 return Array.from({length:6},(_,i)=>i).filter(i=>mask&(1<<i));
}
function scan(bytes,S,emit){
 const r=reader(bytes),extras=r.read(3),byCell=new Map(),rows=[],links=[];
 let loc=0;
 for(let i=0;i<extras;i++){
  loc+=r.delta();const v=r.read(),h=r.read(2)-2048,mask=r.read(2);
  if(loc>=cap||v<1||v>2||mask>255)throw Error("invalid extra-layer header");
  const ordinal=(byCell.get(loc)||0)+1;byCell.set(loc,ordinal);
  rows.push({loc,ordinal,h:h*2,v,mask,node:cap+i});
  S.surfaces++;S[v===1?"drySurfaces":"wetSurfaces"]++;
 }
 const baseLinks=r.read(3);loc=0;
 for(let i=0;i<baseLinks;i++){
  loc+=r.delta();
  const mask=r.read(2);
  if(loc>=cap||mask>255)throw Error("invalid lower-layer header");
  rows.push({loc,ordinal:0,mask,node:loc});
 }
 const olen=r.read(3), op=r.next;
 const overrides=reader(bytes,op,op+olen);
 r.jump(op+olen);
 let redirection=overrides.done?Infinity:overrides.delta();
 let ordinal=0;
 for(const row of rows){
  const x=Math.floor(row.loc/n),y=row.loc%n;
  for(let d=0;d<8;d++)if(row.mask&(1<<d)){
   const X=x+dx[d],Y=y+dy[d],local=X>=0&&Y>=0&&X<n&&Y<n;
   const other=local?(byCell.get(X*n+Y)||0):null;
   const defaultLayer=other===null?null:row.ordinal===0?(other===1?1:null):other===0?0:null;
   let landings;
   if(defaultLayer===null)landings=landingList(r);
   else{
    ordinal++;
    if(ordinal===redirection){
     landings=landingList(overrides);
     S.overrides++;
     redirection=overrides.done?Infinity:redirection+overrides.delta();
    }else{landings=[defaultLayer];S.implicit++;}
   }
   for(const to of landings){
    if(emit)links.push({row,d,to});
    if(local&&to>other)S.unknownLocalLanding++;
    S.links++;
    if(!local)S.crossTile++;
    else if(row.ordinal===0)S.lowerToUpper++;
    else if(to===0)S.upperToLower++;
    else S.upperToUpper++;
   }
  }
 }
 if(!overrides.done||redirection!==Infinity)throw Error("unused override record");
 const drops=r.read(3);
 S.drops+=drops;
 for(let i=0;i<drops;i++){
  const src=r.read(3),x=r.read(),y=r.read(),k=r.read(),len=r.read(2);
  if(src>=cap+extras||x>16||y>16||k>63||!len)S.dropReview++;
 }
 const tail=bytes[r.next],stride=cap+extras;
 const flagsAt=r.next;
 if(tail===126){
  const rem=bytes.length-r.next-1;
  if(rem%(1+2*stride))throw Error("misaligned multi-layer clearance planes");
  S.planes+=rem/(1+2*stride);
 }else{
  if(tail===33){r.jump(r.next+1+2*stride);S.planes++;}
  let node=0;
  while(!r.done){node+=r.delta();r.read(2);if(node>=cap+extras)throw Error("sparse clearance out of range");S.sparseFlags++;}
 }
 if(emit)emit({rows,links,flagsAt,tail,stride,bytes});
}
module.exports={scan,n,cap,dx,dy,digits};
if(require.main===module){
const totals={};
for(const world of [0,1,2991]){
 const total={tiles:0,surfaces:0,drySurfaces:0,wetSurfaces:0,links:0,crossTile:0,upperToLower:0,lowerToUpper:0,upperToUpper:0,unknownLocalLanding:0,overrides:0,implicit:0,drops:0,dropReview:0,planes:0,sparseFlags:0};
 const prefix="Nav"+world;
 const header=fs.readFileSync(path.join(nav,prefix+".lua"),"utf8");
 const expected=+header.match(/counts\s*=\s*\{[^}]*\bfloor\s*=\s*(\d+)/)?.[1];
 const seen=new Set();
 for(const f of fs.readdirSync(nav).filter(f=>new RegExp("^"+prefix+"_[0-9]+\\.lua$").test(f))){
  const raw=fs.readFileSync(path.join(nav,f),"utf8");
  for(const m of raw.matchAll(/^data\.packed\.floor\[(\d+)\]\s*=\s*\{([^}]+)\}/gm)){
   if(seen.has(m[1]))throw Error("duplicate floor tile");
   seen.add(m[1]);total.tiles++;
   const packed=Buffer.concat([...m[2].matchAll(/"([A-Za-z0-9+/=]+)"/g)].map(b=>zlib.inflateSync(Buffer.from(b[1],"base64"),{maxOutputLength:4e6})));
   try{scan(packed,total)}catch(e){throw Error(f+" tile "+m[1]+": "+e.message);}
  }
 }
 if(total.tiles!==expected)throw Error("floor tile count mismatch");
 totals[world]=total;
}
const json=JSON.stringify(totals,null,2);
if(output)fs.writeFileSync(output,json+"\n");
console.log(json);
}
