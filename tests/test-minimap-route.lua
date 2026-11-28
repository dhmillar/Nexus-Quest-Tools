local AT={db={enabled=true,showQuestRoute=true}}
local x,inside,t,active=.5,false,10,true
local frames={}
local function nothing() end
local function region()
    return {SetText=function(self,v) self.text=v end,SetPoint=nothing,ClearAllPoints=nothing,SetTextColor=nothing,
        SetThickness=nothing,SetColorTexture=nothing,
        SetStartPoint=function(self,_,_,x,y)self.x=x;self.y=y end,
        SetEndPoint=function(self,_,_,x,y)self.endX=x;self.endY=y end,
        Show=nothing,Hide=nothing}
end
function CreateFrame(_,_,parent)
    local f={parent=parent,shown=true,CreateTexture=region,CreateLine=region,SetAllPoints=nothing,
        SetSize=nothing,EnableMouse=nothing,SetFrameLevel=nothing,SetScript=function(self,k,v)self[k]=v end,ClearAllPoints=nothing}
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
