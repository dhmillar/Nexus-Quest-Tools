local AT={db={enabled=true,questHUDEnabled=true},char={}}
local q,held,ready,locale,faction,current=736,true,true,"enUS","Horde",1429
local pin
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function UnitFactionGroup()return faction end
function GetLocale()return locale end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return current end,GetMapInfo=function()return {mapType=3}end}
C_QuestLog={IsOnQuest=function(id)return id==q and held end,ReadyForTurnIn=function(id)return id==q and ready end,
    GetQuestsOnMap=function(m)return pin and m==pin.map and {pin} or nil end}
C_SuperTrack={GetSuperTrackedQuestID=function()return q end}
for _,f in ipairs({"ForeverTownPins","ForeverVerifiedEndpoints","NQTDB","Quests"}) do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
for _,t in ipairs({{736,1458,.5371,.5418,"Keeper Bel'dugur"},{7734,1444,.745,.4283,"Jangdor Swiftstrider"},{7738,1444,.745,.4283,"Jangdor Swiftstrider"}})do
    q=t[1]
    local m,x,y,name,click,estimated=AT.GetReadyQuestTurnInPoint(q)
    assert(m==t[2] and x==t[3] and y==t[4] and name==t[5] and click and estimated,q)
    assert(not AT.GetQuestTurnInPoint(q),"no route without native confirmation")
    pin={map=m,questID=q,isQuestStart=false,inProgress=false,x=x+.002,y=y+.002}
    local a,b,c,n,ok,guess=AT.GetReadyQuestTurnInPoint(q)
    assert(a==pin.map and b==pin.x and c==pin.y and n==name and ok and not guess,"native rediscovers exact stock point on hint map")
    assert(AT.GetQuestTurnInPoint(q)==pin.map,"the real native confirmation can route")
    pin={map=current,questID=q,isQuestStart=false,inProgress=false,x=.3,y=.2}
    a,b,c,n=AT.GetReadyQuestTurnInPoint(q)
    assert(a==current and b==.3 and c==.2 and not n,"never label a conflicting native point")
    pin=nil
end
q=736; locale="frFR"
local m,x,y,name,click=AT.GetReadyQuestTurnInPoint(q)
assert(m==1458 and not name and not click)
locale="enUS"; faction="Alliance"; assert(not AT.GetReadyQuestTurnInPoint(q))
faction="Horde"; held=false; assert(not AT.GetReadyQuestTurnInPoint(q))
held=true; ready=false; assert(not AT.GetReadyQuestTurnInPoint(q))
assert(not AT.NQTDB.CorroboratedTurnInLabels[95982] and not AT.NQTDB.CorroboratedTurnInLabels[94679])
print("PASS three exact corroborated outdoor Rank Quest turn-in labels, native priority and guards against false destinations")
