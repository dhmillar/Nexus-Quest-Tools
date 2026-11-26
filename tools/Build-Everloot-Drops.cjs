const fs = require('fs');
const live=JSON.parse(fs.readFileSync('everloot-live-rollup.json','utf8'));
const old=fs.readFileSync('everloot-observed-drop-rates.ndjson','utf8').trim().split(/\r?\n/).map(x=>JSON.parse(x));
if (live.rows.length!==live.totalRates || !String(live.asOf).startsWith('2026-11-26')) throw Error('Unverified snapshot');
const bySource=new Map();
function add(r,idx){
 const item=r.itemId, obj=r.sourceObjectId, src=r.sourceNpcId || obj;
 const n=r.lootWindows??r.kills, k=r.windowsWithItem??r.drops, installs=r.installs??r.reporters;
 if(idx===2 && (r.public!==true || r.tier!=='confirmed')) return;
 if(![item,src,n,k,installs].every(Number.isSafeInteger)||item<=0||src<=0||k<=0||n<k||installs<3||n<installs|| (!!obj===!!r.sourceNpcId)) return;
 const key=[item,obj?'object':'npc',src].join(':');
 const prev=bySource.get(key);
 if(prev && prev.row[2]>=20 && n<20) return;
 bySource.set(key,{item,row:[src,k,n,installs,idx,obj?1:0]});
}
old.forEach(r=>add(r,1));live.rows.forEach(r=>add(r,2));
const byItem=new Map();
for(const {item,row} of bySource.values()){
 if(!byItem.has(item))byItem.set(item,[]);
 byItem.get(item).push(row);
}
const sorted=[...byItem].sort((a,b)=>a[0]-b[0]).map(([key,rs])=>[
 key, rs.filter(row=>row[2]>=20 || !rs.some(other=>other[5]===row[5]&&other[2]>=20))
 .sort((a,b)=>a[5]-b[5]||a[0]-b[0])
]);
const header=`-- Data from Everloot (https://everloot.app), CC BY-SA 4.0.
-- License: https://creativecommons.org/licenses/by-sa/4.0/
-- Adaptation: public 3+ install observations, deduplicated, not pooled.
-- https://everloot.app/database/download ; https://everloot.app/docs/api/rollups-drops
-- Row layout: source ID, windows with item, eligible loot windows, installs, snapshot index, object flag.
local _,AT=...
AT.ObservedQuestDrops={
  dates={"2026-11-14", "2026-11-26"},
  items={
`;
fs.writeFileSync('NQT/EverlootDrops.lua',header+sorted.map(([item,rows])=>'    ['+item+']={'+rows.map(r=>'{'+r.join(',')+'}').join(',')+'},').join('\n')+'\n  }\n}\n');
console.log({oldItems:626,items:sorted.length,pairs:sorted.reduce((n,[,r])=>n+r.length,0),objectPairs:sorted.reduce((n,[,r])=>n+r.filter(e=>e[5]).length,0),eye:byItem.get(730),objectFixture:sorted.find(([,r])=>r.every(e=>e[5]))});
