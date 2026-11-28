local AT={db={enabled=true,showQuestRoute=true}}
local x,inside,t,active=.5,false,10,true
local frames,drawn={},{}
local function nothing() end
local function region()
    return {SetText=function(self,v) self.text=v end,SetPoint=nothing,ClearAllPoints=nothing,SetTextColor=nothing,
        SetThickness=nothing,SetColorTexture=nothing,
        SetStartPoint=function(self,_,_,x,y)self.x=x;self.y=y end,
        SetEndPoint=function(self,_,_,x,y)self.endX=x;self.endY=y end,
        Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
end
function CreateFrame(_,_,parent)
    local f={parent=parent,shown=true,CreateTexture=region,CreateLine=region,SetAllPoints=nothing,
        SetSize=nothing,EnableMouse=nothing,SetFrameLevel=nothing,SetScript=function(self,k,v)self[k]=v end,ClearAllPoints=nothing}
    function f:CreateLine(_,layer)
        local r=region(); if layer=="OVERLAY" then drawn[#drawn+1]=r end; return r
    end
    function f:SetPoint(a,b,c,dx,dy) self.anchor={a,b,c,dx,dy} end
    function f:CreateFontString() local l=region();self.label=l;return l end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    frames[#frames+1]=f
    return f
end
Minimap={GetWidth=function()return 170 end,GetHeight=function()return 170 end,GetFrameLevel=function()return 1 end}
C_Map={GetBestMapForUnit=function()return 20 end,
    GetPlayerMapPosition=function()return {GetXY=function()return x,.5 end} end,
    GetMapWorldSize=function()return 1000,1000 end,
    GetMapInfo=function()return {mapType=3,name="Zone"} end}
function GetTime()return t end
function GetTaskInfo()return inside end
function AT.GetQuestNavigationID() if active then return 981,"test" end end
function AT.GetFocusedQuestRoutePoint()return 981,20,.75,.5 end
function AT.RenderWorldQuestRoute(state,quest,snapshot) AT.worldStatus,AT.snapshot=state,snapshot end
assert(loadfile("NQT/Route.lua"))("NQT",AT)
AT.InitQuestRoute()
local meter,bearing
for _,f in ipairs(frames) do
    assert(not (f.parent==Minimap and f.anchor and f.anchor[1]=="TOP" and f.anchor[3]=="BOTTOM"),"never create the below-minimap panel")
    if f.label and f.label.text=="250 yd" then meter=f end
    if f.core then bearing=f end
end
assert(meter and meter.shown and bearing and bearing.shown,"keep yards and directional guidance")
assert(not bearing.dashes and bearing.core.x==0 and bearing.core.y==0 and bearing.core.endX>0, "render one uninterrupted bearing from center")
assert(bearing.label.text=="DIRECT BEARING ONLY" and AT.snapshot.bearing)
assert(AT.snapshot.from.x==.5 and AT.snapshot.target.x==.75)
function GetCVarBool() return true end
AT.RefreshQuestRoute()
assert(not bearing.shown and AT.snapshot.bearing, "missing heading does not suppress world-map bearing")
GetCVarBool=nil
x=.55;t=t+1;AT.RefreshQuestRoute()
assert(meter.label.text=="200 yd" and bearing.shown)
inside=true;t=t+1;AT.RefreshQuestRoute()
assert(not meter.shown and not bearing.shown and AT.worldStatus=="arrival","arrival still hides guidance")
inside=false;active=false;t=t+1;AT.RefreshQuestRoute()
assert(not meter.shown and not bearing.shown and AT.worldStatus=="no_quest")
local observer=frames[#frames]
assert(observer.OnUpdate)
local refreshes=0
AT.PerfBegin=function()return 1 end
AT.PerfEnd=function(label) if label=="Quest route" then refreshes=refreshes+1 end end
for i=1,20 do observer:OnUpdate(.1) end
assert(refreshes<8 and refreshes>0,"route refresh stays below 4 Hz")
AT.db.showQuestRoute=false
observer:OnUpdate(.4)
refreshes=0
for i=1,20 do observer:OnUpdate(.1) end
assert(refreshes==0,"disabled GPS does no periodic refresh work")
print("PASS minimap quest panel removed; yard count, direction line, arrival and world-map callbacks preserved")

-- A verified hand-in only 6 yards away geographically may still be down a
-- longer path around a wall. When a real walk exists, it decides arrival.
AT.db.showQuestRoute=true
active=true;t=t+1;x=.55
function AT.IsQuestTurnInNavigation() return true end
function AT.GetFocusedQuestRoutePoint() return 981,20,.556,.5 end
function AT.GetFocusedQuestWalkingPath()
    return {waypoints={{map=20,x=.55,y=.5},{map=20,x=.55,y=.55},
        {map=20,x=.556,y=.55},{map=20,x=.556,y=.5}},yards=106},
        {map=20,x=.556,y=.5},"routed"
end
AT.RefreshQuestRoute()
assert(AT.worldStatus=="routed","follow the actual turn-in walk rather than declaring arrival across the wall")
print("PASS ready-quest route can continue around an obstacle beside the hand-in")

-- The planner can resolve a verified candidate when the independent
-- single-point resolver (used by the fallback UI) supplies no coordinates.
local goodTurnInPlanner=AT.GetFocusedQuestWalkingPath
local goodTurnInPoint=AT.GetFocusedQuestRoutePoint
AT.GetFocusedQuestRoutePoint=function() return 981 end
t=t+1;AT.RefreshQuestRoute()
assert(AT.worldStatus=="routed" and AT.snapshot and AT.snapshot.selected.x==.556,
    "independent fallback metadata cannot suppress a verified route")
assert(not bearing.shown,"a real turn-in path is never replaced by a bearing")
AT.GetFocusedQuestWalkingPath=function()return nil,nil,"objective_missing" end
t=t+1;AT.RefreshQuestRoute()
assert(AT.worldStatus=="turnin_missing" and not AT.snapshot and not bearing.shown,
    "no verified target or geometry is still reported as missing")
AT.GetFocusedQuestRoutePoint=goodTurnInPoint
AT.GetFocusedQuestWalkingPath=function()return nil,nil,"planning" end
t=t+1;AT.RefreshQuestRoute()
assert(AT.worldStatus=="planning","six yards in a straight line is not proof of arrival while planning")
AT.GetFocusedQuestWalkingPath=goodTurnInPlanner
t=t+1;AT.RefreshQuestRoute()
assert(AT.worldStatus=="routed" and AT.snapshot.path)
print("PASS turn-in routing respects the verified planner before display coordinates or direct arrival")


local scope=true
AT.GetWalkingNavigationID=function()if scope then return -1,"waypoint" end end
AT.GetSelectedUserWaypoint=function()return {map=20,x=.556,y=.5}end
AT.IsQuestTurnInNavigation=function()error("waypoint leaked into quest API")end
GetTaskInfo=function()error("waypoint leaked into task API")end
AT.RefreshQuestRoute()
assert(AT.worldStatus=="routed" and AT.snapshot.quest==-1)
local status,id,details,source=AT.GetQuestRouteStatus()
assert(status=="routed" and id==nil and source=="waypoint" and details:find("native waypoint",1,true))
AT.GetFocusedQuestWalkingPath=function()return nil,nil,"offmesh"end
AT.RefreshQuestRoute()
assert(AT.worldStatus=="offmesh" and not bearing.shown and not AT.snapshot)
scope=false
AT.RefreshQuestRoute()
assert(AT.worldStatus=="no_quest" and not meter.shown)
print("PASS selected waypoint route bypasses quest/task state, tracks around walls and hides when cleared or unsupported")


-- The active graph route remains usable at the zone edge even when the
-- native inverse won't expose an out-of-bounds map coordinate.
scope=true
x=.98;t=t+1
local function vec(a,b)return {GetXY=function()return a,b end} end
CreateVector2D=vec
local world=0
C_Map.GetWorldPosFromMapPos=function(m,p)
 local a,b=p:GetXY()
 return m==21 and world or 0,vec((a+(m==21 and 1 or 0))*1000,b*1000)
end
C_Map.GetMapPosFromWorldPos=function(_,p,m)
 local a,b=p:GetXY()
 if m==20 and a>=0 and a<=1000 then return m,vec(a/1000,b/1000) end
end
local endpoint={map=21,x=.06,y=.5}
local function assignPath()
 local path={waypoints={{map=20,x=.98,y=.5},endpoint},yards=80}
 AT.GetFocusedQuestWalkingPath=function()return path,endpoint,"routed"end
end
assignPath()
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.snapshot.path and AT.worldStatus=="routed" and not bearing.shown,
 "verified cross-boundary path must be drawn without resorting to a bearing")
world=1;assignPath()
AT.RefreshQuestRoute()
assert(not AT.snapshot,"never carry a line from a different world")
world=0;local normal=C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos=function(m,p)
 local w,z=normal(m,p);local a,b=z:GetXY()
 if m==20 and a==500 and b==500 then a=a+4 end
 return w,vec(a,b)
end
assignPath()
AT.RefreshQuestRoute()
assert(not AT.snapshot,"nonaffine chart has no safe cross-boundary snap")
print("PASS minimap keeps a verified walking line at a zone boundary, and rejects remote or non-affine geometry")
-- Keep the same path while an initially missing chart becomes readable.
local chartUnavailable=true
C_Map.GetWorldPosFromMapPos=function(m,p)
 if m==20 and chartUnavailable then return end
 return normal(m,p)
end
assignPath();AT.RefreshQuestRoute()
assert(not AT.snapshot,"unavailable chart cannot draw a guessed edge")
chartUnavailable=false;t=t+3
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.snapshot.path and AT.worldStatus=="routed",
 "the verified line comes back on the minimap without replacing the path")
print("PASS native zone boundary transform retries after a temporary chart gap")



-- A single unprojectable chart point must not blank other nearby segments.
-- The two segments touching it stay hidden: never bridge the hole.
x=.5;t=t+1;world=1
local path={waypoints={{map=20,x=.5,y=.5},{map=20,x=.51,y=.5},
    {map=21,x=.1,y=.5},{map=20,x=.52,y=.52},{map=20,x=.54,y=.52}},yards=100}
AT.GetFocusedQuestWalkingPath=function()return path,path.waypoints[5],"routed" end
AT.RefreshQuestRoute()
local show={}
for _,line in ipairs(drawn) do if line.autoTrackGlow and line.shown and line.x then show[#show+1]=line end end
assert(#show==2,"draw both valid pieces and no bridge")
assert(show[1].x==0 and show[1].y==0 and show[2].x>show[1].endX and show[2].y==show[2].endY)
print("PASS minimap shows later verified segments after a projection gap without bridging it")


-- A later map point can be temporarily unavailable after a zone reload.
-- Once readable, recover the precise walking counter without reselecting.
world=0;x=.95;t=t+1
local waiting=true
C_Map.GetWorldPosFromMapPos=function(m,p)
    if m==21 and waiting then return 0,nil end
    return normal(m,p)
end
local long={{map=20,x=.95,y=.5}}
for i=1,40 do long[#long+1]={map=20,x=.95+i*.001,y=.5} end
long[#long+1]={map=21,x=.02,y=.51}
local longPath={waypoints=long,yards=80}
AT.GetSelectedUserWaypoint=function()return long[#long] end
AT.GetFocusedQuestWalkingPath=function() return longPath,long[#long],"routed" end
AT.RefreshQuestRoute()
local _,_,firstDetail=AT.GetQuestRouteStatus()
assert(not firstDetail:find("distance: walking path",1,true))
waiting=false;t=t+1
AT.RefreshQuestRoute()
local _,_,recoveredDetail=AT.GetQuestRouteStatus()
assert(recoveredDetail:find("distance: walking path",1,true),
 "a now-readable map point recovers the remaining walking distance")
print("PASS transient later map point recovers walking distance without replacing the path")


-- On a native bundled route the producer supplies cumulative costs.
-- A later unreadable chart point (in the turn-preview window) must not
-- turn an exact graph counter into a straight-line estimate.
waiting=true;x=.954;t=t+1
local last={map=21,x=.02,y=.52}
local withCosts={waypoints={{map=20,x=.95,y=.5},{map=20,x=.96,y=.5},
    {map=20,x=.98,y=.52},last},cumulativeYards={0,10,38.28428,78.28428},yards=78.28428}
AT.GetSelectedUserWaypoint=function()return last end
AT.GetFocusedQuestWalkingPath=function()return withCosts,last,"routed" end
AT.RefreshQuestRoute()
local _,_,withDetail=AT.GetQuestRouteStatus()
assert(withDetail:find("distance: walking path",1,true) and meter.label.text=="74 yd",
    "partial segment uses the exact producer counter while the later chart is unavailable")
withCosts.cumulativeYards={0,90,38.28428,78.28428}
AT.RefreshQuestRoute()
local _,_,badDetail=AT.GetQuestRouteStatus()
assert(not badDetail:find("distance: walking path",1,true),"invalid metadata uses existing guarded fallback")
print("PASS exact fractional graph distance survives a later missing chart; invalid metadata does not set the walking counter")

-- The native width/height getter sometimes isn't ready at a zone change.
-- A cardinal, round-tripped outdoor chart can supply the exact scales.
local chart=30
C_Map.GetBestMapForUnit=function()return chart end
C_Map.GetMapWorldSize=nil
C_Map.GetWorldPosFromMapPos=function(m,p)
    local u,v=p:GetXY()
    return m==32 and 2 or 1,vec(5000-v*2000,3400-u*1200+(m==31 and u*v*40 or 0))
end
C_Map.GetMapPosFromWorldPos=function(_,p,m)
    local a,b=p:GetXY()
    return m,vec((3400-b)/1200,(5000-a)/2000)
end
scope=true;x=.5;t=t+1
local plannerCalls=0
local target={map=chart,x=.6,y=.5}
AT.GetSelectedUserWaypoint=function()return target end
AT.GetFocusedQuestWalkingPath=function(_,origin,w,h)
    plannerCalls=plannerCalls+1
    assert(w==1200 and h==2000)
    return {waypoints={origin,target},yards=120},target,"routed"
end
AT.RefreshQuestRoute()
assert(AT.worldStatus=="routed" and AT.snapshot and plannerCalls==1,"verified map size fallback keeps walking in view")
chart=31;target={map=chart,x=.6,y=.5};t=t+1
AT.RefreshQuestRoute()
assert(not AT.snapshot and plannerCalls==1,"a nonlinear chart may not substitute for the native size")
chart=32;target={map=chart,x=.6,y=.5};t=t+1
C_Map.GetMapPosFromWorldPos=function(_,p,m) return m,vec(.6,.6) end
AT.RefreshQuestRoute()
assert(not AT.snapshot and plannerCalls==1,"a chart must independently round trip")
function C_Map.GetMapWorldSize()return 1200,2000 end
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.worldStatus=="routed" and plannerCalls==2,"native sizes remain authoritative")
print("PASS exact outdoor chart dimensions prevent disappearing routes while native width/height is unavailable")

-- A rotated/minimap API raising a client restriction must never stop the
-- independently verified world-map route or walking-yard counter.
function GetCVarBool() error("protected rotation state") end
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.worldStatus=="routed" and meter.shown and not frames[1].shown,
 "the world map and walking counter do not depend on a readable rotation toggle")
function GetCVarBool()return true end
function GetPlayerFacing()error("protected heading")end
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.worldStatus=="routed" and not frames[1].shown)
function GetPlayerFacing()return 0 end
Minimap.GetWidth=function()error("minimap rendering is unavailable")end
AT.RefreshQuestRoute()
assert(AT.snapshot and AT.worldStatus=="routed" and not frames[1].shown)
Minimap.GetWidth=function()return 170 end
AT.RefreshQuestRoute()
assert(AT.snapshot and frames[1].shown,"the minimap resumes when rotation and its geometry are readable")
print("PASS native minimap restrictions cannot suppress independently verified world routes")
