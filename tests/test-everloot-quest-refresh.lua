local AT={db={rankQuestLegacyDropRates=false}}
function IsInGroup()return false end
function GetLocale()return "enUS" end
for _,name in ipairs({"ForeverQuestFacts","LevelGuideData","QuestMobData","EverlootDrops",
    "ClassicQuestDropReferences","ClassicQuestMobReferences","NQTDB","QuestMobs","QuestHUD"}) do
    assert(loadfile("NQT/"..name..".lua"))("NQT",AT)
end
local expected={ {577,4104,"36%","Snapjaw Crocolisk"}, {1110,5798,"100%"}, {94975,267091,"32%"} }
for _,f in ipairs(expected) do
    local q,item,pct,npc=unpack(f)
    assert(AT.GetRankQuestDropRateSuffix(q,item):find(pct,1,true),"expected newly covered quest item "..q..":"..item)
    if npc then
        local names=AT.GetQuestDropMobNames(item,q)
        assert(table.concat(names,";"):find(npc,1,true),"named corpse link follows actual source ID")
    end
end
local pack=AT.ObservedQuestDrops
assert(pack.dates[6]=="2026-11-28 04:50 UTC")
local measured,items,tuples=0,0,0
for _,sources in pairs(pack.items) do
    items=items+1
    for _,r in ipairs(sources) do
        tuples=tuples+1
        if r[5]==6 then
            measured=measured+1
            assert(r[2]>=2 and r[3]>=12 and r[2]<=r[3] and r[4]>=3 and r[4]<=r[3])
        end
    end
end
assert(items>=1170 and tuples==2081 and measured==91)
local before=AT.GetRankQuestDropRateSuffix(577,4104)
AT.ObservedQuestDrops={items={}}
assert(AT.GetRankQuestDropRateSuffix(577,4104)~=before,"fresh observed fallback, not a hardcoded Classic number")
assert(AT.GetRankQuestDropRateSuffix(577,9999999)=="","unknown remains unknown")
print("PASS new exact Forever loot observations, Rank Quest rate and corpse resolution, object witnesses, no guessed percentage")
