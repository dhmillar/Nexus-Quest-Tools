local AT={db={rankQuestLegacyDropRates=false}}
local locale="enUS"
function GetLocale()return locale end
function IsInGroup()return false end
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","NQTDB","QuestMobs","QuestHUD"}) do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local n=0
for q,items in pairs(AT.NQTDB.NamedObjectPickups) do
    assert(AT.ForeverLevelGuideQuests[q] and AT.ForeverQuestFacts[q])
    for item,links in pairs(items) do
        local relevant
        local facts=AT.ForeverQuestFacts[q]
        for k=3,#facts do if facts[k][1]==item then relevant=true end end
        assert(relevant and #links==1)
        local name,id=AT.GetQuestLootObjectName(q,item)
        assert(id==links[1][1] and name==links[1][2])
        assert(AT.GetRankQuestDropRateSuffix(q,item)=="","thin source never manufactures a rate")
        n=n+1
    end
end
local name,id=AT.GetQuestLootObjectName(95775,270308)
assert(name=="The First Tablet of I'lalai" and id==642943)
assert(not AT.GetQuestLootObjectName(95776,270308))
assert(not AT.GetQuestLootObjectName(95775,270312) and not AT.GetQuestLootObjectName(95775,"270308"))
locale="deDE"
assert(not AT.GetQuestLootObjectName(95775,270308))
assert(n==17 and AT.NQTDB.NamedObjectPickups[98283]==nil)
print("PASS 17 exact game-object loot source hints for existing quest items, no rates, locales and IDs")
