-- Use the real minimap coordinator and walking job scheduler together.
local AT={db={enabled=true,showQuestRoute=true}}
local now,posX,posY=.0,.2,.2
local dest={map=19,x=.9,y=.2}
local frames={}
local function nop()end
local function region()return {Show=nop,Hide=nop,SetText=nop,SetTextColor=nop,SetPoint=nop,ClearAllPoints=nop,
 SetColorTexture=nop,SetStartPoint=nop,SetEndPoint=nop,SetThickness=nop}end
function CreateFrame()
 local f=region(); f.CreateLine=region;f.CreateFontString=region;f.SetSize=nop;f.EnableMouse=nop
 f.SetAllPoints=nop;f.SetFrameLevel=nop;f.SetScript=nop
 frames[#frames+1]=f;return f
end
Minimap={GetWidth=function()return 170 end,GetHeight=function()return 170 end,GetFrameLevel=function()return 1 end}
function GetTime()return now end
C_Map={GetBestMapForUnit=function()return 19 end,GetPlayerMapPosition=function()return {GetXY=function()return posX,posY end}end,
 GetMapWorldSize=function()return 1000,1000 end,GetMapInfo=function()return {mapType=3}end}
function AT.GetQuestNavigationID()return 3 end
function AT.GetFocusedQuestRouteTargets()return 3,{dest} end
function AT.GetFocusedQuestRoutePoint()return 3,dest.map,dest.x,dest.y end
function AT.RenderWorldQuestRoute(status,_,snapshot) AT.lastStatus,AT.snap=status,snapshot end
local pending,cancelled,count=nil,0,0
local function compute(_,at,goals,callback)
 count=count+1
 local goal=goals[1]
 pending=function()
   local path={waypoints={at,{map=19,x=at.x,y=goal.y},goal},targetIndex=1,
      yards=math.abs(goal.x-at.x)*1000+math.abs(goal.y-at.y)*1000,navVersion="atlas"}
   callback(path)
 end
 return function()cancelled=cancelled+1 end
end
local api={version=2,minor=7,NavVersion=function()return "atlas"end,WalkBestPath=compute,
 EstimateWalks=function()error("unexpected estimate")end,WalkPath=function()error("unexpected separate path")end}
function AT.GetBundledWalkingAPI()return api end
assert(loadfile("NQT/Walking.lua"))("NQT",AT)
assert(loadfile("NQT/Route.lua"))("NQT",AT)
local function refresh(dx,dy)
 posX,posY=posX+(dx or 0)/1000,posY+(dy or 0)/1000
 now=now+.3
 AT.RefreshQuestRoute()
end
AT.InitQuestRoute();assert(count==1)
pending();refresh()
assert(AT.lastStatus=="routed" and AT.snap)
for i=1,40 do
 refresh(10,0)
 assert(AT.lastStatus=="routed" and AT.snap and count==1,"smooth route should not relaunch while progressing along it")
end
refresh(0,14) -- Nearby enough to finish displaying old path while a replacement starts.
assert(count==1)
refresh(0,0);assert(count==2 and AT.lastStatus=="routed","begin a replacement once no longer close to the path")
local replacement=pending
refresh(0,14)
assert(count==2 and cancelled==0 and AT.lastStatus=="replan","drop rejected geometry without cancelling an in-flight replacement")
replacement();refresh()
assert(AT.lastStatus=="routed" and AT.snap and count==2)
dest={map=19,x=.87,y=.5}
now=now+1;refresh()
assert(count==3 and not (AT.snap and AT.snap.path),"changed target cannot retain old route geometry")
print("PASS uninterrupted 400-yard walk with one request, off-path replacement retained, changed goal drops old geometry")
