local AT={db={enabled=true,showQuestRoute=true}}
local function noop() end
local function vec(x,y) return {GetXY=function()return x,y end} end
CreateVector2D=vec
local continent=false
local visible=true
local map={GetWidth=function()return 1200 end,GetHeight=function()return 800 end,GetFrameLevel=function()return 8 end}
WorldMapFrame={IsVisible=function()return visible end,GetCanvas=function()return map end,
    GetMapID=function()return continent and 2 or 20 end}
C_Map={
    GetMapInfo=function(id) return {mapType=id==2 and 2 or 3,parentMapID=id==2 and 1 or 2} end,
    GetBestMapForUnit=function() return 20 end,
    GetWorldPosFromMapPos=function(m,p)
        local x,y=p:GetXY();return 0,vec((m==21 and 1000 or 0)+x*1000,y*1000)
    end,
    GetMapPosFromWorldPos=function(_,p,dst)
        local x,y=p:GetXY();return dst,vec(dst==2 and x/2000 or x/1000,y/1000)
    end
}
local overlay,segments
function CreateFrame()
    segments={}
    overlay={SetAllPoints=noop,EnableMouse=noop,SetFrameLevel=noop,
        Show=function(self) self.visible=true end,Hide=function(self) self.visible=false end}
    function overlay:CreateLine(_,layer)
        local l={SetThickness=noop,SetColorTexture=noop,SetStartPoint=function(self,_,_,x,y)self.start={x,y}end,
            SetEndPoint=function(self,_,_,x,y)self.finish={x,y}end,
            Show=function(self)self.visible=true end,Hide=function(self)self.visible=false end}
        if layer=="OVERLAY" then segments[#segments+1]=l end
        return l
    end
    function overlay:CreateFontString() return {SetShadowOffset=noop,SetText=noop,SetPoint=noop,
        SetTextColor=noop,ClearAllPoints=noop,Show=noop,Hide=noop} end
    return overlay
end
local path={waypoints={}}
for i=0,700 do path.waypoints[i+1]={map=i<350 and 20 or 21,x=i<350 and .2+i/1500 or (i-350)/1000,y=.6+i%2*.0005} end
local quest=18
local player=path.waypoints[1]
local goal=path.waypoints[#path.waypoints]
local function provider(kind)
    local a={version=2,minor=13,NavVersion=function() return kind end,started=0}
    a.EstimateWalks=function(owner,from,targets,callback)
        assert(owner=="AutoTrack.QuestWalking" and from==player and targets[1]==goal)
        a.started=a.started+1
        if a.unavailable then return nil,"nodata" end
        callback({1300})
        return noop
    end
    a.WalkPath=function(owner,from,to,callback)
        assert(owner=="AutoTrack.QuestWalking" and from==player and to==goal)
        callback({waypoints=path.waypoints,yards=1300,navVersion=kind})
        return noop
    end
    return a
end
local spf,road=provider("spf"),provider("road")
ShortestPathForever={API=spf}
function AT.GetQuestNavigationID() return quest end
function AT.GetFocusedQuestRouteTargets()return quest,{goal}end
function AT.GetRoadWalkingAPI()return road end
local now=1
function GetTime()return now end
assert(loadfile("NQT/Walking.lua"))("NQT",AT)
local result,selected,status=AT.GetFocusedQuestWalkingPath(quest,player,1000,1000)
assert(result and result.navVersion=="road" and #result.waypoints==701 and selected==goal and status=="routed")
assert(spf.started==0 and road.started==1)
assert(loadfile("NQT/WorldRoute.lua"))("NQT",AT)
continent=true
AT.RenderWorldQuestRoute("routed",quest,{path=result,selected=goal,quest=quest,segment=1,fraction=.25})
assert(overlay.visible and #segments==700 and segments[700].visible)
assert(math.abs(segments[700].finish[1]-810)<.00001,"last segment reaches the other zone on the continent map")
assert(segments[1].start[1]>120,"trim already-walked part of the first segment")
visible=false
AT.RenderWorldQuestRoute("routed",quest,{path=result,selected=goal,quest=quest,segment=1,fraction=0})
assert(not overlay.visible)

visible=true
AT.RenderWorldQuestRoute("nodata",quest,{quest=quest,bearing=true,from=player,target=goal})
assert(overlay.visible and segments[1].visible and not segments[2].visible)
assert(math.abs(segments[1].finish[1]-810)<.00001,"shared bearing projects across zones")
AT.RenderWorldQuestRoute("arrival",quest,nil)
assert(not overlay.visible)
assert(spf.started==0,"do not call the external provider even when installed")
-- Native map data may not have populated when a route was first painted.
-- Initially none of the neighboring-zone vertices can be projected.
local getWorld=C_Map.GetWorldPosFromMapPos
local blocked,attempts=true,0
C_Map.GetWorldPosFromMapPos=function(m,p)
    if m==21 then attempts=attempts+1;if blocked then return end end
    return getWorld(m,p)
end
local transient={waypoints=path.waypoints}
local args={path=transient,selected=goal,quest=quest,segment=1,fraction=0}
AT.RenderWorldQuestRoute("routed",quest,args)
assert(segments[349].visible and not segments[350].visible,"never bridge a projection failure")
attempts=0
AT.RenderWorldQuestRoute("routed",quest,args)
assert(attempts<=2,"do not reproject all the failed vertices every refresh")
blocked=false;now=now+3;attempts=0
AT.RenderWorldQuestRoute("routed",quest,args)
assert(segments[350].visible and attempts<=26,"nearby geometry recovers with bounded work even for a long route")
for i=1,20 do now=now+.3;AT.RenderWorldQuestRoute("routed",quest,args) end
assert(segments[700].visible and math.abs(segments[700].finish[1]-810)<.00001,
    "all later segments recover without reopening the map or reselecting the quest")
print("PASS transient native world-map projections recover via a bounded fair retry queue")

print("PASS standalone road provider, full cross-zone walking path, and shared amber bearing")
