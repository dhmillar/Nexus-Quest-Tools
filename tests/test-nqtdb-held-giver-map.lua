local AT={db={enabled=true},char={}}
local held,actual,ready,offers,side=false,false,false,false,"Horde"
function UnitFactionGroup()return side end
function GetLocale()return "enUS" end
function UnitLevel()return 52 end
function UnitClass()return "Warrior","WARRIOR",1 end
function UnitRace()return "Orc","Orc",2 end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
C_Timer={After=function()end}
C_Map={
    GetBestMapForUnit=function()return 1454 end,
    GetMapInfo=function(m)
        if m==1454 then return {mapType=3,name="Orgrimmar"} end
        if m==1435 then return {mapType=3,name="Swamp of Sorrows"} end
    end,
}
C_QuestLog={
    GetQuestsOnMap=function(m)
        return offers and m==1454 and {{questID=8417,x=.8015,y=.324,isQuestStart=true}} or {}
    end,
    IsOnQuest=function(q)return actual and q==8417 end,
    ReadyForTurnIn=function(q)return ready and q==8417 end,
    IsQuestFlaggedCompleted=function()return false end,
    GetAllCompletedQuestIDs=function()return {} end,
}
AT.GetLevelGuideQuestLog=function()
    if held then return {[8417]={title="A Troubled Spirit",level=52}} end
    return {}
end
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","ForeverVerifiedEndpoints","NQTDB","LevelGuide","Quests"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
assert(AT.ForeverLevelGuideQuests[8417][3]==0 and AT.NQTDB.Starts[8417][1][5]==3354)
local function find()
    for _,p in ipairs(AT.BuildLevelGuide(52,1).places)do
        for _,q in ipairs(p.quests)do if q.id==8417 then return q,p.map end end
    end
end
assert(not find(),"catalog-only quest without eligibility proof is not recommended")
held=true;assert(not find(),"stale HUD row alone cannot import the start map")
actual=true
local row,map=find()
assert(row and row.status=="In log" and map==1454 and row.giver.map==1454 and row.giver.npc==3354 and row.giver.name=="Sorek")
assert(row.giver.x==.8015 and row.giver.y==.324)
ready=true
assert(find().status=="Turn in")
local m,x,y,npc,click=AT.GetReadyQuestTurnInPoint(8417)
assert(m==1435 and x==.3425 and y==.6599 and npc=="Fallen Hero of the Horde" and click,
    "ready turn-in uses exact independent finisher, never the starting Sorek")
ready=false;side="Alliance"
assert(not find(),"recorded Horde starter does not classify an Alliance quest")
held,actual=false,false;side="Horde";offers=true
assert(find().status=="Pick up","true live native offer is independently placed")
print("PASS exact standalone Sorek start places held quest without AreaTable; unheld/stale/faction guards, separate ready finisher")
