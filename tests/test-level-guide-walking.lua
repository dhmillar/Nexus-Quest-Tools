local AT={db={enabled=true,showQuestRoute=true},char={}}
local q,here,dest=777,1420,1421
local held,inside=false,false
local x,y,tx,ty=547.3,1593.1,518,1599.7
local world,targetWorld=0,0
local nativeReads=0
local function vec(a,b)return {GetXY=function()return a,b end}end
function CreateVector2D(a,b)return vec(a,b)end
function IsInInstance()return inside,inside and "party" or "none" end
function UnitPosition()return x,y,0,world end
function GetBuildInfo()return "1.60.1","71139" end
function GetTime()return 10 end
local pending={}
C_Timer={After=function(_,f)pending[#pending+1]=f end}
local function drain()
 local n=0 while #pending>0 do n=n+1;assert(n<350);table.remove(pending,1)()end
end
local function mp(ax,ay)return (ax-x)/42000+.5,(ay-y)/42000+.5 end
C_Map={
 GetBestMapForUnit=function()return here end,
 GetPlayerMapPosition=function()return vec(.5,.5)end,
 GetMapWorldSize=function()return 42000,42000 end,
 GetMapInfo=function(m)return {mapType=m==1999 and 4 or 3}end,
 GetWorldPosFromMapPos=function(m,p)local a,b=p:GetXY();return m==here and world or targetWorld,vec(x+(a-.5)*42000,y+(b-.5)*42000)end,
 GetMapPosFromWorldPos=function(_,p,m)local a,b=p:GetXY();local u,v=mp(a,b);return m,vec(u,v)end,
}
C_QuestLog={IsOnQuest=function(id)return id==q and held end,
 GetNextWaypointForMap=function()nativeReads=nativeReads+1;return .9,.9 end}
C_SuperTrack={GetSuperTrackedQuestID=function()if held then return q end end}
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
for _,f in ipairs({"NQTDBRouteWorld0","NQTDBDryComponents","NQTDBDryLandmarks","NQTDBWalking","LevelGuide","Quests","Walking"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local a,b=mp(tx,ty)
local start={id=q,giver={map=dest,x=a,y=b,name="Known giver"}}
assert(AT.TrackLevelGuideGiver(start))
assert(AT.GetQuestNavigationID()==q)
local selected,goals,backups=AT.GetFocusedQuestRouteTargets(here)
assert(selected==q and #goals==1 and #backups==0 and goals[1].map==dest and goals[1].x==a and goals[1].y==b and nativeReads==0)
local origin={map=here,x=.5,y=.5}
assert(not AT.GetFocusedQuestWalkingPath(q,origin,42000,42000));drain()
local path,goal=AT.GetFocusedQuestWalkingPath(q,origin,42000,42000)
assert(path and goal.map==dest and path.yards>0 and #path.waypoints>2,"actual bundled path to explicitly tracked giver")
local function empty()
 local v,rows=AT.GetFocusedQuestRouteTargets(here)
 assert(v==q and #rows==0 and nativeReads==0)
end
inside=true;empty();inside=false
targetWorld=1;empty();targetWorld=0
assert(AT.TrackLevelGuideGiver(start) and not AT.GetQuestNavigationID())
held=true
local id,normal=AT.GetFocusedQuestRouteTargets(here)
assert(id==q and #normal==1 and normal[1].x==.9 and nativeReads==1)
held=false
local dungeon={id=q,giver={map=1999,x=a,y=b,name="Giver on hidden floor"}}
assert(AT.TrackLevelGuideGiver(dungeon));nativeReads=0;empty()
assert(AT.TrackLevelGuideGiver(dungeon))
assert(AT.TrackLevelGuideGiver({id=q,giver={map=dest,x=a,y=b,pickup=true}}))
assert(not AT.GetQuestNavigationID(),"item-start area is not an NPC start waypoint")
print("PASS actual Level Guide tracking drives the independent terrain engine; priority, remote-world, dungeon and cancellation guards")
