local AT={db={enabled=true,questHUDEnabled=true},char={}}
local active,complete,inst=true,false,false
local live={{type="monster",numRequired=10,finished=false,npcID=6}}
local native=false
function IsInInstance()return inst,inst and "party" or "none" end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end} end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return 1429 end,GetMapInfo=function()return {mapType=3}end,
       GetMapWorldSize=function()return 10000,10000 end,
       GetPlayerMapPosition=function()return {GetXY=function()return .5,.5 end}end}
C_QuestLog={IsOnQuest=function()return active end,ReadyForTurnIn=function()return complete end,
    GetQuestObjectives=function()return live end,GetQuestsOnMap=function()return {} end,
    GetNextWaypointForMap=function()if native then return .7,.8 end end}
for _,f in ipairs({"LevelGuideData","QuestMobData","NQTDB","Quests"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
assert(AT.NQTDB.Quests==AT.ForeverLevelGuideQuests and AT.NQTDB.Creatures==AT.QuestMobData.creatures)
assert(AT.NQTDB.Starts[8417][1][5]==3354)
assert(AT.NQTDB.TurnIns[84398][1][5]==7825)
assert(AT.NQTDB.QuestUses[93404][1][1]==258296)
local spots=AT.GetObservedQuestObjectiveSpots(7,1429)
assert(#spots==6 and spots[1][1]==1429)
local nav=AT.GetQuestNavigationID
AT.GetQuestNavigationID=function()return 7 end
local id,route=AT.GetFocusedQuestRouteTargets(1429)
assert(id==7 and #route==6 and route[1].map==1429)
local id,m,x,y,source=AT.GetFocusedQuestRoutePoint()
assert(id==7 and m==1429 and x and y and source=="observed objective area")
native=true
local _,targets,backup=AT.GetFocusedQuestRouteTargets(1429)
assert(#targets==1 and targets[1].x==.7,"native route wins")
assert(#backup==6 and backup[1].map==1429,"verified observed points are kept separate as walking backups")
native=false
live[1].npcID=999999
assert(#AT.GetObservedQuestObjectiveSpots(7,1429)==0,"wrong live entity")
live[1].npcID=nil
live[2]={type="monster",numRequired=10,finished=false}
assert(#AT.GetObservedQuestObjectiveSpots(7,1429)==0,"ambiguous native objective")
live[2]=nil
assert(#AT.GetObservedQuestObjectiveSpots(7,1429)==6,"unique fallback if client omits ID")
assert(#AT.GetObservedQuestObjectiveSpots(7,1434)==0,"no off-zone guess")
live[1].finished=true
assert(#AT.GetObservedQuestObjectiveSpots(7,1429)==0)
live[1].finished=false
complete=true;assert(not AT.GetObservedQuestObjectiveSpots(7,1429))
complete=false;inst=true;assert(not AT.GetObservedQuestObjectiveSpots(7,1429))
inst=false;active=false;assert(not AT.GetObservedQuestObjectiveSpots(7,1429))
AT.GetQuestNavigationID=nav
print("PASS internal NQTDB catalog and dated sources, native-first objective routes, fail-closed identity and state guards")
