local AT={char={}}
local faction,race="Alliance",1
local held={}
UnitLevel=function()return 41 end
UnitRace=function()return "Human","Human",race end
UnitClass=function()return "Hunter","HUNTER",3 end
UnitFactionGroup=function()return faction end
GetLocale=function()return "enUS" end
C_Map={
    GetBestMapForUnit=function()return 1425 end,
    GetMapInfo=function(id)if id==1425 then return {name="The Hinterlands",mapType=3} end end,
    GetAreaInfo=function(id)if id==348 then return "The Hinterlands" end end,
}
C_QuestLog={
    GetQuestsOnMap=function()return {} end,
    IsQuestFlaggedCompleted=function()return false end,
    GetAllCompletedQuestIDs=function()return {} end,
}
AT.GetLevelGuideQuestLog=function()return held end
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","NQTDB","LevelGuide"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function get(q)
    for _,p in ipairs(AT.BuildLevelGuide(41,1).places)do
        for _,r in ipairs(p.quests)do if r.id==q then return r end end
    end
end
for _,r in ipairs({{86615,"Treaty Obligations",279171,1,"5s"},{86620,"Fledgling Rescue",279229,6,"82s"}})do
    local q=r[1]
    local actual=assert(get(q),"corrected Hinterlands quest absent")
    assert(actual.name==r[2] and actual.level==41 and actual.fits and actual.availableHere,q)
    assert(AT.NQTDB.QuestFacts[q][2]==41 and AT.NQTDB.QuestFacts[q][3][1]==r[3])
    assert(AT.GetLevelGuideRewardRows(q)[1].text==r[5],"direct quest-catalog reward")
    assert(AT.GetLevelGuideObjectiveRows(q)[1].item==r[3],"same objective ID retains current counts")
end
faction,race="Horde",2
assert(not get(86615),"Treaty Obligations keeps exact Alliance restriction")
assert(get(86620),"do not infer a new restriction from NPC observations")
faction,race="Alliance",1
held[86615]={title="Treaty Obligations",level=40,destination=1425}
assert(get(86615).level==40,"native held quest level takes precedence over static data")
print("PASS exact latest Forever Hinterlands quest levels, actual recommendation, faction, rewards and native priority")
