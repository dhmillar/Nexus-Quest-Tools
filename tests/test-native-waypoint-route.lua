-- The native waypoint selection takes the same stand-alone, real terrain
-- path as a tracked quest; no quest/objective APIs receive its internal ID.
local AT={db={enabled=true,showQuestRoute=true},char={}}
local home,dest,x,y=1420,1421,547.3,1593.1
local q,selected,inside,secret=777,false,false,{}
local goal={518,1599.7}
local tw=0
local function vec(a,b)return {GetXY=function()return a,b end}end
local function mp(a,b)return (a-x)/42000+.5,(b-y)/42000+.5 end
CreateVector2D=vec
function GetBuildInfo()return "1.60.1","71139" end
function UnitPosition()return x,y,0,0 end
function GetTime()return 10 end
function IsInInstance()return inside end
function issecretvalue(v)return rawequal(v,secret)end
local pending={}
C_Timer={After=function(_,f)pending[#pending+1]=f end}
local function drain()
 local n=0 while #pending>0 do n=n+1;assert(n<350);table.remove(pending,1)()end
end
C_Map={
 GetBestMapForUnit=function()return home end,
 GetPlayerMapPosition=function()return vec(.5,.5) end,
 GetMapWorldSize=function()return 42000,42000 end,
 GetMapInfo=function(m)return {mapType=m==1999 and 4 or 3}end,
 GetUserWaypoint=function()if goal then return {uiMapID=dest,position=vec(mp(goal[1],goal[2]))} end end,
 GetWorldPosFromMapPos=function(m,p)local a,b=p:GetXY();return m==home and 0 or tw,vec(x+(a-.5)*42000,y+(b-.5)*42000)end,
 GetMapPosFromWorldPos=function(_,p,m)local a,b=p:GetXY();return m,vec(mp(a,b))end,
}
C_SuperTrack={IsSuperTrackingUserWaypoint=function()return selected end}
function AT.GetQuestNavigationID()return q,"order" end
function AT.IsQuestTurnInNavigation(id)assert(id==q);return false end
function AT.GetFocusedQuestRouteTargets()error("waypoints cannot use quest destinations")end
for _,f in ipairs({"NQTDBRouteWorld0","NQTDBDryComponents","NQTDBDryLandmarks","NQTDBWalking","Walking"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
assert(AT.GetWalkingNavigationID()==q,"a placed pin must also be selected")
selected=secret;assert(AT.GetWalkingNavigationID()==q)
selected=true
local key,kind=AT.GetWalkingNavigationID()
assert(key~=q and kind=="waypoint")
local origin={map=home,x=.5,y=.5}
local function walk()return AT.GetFocusedQuestWalkingPath(key,origin,42000,42000)end
assert(not walk());drain()
local path,where=walk()
assert(path and path.yards>0 and #path.waypoints>2 and where.map==dest)
local a,b=mp(goal[1],goal[2]);assert(where.x==a and where.y==b)

-- UI map layouts need not share normalized coordinates. Cross the same
-- verified outdoor path into a neighboring UI map without another search.
local curMap,bump=home,1422
local px,py=x,y
local bumpWorld=0
local baseWF=C_Map.GetWorldPosFromMapPos
local baseMF=C_Map.GetMapPosFromWorldPos
C_Map.GetWorldPosFromMapPos=function(m,p)
 if m~=bump then return baseWF(m,p) end
 local a,b=p:GetXY();return bumpWorld,vec(x+(a-.25)*42000,y+(b-.7)*42000)
end
C_Map.GetMapPosFromWorldPos=function(w,p,m)
 if m~=bump then return baseMF(w,p,m) end
 local a,b=p:GetXY();return m,vec((a-x)/42000+.25,(b-y)/42000+.7)
end
C_Map.GetBestMapForUnit=function()return curMap end
C_Map.GetPlayerMapPosition=function(m)
 local _,p=C_Map.GetMapPosFromWorldPos(0,vec(px,py),m);return p
end
UnitPosition=function()return px,py,0,bumpWorld end
local function region()
 return setmetatable({}, {__index=function()return function()end end})
end
function CreateFrame()
 local f=region();f.CreateLine=region;f.CreateFontString=region;return f
end
Minimap={GetWidth=function()return 170 end,GetHeight=function()return 170 end,GetFrameLevel=function()return 1 end}
function AT.RenderWorldQuestRoute(status,k,snapshot) AT.status,AT.snapshot=status,snapshot end
assert(loadfile("NQT/Route.lua"))("NQT",AT)
AT.InitQuestRoute();drain();AT.RefreshQuestRoute()
local first=assert(AT.snapshot,"already-visible actual route")
path=first.path
local p=path.waypoints[2]
local w,v=C_Map.GetWorldPosFromMapPos(p.map,vec(p.x,p.y));assert(w==0)
px,py=v:GetXY()
curMap=bump
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.snapshot.path==path and AT.status=="routed" and #pending==0,
 "crossing an outdoor map boundary immediately keeps actual verified route and reprojects to the new layout")
inside=true
AT.RefreshQuestRoute()
assert(not AT.snapshot,"an instance must not keep outdoor geometry")
inside=false;curMap=home;px,py=x,y
AT.RefreshQuestRoute();drain();AT.RefreshQuestRoute()
path=assert(AT.snapshot).path
curMap=bump;px,py=x+200,y+200
AT.RefreshQuestRoute()
assert(not AT.snapshot,"a jump off the active path cannot retain previous geometry")
curMap=home;px,py=x,y
AT.RefreshQuestRoute();drain();AT.RefreshQuestRoute()
assert(AT.snapshot)
curMap=bump;bumpWorld=1
AT.RefreshQuestRoute()
assert(not AT.snapshot,"a different world never keeps the previous tile path")
bumpWorld=0;curMap=home
AT.CancelQuestWalking()
print("PASS verified native waypoint route remains continuous across a map seam, rejects interior and other-world transitions")
-- A new pin, a map with no outdoor surface, and a different continent
-- never recycle the old path or draw a guessed crossing.
goal={517,1598.5};assert(not walk());drain()
dest=1999;local r,_,why=walk();assert(not r and why=="objective_missing")
dest=1421;tw=1;assert(not walk());drain()
r,_,why=walk();assert(not r and why=="offmesh")
tw=0;inside=true;r,_,why=walk();assert(not r and (why=="objective_missing" or why=="provider_missing"),tostring(why))
inside=false;goal={518,1599.7};assert(not walk())
goal=nil;drain();assert(AT.GetWalkingNavigationID()==q and not walk(),"late computation cannot republish a cleared waypoint")
goal={518,1599.7}
function AT.GetQuestNavigationID()return q,"guide" end
assert(AT.GetWalkingNavigationID()==q,"Level Guide's own native pin must remain a quest-giver route")
print("PASS native tracked waypoint routes across two zone maps on real bundled terrain, rejects ambiguous/remote/instance pins, cancels a cleared pin, preserves Level Guide")
