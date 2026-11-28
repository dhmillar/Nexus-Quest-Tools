local AT={db={rankQuestLegacyDropRates=true}}
local locale,known="enUS",nil
function GetLocale()return locale end
function IsInGroup()return false end
C_Item={GetItemNameByID=function(i)return known and known[i]end}
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","QuestMobData","EverlootDrops","ClassicQuestDropReferences","ClassicQuestMobReferences","NQTDB","QuestMobs","QuestHUD","LevelGuide"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local o={type="item",numRequired=1}
assert(AT.ResolveRankQuestObjectiveItem(8926,o,"Wildheart Belt: 0/1")==16716)
assert(AT.ResolveRankQuestObjectiveItem(8926,o,"Wildheart Gloves: 0/1")==16717)
assert(not AT.ResolveRankQuestObjectiveItem(8926,o,"Some Other Belt: 0/1"))
assert(not AT.ResolveRankQuestObjectiveItem(1,o,"Wildheart Belt: 0/1"))
assert(AT.ResolveRankQuestObjectiveItem(1,{type="item",numRequired=1,itemID=16716},"Other") == 16716)
known={[16716]="Native live belt"};assert(not AT.ResolveRankQuestObjectiveItem(8926,o,"Wildheart Belt: 0/1"))
assert(AT.ResolveRankQuestObjectiveItem(8926,o,"Native live belt: 0/1")==16716)
known=nil;locale="frFR";assert(not AT.ResolveRankQuestObjectiveItem(8926,o,"Wildheart Belt: 0/1"));locale="enUS"
local shown=AT.GetLevelGuideObjectiveRows(8926)
local match
for _,r in ipairs(shown)do if r.item==16716 and r.text:find("Wildheart Belt",1,true) then match=true end end
assert(match,"Level Guide displays the exact name without item cache")
local names=AT.NQTDB.CurrentColdQuestItemNames
local fixed,mobs,rates=0,0,0
for q,fs in pairs(AT.ForeverQuestFacts)do
 for j=3,#fs do
  local i,n=table.unpack(fs[j])
  if names[i] then
   local obj={type="item",numRequired=n}
   local label=names[i]..": 0/"..n
   if AT.ResolveRankQuestObjectiveItem(q,obj,label)==i then
    AT.NQTDB.CurrentColdQuestItemNames=nil
    local before=AT.ResolveRankQuestObjectiveItem(q,obj,label)
    AT.NQTDB.CurrentColdQuestItemNames=names
    if before~=i then
     fixed=fixed+1
     if AT.GetQuestDropMobNames(i,q) then mobs=mobs+1 end
     if AT.GetRankQuestDropRateSuffix(q,i)~="" then rates=rates+1 end
    end
   end
  end
 end
end
assert(fixed>=100)
print(("PASS live limits and cache-only names; improved actual cold-cache item association for %d quest items (%d known mobs; %d existing rate suffixes)"):format(fixed,mobs,rates))
