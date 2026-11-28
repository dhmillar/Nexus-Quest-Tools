local AT={}
local side="Alliance"
local held,offers={},{},{}
function UnitLevel()return 10 end
function UnitFactionGroup()return side end
function GetLocale()return "enUS" end
C_Map={GetBestMapForUnit=function()return 1411 end,
    GetMapInfo=function(m)if m==1411 then return {name="Durotar",mapType=3} end
        if m==1453 then return {name="Stormwind City",mapType=3} end end}
C_QuestLog={IsQuestFlaggedCompleted=function()return false end,
    GetAllCompletedQuestIDs=function()return {} end,
    GetQuestsOnMap=function(m)return offers[m] or {} end,
    GetTitleForQuestID=function(q)return q==137 and "Native offer with current title" end}
AT.GetLevelGuideQuestLog=function()return held end
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","NQTDB","LevelGuide"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
assert(AT.ForeverLevelGuideQuests[137][9]:match("^<NYI>") and AT.ForeverLevelGuideQuests[807][9]=="<UNUSED>")
local function get(q)
    for _,p in ipairs(AT.BuildLevelGuide(10,1).places)do
        for _,v in ipairs(p.quests)do if v.id==q then return v end end
    end
end
assert(not get(137) and not get(807),"older cache marker can't create a recommendation")
-- The live client, not an old static label, controls actual offers and held quests.
offers[1453]={{questID=137,isQuestStart=true,x=.4,y=.5}}
assert(get(137).status=="Pick up" and get(137).name=="Native offer with current title")
side="Horde"
held[807]={title="Current held title",destination=1411,level=11}
assert(get(807).status=="In log" and get(807).name=="Current held title")
-- Not a fuzzy substring filter: legitimate text mentioning unused objects remains valid.
AT.ForeverLevelGuideQuests[900000]={1,10,14,0,"ffffffffffffffff",5,1,0,"Recover the unused plans",{{2,403,2}}}
assert(get(900000))
AT.ForeverLevelGuideQuests[900000][9]="[DNT] Internal tracker"
assert(not get(900000))
print("PASS real Level Guide excludes explicit placeholders; preserves held, native live, and legitimate titles")
