local origin={map=19,x=.2,y=.2}
local blocked={map=19,x=.7,y=.6}
local observed={map=19,x=.65,y=.67}
local focus,mockResult,change=nil,"offmesh",nil
local AT={db={}}
local req={}
local function cleanStop()end
local engine={
 version=2,minor=7,
 NavVersion=function()return "bundled-test" end,
 EstimateWalks=function()error("combined search already available")end,
 WalkPath=function()error("one or more objective targets use the bundled multi-goal entry")end,
 WalkBestPath=function(_,from,spots,reply)
  assert(from==origin)
  local p=spots[1]
  req[#req+1]=p
  if p==blocked and mockResult=="offmesh" then return nil,"offmesh" end
  if p==blocked and (mockResult=="unreachable" or mockResult=="projection") then
   if change then observed=change end
   reply(nil,mockResult)
   return cleanStop
  end
  reply({targetIndex=1,navVersion="bundled-test",yards=100,waypoints={origin,p}})
  return cleanStop
 end
}
function AT.GetBundledWalkingAPI()return engine end
function AT.GetQuestNavigationID()return focus end
function AT.GetFocusedQuestRouteTargets()return focus,{blocked},{observed} end
assert(loadfile("NQT/Walking.lua"))("NQT",AT)
focus=10
local route,p=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
assert(route and p==observed and route.observedApproach and #req==2 and req[1]==blocked and req[2]==observed)
for _,why in ipairs({"unreachable","projection"}) do
 focus=focus+1
 AT.CancelQuestWalking()
 req={};mockResult=why
 route,p=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
 assert(route and p==observed and route.observedApproach and #req==2)
end
focus=focus+1
AT.CancelQuestWalking()
req={};mockResult="native"
route,p=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
assert(route and p==blocked and not route.observedApproach and #req==1,"never change a routable native target")
focus=focus+1
AT.CancelQuestWalking()
req={};mockResult="unreachable";change={map=19,x=.8,y=.4}
route=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
assert(not route,"progress changing backup identity invalidates a stale route")
print("PASS verified observed walking backup only after unmappable native path; native priority and stale-point guard")

focus=focus+1
AT.CancelQuestWalking()
change=nil;observed={map=19,x=.68,y=.62}
mockResult="offmesh";req={}
function AT.IsQuestTurnInNavigation()return true end
route,p=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
assert(route and p==observed and route.verifiedTurnInApproach and not route.observedApproach and #req==2)
print("PASS verified turn-in uses distinct fallback label and still tries native first")


-- A combined search that budgets out can fall back to per-map estimates.
-- If those prove every primary unreachable, it still owes the verified backup a try.
for _,case in ipairs({"none reachable","projected path rejected","async path rejected","combat","both budget"}) do
 focus=focus+1
 AT.CancelQuestWalking()
 local pending,trace=nil,{}
 engine.WalkBestPath=function(_,from,spots,reply)
  trace[#trace+1]=spots[1]
  if spots[1]==blocked then return nil,"budget" end
  assert(spots[1]==observed)
  reply({targetIndex=1,navVersion="bundled-test",yards=95,waypoints={origin,observed}})
  return cleanStop
 end
 engine.EstimateWalks=function(_,from,spots,reply)
  assert(spots[1]==blocked)
  if case=="both budget" then return nil,"budget" end
  reply({case~="none reachable" and 100 or false})
  return cleanStop
 end
 engine.WalkPath=function(_,from,target,reply)
  assert(target==blocked)
  if case=="async path rejected" then pending=reply;return cleanStop end
  return nil,case=="combat" and "combat" or "projection"
 end
 route,p=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
 if pending then
  assert(not route and #trace==1,"pending path must not draw prematurely")
  pending(nil,"projection")
  route,p=AT.GetFocusedQuestWalkingPath(focus,origin,1000,1000)
 end
 if case=="combat" or case=="both budget" then
  assert(not route and #trace==1,"temporary refusal must not replace the destination")
 else
  assert(route and p==observed and route.verifiedTurnInApproach and #trace==2,"verified fallback lost: "..case)
 end
end
print("PASS verified fallback survives estimate and final-projection failures without bypassing combat or budget")
