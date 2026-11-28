local AT={db={rankQuestLegacyDropRates=true}}
local locale="enUS"
function GetLocale()return locale end
local active={}
C_QuestLog={GetQuestObjectives=function(q)return active[q]end}
C_Item={}
for _,f in ipairs({"LevelGuideData","LevelGuideObjectiveText","ForeverQuestFacts","QuestMobData","EverlootDrops","ClassicQuestDropReferences","ClassicQuestMobReferences","NQTDB","QuestMobs","QuestHUD","LevelGuide"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function row(q,p)
 for _,r in ipairs(AT.GetLevelGuideObjectiveRows(q))do if p(r) then return r end end
end
local guideInn=row(92514,function(r)return r.text:find("Innkeeper",1,true)end)
assert(guideInn.npc==254089 and guideInn.mob=="Coriella Calmbreeze" and guideInn.display>0 and guideInn.kind=="other")
local allNpc,allPickups=0,0
for q,links in pairs(AT.NQTDB.ExactInteractionObjectives)do
 for _,a in ipairs(links)do
  local option=row(q,function(r)return r.npc==a[2] and r.kind=="other" and r.display and r.text:find(a[3],1,true)end)
  if option then allNpc=allNpc+1 end
 end
end
for q,links in pairs(AT.NQTDB.WitnessedObjectPickups)do
 for i,o in pairs(links)do
  assert(row(q,function(r)return r.item==i and r.source==o[2] and r.kind=="collect"end),
      "current recorded source missing in unaccepted Level Guide "..q.."/"..i)
  allPickups=allPickups+1
 end
end
assert(allNpc==20 and allPickups==37)
active[92514]={{text="Speak with the Innkeeper: 0/1",type="event",objectiveID=468024,finished=false}}
local a,live=AT.GetLevelGuideObjectiveRows(92514)
assert(live and #a==1 and a[1].npc==254089 and a[1].display==guideInn.display)
active[92514][1].npcID=251902
a=AT.GetLevelGuideObjectiveRows(92514);assert(#a==1 and not a[1].npc and not a[1].display)
active[8926]={{type="item",text="Wildheart Gloves: 0/1",numRequired=1}}
a=AT.GetLevelGuideObjectiveRows(8926);assert(a[1].item==16717,"cold exact item source reaches live Guide")
active[95561]={{type="item",text="Apples here: 2/6",itemID=271431,numRequired=6,finished=false}}
a=AT.GetLevelGuideObjectiveRows(95561);assert(a[1].source=="Fresh Apple" and a[1].text=="Apples here: 2/6")
active[95561][1].itemID=271620
a=AT.GetLevelGuideObjectiveRows(95561);assert(not a[1].source,"never map same item's source to a different quest")
local weed=row(99130,function(r)return r.item==286214 end)
assert(weed and weed.source=="Overgrown Duskweed" and weed.kind=="collect")
local blood=row(99130,function(r)return r.item==286215 end)
assert(blood and blood.source~="Overgrown Duskweed","no cross-objective labeling in the unaccepted guide")
active[99130]={{type="item",text="Blood: 0/6",itemID=286215,numRequired=6,finished=false},
 {type="item",text="Petals: 4/18",itemID=286214,numRequired=18,finished=false}}
a,live=AT.GetLevelGuideObjectiveRows(99130)
assert(live and a[1].source~="Overgrown Duskweed" and a[2].source=="Overgrown Duskweed" and a[2].text=="Petals: 4/18")
locale="deDE";active[92514]=nil
a=AT.GetLevelGuideObjectiveRows(92514)
for _,r in ipairs(a)do assert(r.npc~=254089,"English cache not leaked")end
print(("PASS real Level Guide shows %d verified NPC portraits and %d known pickups plus live conflict/cold cache guards"):format(allNpc,allPickups))
