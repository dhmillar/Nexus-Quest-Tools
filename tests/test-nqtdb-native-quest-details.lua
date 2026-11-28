local AT={db={enabled=true},char={}}
local held,live={},{}
function GetLocale()return "enUS" end
function UnitFactionGroup()return "Alliance" end
function UnitLevel()return 60 end
local book={}
C_Map={GetBestMapForUnit=function()return 1423 end,GetMapInfo=function(id)
    if id==1423 then return {name="Eastern Plaguelands",mapType=3} end end}

C_QuestLog={IsOnQuest=function(q)return held[q]==true end,GetQuestObjectives=function(q)return live[q] end,
    IsQuestFlaggedCompleted=function()return false end,GetAllCompletedQuestIDs=function()return {} end}
C_Item={GetItemNameByID=function(i)
    if i==13890 then return "Plated Armorfish" end
    if i==22623 then return "Craftsman's Writ - Plated Armorfish" end
    return "Item "..i
end}
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","NQTDB","LevelGuide","QuestHUD"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local ids={8951,9008,9012,9205,84196}
for _,id in ipairs(ids)do
    assert(not AT.ForeverLevelGuideQuests[id] and not AT.ForeverQuestFacts[id],"don't recommend unverified outside the log")
    assert(#AT.GetLevelGuideObjectiveRows(id)==0 and #AT.GetLevelGuideRewardRows(id)==0)
    held[id]=true
    local a,b=AT.GetLevelGuideObjectiveRows(id)
    assert(not b and #a>=2 and a[1].kind=="collect")
    assert(#AT.GetLevelGuideRewardRows(id)>=2)
end
book[9205]={title="Craftsman's Writ - Plated Armorfish"}
AT.GetLevelGuideQuestLog=function()return book end
local found
for _,place in ipairs(AT.BuildLevelGuide(60,1).places)do
    for _,q in ipairs(place.quests)do
        if q.id==9205 then found=q end
    end
end
assert(found and found.status=="In log" and found.level==60 and found.items==31,
    "real held source-only quest appears in its known guide area with 31 exact required items")
local rows=AT.GetLevelGuideObjectiveRows(9205)
assert(rows[2].item==13890 and rows[2].text=="Plated Armorfish: 0/30")
local r=AT.GetLevelGuideRewardRows(9205)
assert(r[1].text=="Choose one" and r[2].item==22524 and r[3].item==22523)
local item=AT.ResolveRankQuestObjectiveItem
assert(item(9205,{type="item",numRequired=30},"Plated Armorfish: 4/30")==13890)
assert(not item(9206,{type="item",numRequired=30},"Plated Armorfish: 4/30"))
live[9205]={{type="item",itemID=13890,text="Plated Armorfish: 4/30",finished=false}}
local actual,fromGame=AT.GetLevelGuideObjectiveRows(9205)
assert(fromGame and actual[1].text=="Plated Armorfish: 4/30" and #actual==1,"native progress never mixed with static 0/30")
held[9205]=false;live[9205]=nil
assert(not item(9205,{type="item",numRequired=30},"Plated Armorfish: 4/30"))
print("PASS five exact held-only quest detail sets and 11 item links, live progress/rank item resolver, native-only policy")
