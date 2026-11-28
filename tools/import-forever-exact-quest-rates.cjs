"use strict";
const fs=require("node:fs"),path=require("node:path");
const [baseline,source,nqt]=process.argv.slice(2);
const read=f=>fs.readFileSync(path.join(nqt,f),"utf8").replace(/\r\n/g,"\n");
const name="exact quest corpse rates",a="-- BEGIN NQTDB "+name+" (generated)",z="-- END NQTDB "+name;
const db=read("NQTDB.lua"), base=db.replace(new RegExp(a.replace(/[()]/g,"\\$&")+"\n[\\s\\S]*?"+z+"\n"),"");
const header="quest_id\tobjective_item_id\tmob_source\tobject_witness\tknown_vendor\tshown_solo_without_classic\tshown_party_without_classic\tclassic_fallback";
const [h,...rows]=fs.readFileSync(baseline,"utf8").trim().split(/\r?\n/);
if(h!==header||rows.length<2000)throw Error("Need baseline production loot audit");
const gaps=new Map(rows.map(r=>r.split("\t")).map(r=>[r[0]+":"+r[1],r]));
const [currentBuild,currentFile]=["1.60.1.71139","1.60.1.71139-quests.enUS.json"];
const cur=JSON.parse(fs.readFileSync(path.join(source,currentFile),"utf8"));
function validate(d,build,dataset){if(d.meta?.dataset!==dataset||d.meta.product!=="wowf"||d.meta.license!=="CC BY 4.0"||d.meta.clientBuild!==build)throw Error("Unexpected "+dataset+" revision "+build);}
validate(cur,currentBuild,"quests");
if(cur.meta.locale!=="enUS")throw Error("Unexpected quest locale");
const latestItems=new Map();
for(const [q,r] of Object.entries(cur.quests))latestItems.set(+q,new Set(r.objectives?.filter(o=>o.type==="item"&&o.amount>0).map(o=>o.objectId)));
const shelf=new Map(),int=(n,min=0)=>Number.isSafeInteger(n)&&n>=min;
let exportsRead=0;
for(const f of fs.readdirSync(source).filter(x=>/^1\.60\.1\.\d+-loot\.json$/.test(x)).sort()){
 const build=f.split("-")[0],d=JSON.parse(fs.readFileSync(path.join(source,f),"utf8"));validate(d,build,"loot");
 if(d.format!==3)throw Error("Expected loot schema 3");
 exportsRead++;
 for(const [k,r] of Object.entries(d.sources??{})){
  const m=k.match(/^npc:(\d+)\|quest(\|group)?$/);if(!m)continue;
  const mode=m[2]?1:0,npc=+m[1];
  for(const [q,b] of Object.entries(r.quests??{}))for(const [i,s] of Object.entries(b.items??{})){
   const item=+i,gap=gaps.get(q+":"+i);
   if(!gap||+gap[5+mode]||+gap[4]||!latestItems.get(+q)?.has(item)||!int(b.windows,12)||!int(s.drops,2)||s.drops>b.windows||(s.shared??0)!==0||!int(b.sources,1))continue;
   // Recalculate the published expected per-kill rate from same-quest
   // known-death counts. Group rates use the same build's matching solo
   // count as documented upstream; no overall-corpse or plain window mix.
   const death=d.kills?.["npc:"+m[1]+"|quest"]?.quests?.[q];
   if(!int(death?.deaths)||!int(death?.unknown)||!int(death?.empty)||!int(death?.sources,1))continue;
   const n=death.deaths-death.unknown,nonempty=n-death.empty;
   if(n<12||nonempty<1||typeof s.chance!=="number")continue;
   const recon=s.drops/b.windows*nonempty/n;
   if(!(recon>0&&recon<=1)||Math.abs(recon-s.chance)>.0000500001)continue;
   const key=[q,i,mode,npc].join(":");
   const one={q:+q,item,mode,npc,build,windows:b.windows,drops:s.drops,known:n,nonempty};
   const old=shelf.get(key);
   // Never pool builds or silently reuse the same contributors as more samples.
   if(!old||Math.min(old.windows,old.known)<=Math.min(one.windows,one.known))shelf.set(key,one);
  }
 }
}
if(exportsRead<15||latestItems.size<3000||shelf.size<5)throw Error("Incomplete source corpus: "+[exportsRead,latestItems.size,shelf.size].join(","));
const pack=new Map();
for(const r of [...shelf.values()].sort((a,b)=>a.q-b.q||a.item-b.item||a.mode-b.mode||a.npc-b.npc)){
 const q=pack.get(r.q)??pack.set(r.q,new Map()).get(r.q), i=q.get(r.item)??q.set(r.item,[[],[]]).get(r.item);
 i[r.mode].push([r.npc,r.drops,r.windows,r.nonempty,r.known,+r.build.split(".").at(-1)]);
}
const out=[a,"-- Exact quest-conditioned rate evidence from Efficient Games Forever, CC BY 4.0.",
 "-- https://github.com/JIVESCORP/eg-link-output-wowf/blob/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/DATASETS.md#loot",
 "-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/",
 "-- Current-mode estimates only: {npc,drops,windows,nonempty known deaths,known deaths,build}.",
 "db.ExactQuestCorpseRates={"];let pairs=0,counts=[0,0];
for(const [q,items] of pack){
 const rr=[];
 for(const [i,m] of items){
  pairs++;
  rr.push("["+i+"]={"+m.map((rows,mode)=>{if(!rows.length)return "";counts[mode]++;return "["+mode+"]={"+rows.map(r=>"{"+r.join(",")+"}").join(",")+"}";}).filter(Boolean).join(",")+"}");
 }
 out.push(" ["+q+"]={"+rr.join(",")+"},");
}
out.push("}",z,"");
fs.writeFileSync(path.join(nqt,"NQTDB.lua"),base+out.join("\n"));
console.log(JSON.stringify({exportsRead,quests:pack.size,pairs,solo:counts[0],group:counts[1],sources:shelf.size}));
