local AT={db={enabled=true},char={}}
local q,map,item,need=10,1446,8593,1
local held,ready,done,inside,native=true,false,false,false,false
local obj
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function IsInInstance()return inside,inside and "party" or "none" end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return map end,GetMapInfo=function()return {mapType=3}end,
    GetMapWorldSize=function()return 1000,1000 end,
    GetPlayerMapPosition=function()return {GetXY=function()return .5,.7 end} end}
C_QuestLog={IsOnQuest=function(x)return held and x==q end,ReadyForTurnIn=function()return ready end,
    GetQuestObjectives=function()return obj or {{type="item",itemID=item,numRequired=need,finished=done}} end,
    GetNextWaypointForMap=function()if native then return .42,.63 end end}
C_SuperTrack={GetSuperTrackedQuestID=function()return q end}
for _,f in ipairs({"NQTDB","Quests"})do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
local id,t,b=AT.GetFocusedQuestRouteTargets(map)
assert(id==10 and #t==3 and #b==0 and t[1].x==.5596,"real Rank Quest navigation with no native route point")
local qid,pointMap,x,y,kind=AT.GetFocusedQuestRoutePoint()
assert(qid==q and pointMap==map and x==.5596 and y==.7124 and kind=="observed objective area")
native=true
id,t,b=AT.GetFocusedQuestRouteTargets(map)
assert(id==10 and #t==1 and t[1].x==.42 and #b==3,"native target first, exact pickup only as routing fallback")
qid,pointMap,x,y,kind=AT.GetFocusedQuestRoutePoint()
assert(qid==q and x==.42 and not kind)
native=false
local function reject(reason)
    local _,r,spare=AT.GetFocusedQuestRouteTargets(map)
    assert((not r or #r==0) and (not spare or #spare==0),reason)
end
held=false;reject("unheld");held=true
ready=true;reject("turn-in");ready=false
done=true;reject("finished");done=false
inside=true;reject("dungeon");inside=false
map=1433;reject("different zone");map=1446
item=8594;reject("wrong live id");item=8593
need=2;reject("wrong count");need=1
obj={{type="item",numRequired=1,finished=false},{type="item",numRequired=1,finished=false}}
reject("same counts with ambiguous identity")
obj=nil
local count,total=0,0
for quest,refs in pairs(AT.NQTDB.ObjectPickupApproaches) do
    for idx,r in pairs(refs) do
        q=quest;map=r[4][1][1];item=r[2];need=r[3];obj={}
        for i=1,idx-1 do obj[i]={type="dummy"} end
        obj[idx]={type="item",itemID=item,numRequired=need,finished=false}
        local spots=AT.GetObservedQuestObjectiveSpots(q,map)
        assert(#spots==#r[4] and #spots>=2 and #spots<=6,quest)
        count=count+1;total=total+#spots
    end
end
assert(count==22 and total==55)
print("PASS 55 observed outdoor approaches for 22 exact item objectives; tracked point resolution, native priority, held/turn-in/finished/map/instance/ambiguous guards")
