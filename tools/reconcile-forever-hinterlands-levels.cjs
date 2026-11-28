"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const [file,nqt]=process.argv.slice(2);
const raw=fs.readFileSync(file);
const hash=crypto.createHash("sha256").update(raw).digest("hex");
if(hash!=="8048fa65bb8ac0ec088b47a6fcd2ee000df05664535ab32a49a52dd80ca6994b")throw Error("Unexpected pinned 71139 quest export");
const d=JSON.parse(raw);
if(d.meta?.product!=="wowf"||d.meta?.dataset!=="quests"||d.meta?.clientBuild!=="1.60.1.71139"||
 d.meta?.license!=="CC BY 4.0"||d.meta?.locale!=="enUS")throw Error("Wrong source quest metadata");
const names=["LevelGuideData.lua","ForeverQuestFacts.lua"];
const [data,facts]=names.map(name=>fs.readFileSync(path.join(nqt,name),"utf8").replace(/\r\n/g,"\n"));
let out=data, fOut=facts;
const patched=[];
for(const qid of [86615,86620]){
 const q=d.quests[qid];
 const row=new RegExp("^ \\["+qid+"\\]=\\{(\\d+),(\\d+),(\\d+),(\\d+),\"([^\"]+)\",(\\d+),([\\d.]+),(\\d+),(\"(?:\\\\.|[^\"\\\\])*\"),\\{(.*)\\}\\},$","m");
 const m=data.match(row);
 if(!q||!m||q.title!==JSON.parse(m[9])||q.minLevel!==+m[1]||q.zoneAreaId!==+m[3]||
    (q.questInfoId??0)!==+m[4]||q.raceMask.toLowerCase()!==m[5]||(q.classMask??0)!==+m[8]||!Number.isSafeInteger(q.level)||q.level<q.minLevel||
    q.rewards?.xpDifficulty!==+m[6]||q.rewards?.xpMultiplier!==+m[7])throw Error("Quest identity drift "+qid);
 const actual=q.objectives.map(r=>r.type==="item"&&[2,r.objectId,r.amount]);
 const current=[...m[10].matchAll(/\{(\d+),(\d+),(\d+)\}/g)].map(r=>r.slice(1).map(Number));
 if(!actual.length||actual.includes(false)||JSON.stringify(actual)!==JSON.stringify(current))throw Error("Quest objectives drift "+qid);
 const f=facts.match(new RegExp("^ \\["+qid+"\\]=\\{(\\d+),(\\d+),([^\n]+)$","m"));
 const stamp=" ["+qid+"]={"+m[1]+",";
 const required=actual.map(r=>"{"+r[1]+","+r[2]+"}").join(",")+"},";
 if(!f||f[1]!==m[1]||f[2]!==m[2]||f[3]!==required)throw Error("Incomplete parallel facts "+qid);
 out=out.replace(m[0],m[0].replace(stamp+m[2],stamp+q.level));
 fOut=fOut.replace(f[0],f[0].replace(stamp+f[2],stamp+q.level));
 patched.push([qid,q.level]);
}
for(const [i,text] of [out,fOut].entries())fs.writeFileSync(path.join(nqt,names[i]),text);
console.log(JSON.stringify({source:"Efficient Games CC BY 4.0",hash,patched}));
