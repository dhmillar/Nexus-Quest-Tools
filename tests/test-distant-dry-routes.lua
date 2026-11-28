-- Same-world, publicly observed Forever coordinates, Efficient Games CC BY 4.0.
-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf
local AT={NQTDB={}}
local w,x,y
local function vec(a,b)return {GetXY=function()return a,b end}end
CreateVector2D=vec
C_Map={
 GetWorldPosFromMapPos=function(_,p)local a,b=p:GetXY();return w,vec(x+(a-.5)*50000,y+(b-.5)*50000)end,
 GetMapPosFromWorldPos=function(_,p,m)local a,b=p:GetXY();return m,vec((a-x)/50000+.5,(b-y)/50000+.5)end
}
function UnitPosition()return x,y,0,w end
function GetBuildInfo()return "1.60.1","71139" end
local q={}
C_Timer={After=function(_,f) q[#q+1]=f end}
for _,f in ipairs({"NQTDBRouteWorld0","NQTDBRouteWorld1","NQTDBDryComponents","NQTDBDryLandmarks","NQTDBWalking"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function check(world,sx,sy,gx,gy,expected)
 w,x,y=world,sx,sy
 local start={map=100+w,x=.5,y=.5}
 local goal={map=100+w,x=(gx-x)/50000+.5,y=(gy-y)/50000+.5}
 local api=assert(AT.GetBundledWalkingAPI(start))
 local result
 assert(api.WalkPath("known distant dry route",start,goal,function(path,why)
   assert(not why,why);result=path
 end))
 local n=0
 while #q>0 do n=n+1;assert(n<760,"extended exact search must remain bounded");table.remove(q,1)()end
 assert(result and math.abs(result.yards-expected)<1 and #result.waypoints>150)
 local cost,points=result.cumulativeYards,result.waypoints
 assert(#cost==#points and cost[1]==0 and cost[#points]==result.yards)
 local merged=false
 for i=2,#cost do
  local a,b=points[i-1],points[i]
  local dx,dy=(b.x-a.x)*50000,(b.y-a.y)*50000
  local length=math.sqrt(dx*dx+dy*dy)
  assert(cost[i]>cost[i-1] and math.abs((cost[i]-cost[i-1])-length)<.001,
      "each retained straight edge retains its true accumulated graph cost")
  if length>20 then merged=true end
 end
 assert(merged,"witness must include a compacted segment")
 print(("PASS %.0f yd bounded exact walking path in %d timer slices on world %d"):format(result.yards,n,w))
end
check(0,-8869.4,-161.5,-10455.1,-3281.9,8079.5)
check(1,-1731.7,3184.7,-897.7,-3765.6,11317.5)



-- Re-run the exact same bundled data through the actual caller at 15 fps.
-- A frame-paced stationary request takes longer than the old 35 s watchdog.
AT.db={}
local now,quest,selected,focusMap,target=0,11,true
function GetTime()return now end
C_Map.GetBestMapForUnit=function() return focusMap end
C_Map.GetMapInfo=function()return {mapType=3} end
C_Map.GetUserWaypoint=function()return selected and {uiMapID=target.map,position=vec(target.x,target.y)} end
C_SuperTrack={IsSuperTrackingUserWaypoint=function()return selected end}
function AT.GetQuestNavigationID()return quest,"hud" end
function AT.GetFocusedQuestRouteTargets()return quest,{target} end
assert(loadfile("NQT/Walking.lua"))("NQT",AT)
local function paced(world,sx,sy,gx,gy,expected,isPin)
 w,x,y,selected=world,sx,sy,isPin
 quest=quest+1
 focusMap=100+w
 local from={map=focusMap,x=.5,y=.5}
 target={map=focusMap,x=(gx-x)/50000+.5,y=(gy-y)/50000+.5}
 local nav=AT.GetWalkingNavigationID()
 local api=assert(AT.GetBundledWalkingAPI(from))
 local method="WalkPath" -- A single quest target is the same exact query as a pin.
 local orig,requests=api[method],0
 api[method]=function(...)requests=requests+1;return orig(...)end
 AT.CancelQuestWalking()
 now=0
 local got=AT.GetFocusedQuestWalkingPath(nav,from,50000,50000)
 local frame=0
 while not got and frame<1000 do
  frame=frame+1
  now=frame/15
  local callback=table.remove(q,1)
  if callback then callback() end
  got=AT.GetFocusedQuestWalkingPath(nav,from,50000,50000)
 end
 api[method]=orig
 assert(got and requests==1 and now>35,"actively progressing request must not restart at 35 seconds: "..requests)
 assert(math.abs(got.yards-expected)<1)
 print(("PASS exact %.0f yd %s in %.1f modeled seconds at 15 fps without restarting"):format(got.yards,isPin and "waypoint" or "quest path",now))
end
paced(0,-8869.4,-161.5,-10455.1,-3281.9,8079.5,true)
paced(1,-1731.7,3184.7,-897.7,-3765.6,11317.5,false)

-- Change one pin without moving or allowing a previously queued callback
-- to finish, then simulate a real scheduler stall on the new search.
selected=true
local from={map=focusMap,x=.5,y=.5}
local api=assert(AT.GetBundledWalkingAPI(from))
local orig=api.WalkPath
local work,respond,cancelled,requests
cancelled,requests=0,0
api.WalkPath=function(_,p,t,cb,report)
 work,respond=report,cb
 requests=requests+1
 return function()cancelled=cancelled+1 end
end
local nav=AT.GetWalkingNavigationID()
AT.CancelQuestWalking()
now=100
assert(not AT.GetFocusedQuestWalkingPath(nav,from,50000,50000))
local staleWork,staleResponse=assert(work),respond
target={map=focusMap,x=target.x+.001,y=target.y}
now=101
assert(not AT.GetFocusedQuestWalkingPath(nav,from,50000,50000) and requests==2 and cancelled==1)
now=130
staleWork()
staleResponse({yards=1,navVersion=api.NavVersion(),waypoints={from,target}})
assert(not AT.GetFocusedQuestWalkingPath(nav,from,50000,50000) and requests==2)
now=137
assert(not AT.GetFocusedQuestWalkingPath(nav,from,50000,50000) and requests==3 and cancelled==2,
 "stale activity cannot prevent recovery from a stalled new request")
api.WalkPath=orig
AT.CancelQuestWalking()
print("PASS changed waypoint cancels immediately; a stalled replacement restarts and stale request activity cannot extend it")
