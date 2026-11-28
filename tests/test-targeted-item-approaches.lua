local AT={db={enabled=true},char={}}
local focus,map,item,held,ready,complete,inside,stock,public=true,1413,5068,true,false,false,false,nil,1
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function IsInInstance()return inside,inside and "party" or "none" end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return map end,GetMapInfo=function()return {mapType=3}end,
    GetMapWorldSize=function()return 1000,1000 end,
    GetPlayerMapPosition=function()return {GetXY=function()return .5,.45 end} end}
local target=3737
C_QuestLog={IsOnQuest=function(q)return q==877 and held end,ReadyForTurnIn=function()return ready end,
    GetQuestObjectives=function()return {{type="gameObject",objectID=target,numRequired=1,finished=complete}} end,
    GetNextWaypointForMap=function()if stock then return .42,.63 end end}
C_SuperTrack={GetSuperTrackedQuestID=function()return focus and 877 end}
C_Item={GetItemCount=function(i,bank,alt)assert(i==item and bank==false and alt==false);return public end}
for _,f in ipairs({"NQTDB","Quests"})do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
local r=assert(AT.NQTDB.TargetedItemApproaches[877][1])
assert(r[1]=="object" and r[2]==3737 and r[3]==1 and r[5]==5068 and #r[4]==2)
local navigation,points,backups=AT.GetFocusedQuestRouteTargets(map)
assert(navigation==877 and #points==2 and #backups==0 and points[1].x==.5555)
stock=true
navigation,points,backups=AT.GetFocusedQuestRouteTargets(map)
assert(navigation==877 and #points==1 and points[1].x==.42 and #backups==2)
stock=nil
local q,m,x,y,label=AT.GetFocusedQuestRoutePoint()
assert(q==877 and m==1413 and x==.5555 and y==.4268 and label=="observed objective area")
local function reject()
    local _,p,b=AT.GetFocusedQuestRouteTargets(map)
    assert((not p or #p==0) and (not b or #b==0))
end
public=0;reject();public=1
local secret={}
function issecretvalue(v)return v==secret end
public=secret; reject();public=1
target=3738;reject();target=3737
complete=true;reject();complete=false
held=false;reject();held=true
ready=true;reject();ready=false
inside=true;reject();inside=false
map=1436;reject()
assert(not AT.NQTDB.TargetedItemApproaches[6381],"mixed-target record cannot supply source positions")
print("PASS documented Stagnant Oasis approaches are available only for exact held quest with Dried Seeds, native point still first")
