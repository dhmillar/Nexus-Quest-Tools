const fs=require('fs');
const input=fs.readFileSync(process.argv[2],'utf8').replace(/\r\n/g,'\n');
const q=JSON.parse(input);
const crypto=require('crypto');
if(crypto.createHash('sha256').update(input).digest('hex')!=='f9ae9af83c72285e024a83943cf365f1751545c8dce047d1359d30c295b4a621'||q.meta?.license!=='CC BY 4.0'||q.meta?.clientBuild!=='1.60.1.71139'||q.meta?.locale!=='enUS'||q.meta?.dataset!=='quests')throw Error('Unexpected source');
const names=new Map(), counts=new Map();for(const a of fs.readFileSync('NQT/QuestMobData.lua','utf8').matchAll(/^\s*\[(\d+)\]=\{("(?:\\.|[^"\\])*"),\d+,\d+,[^\r\n]*\}/gm)){const name=JSON.parse(a[2]); names.set(+a[1],name);counts.set(name.toLowerCase(),(counts.get(name.toLowerCase())??0)+1);}
const guide=fs.readFileSync('NQT/LevelGuideData.lua','utf8');let seen=0,found=0;
const out=['-- BEGIN NQTDB exact interaction objectives (generated)','-- From Efficient Games build 1.60.1.71139 quest-cache facts (CC BY 4.0).','-- https://github.com/JIVESCORP/eg-link-output-wowf/blob/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf/1.60.1.71139/quests.enUS.json','-- https://efficient.games | https://creativecommons.org/licenses/by/4.0/','-- Exact quest objective ID, creature ID, and canonical English objective label.','db.ExactInteractionObjectives={'];
for(const [id,r] of Object.entries(q.quests)){
 const l=guide.match(new RegExp('^ *\\['+id+'\\]=\\{[^\\n]+','m'))?.[0];
 if(!l?.includes(','+JSON.stringify(r.title)+',{')||/^(Your First |An Epic Ride$)/.test(r.title))continue;
 const a=[];
 for(const o of r.objectives??[]){
  if(o.type!=='talkTo'||o.amount!==1||!Number.isSafeInteger(o.id)||!Number.isSafeInteger(o.objectId)||!o.text||/[|\x00-\x1f]/.test(o.text))continue;
  seen++;
  const n=names.get(o.objectId);if(!n||counts.get(n.toLowerCase())!==1||/^(?:Dead |Corpse )/i.test(n))continue;
  if(r.objectives.filter(x=>x.text?.toLowerCase()===o.text.toLowerCase()).length!==1)continue;
  a.push('{'+[o.id,o.objectId,JSON.stringify(o.text)].join(',')+'}');found++;
 }
 if(a.length)out.push(' ['+id+']={'+a.join(',')+'},');
}
out.push('}','-- END NQTDB exact interaction objectives','');
const dest='NQT/NQTDB.lua';const prior=fs.readFileSync(dest,'utf8');
const db=prior.replace(/\r\n/g,'\n').replace(/-- BEGIN NQTDB exact interaction objectives \(generated\)\n[\s\S]*?-- END NQTDB exact interaction objectives\n/,'');const result=db+out.join('\n');
fs.writeFileSync(dest,prior.includes('\r\n')?result.replace(/\n/g,'\r\n'):result);
console.log({seen,found});
