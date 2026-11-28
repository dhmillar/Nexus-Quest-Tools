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
