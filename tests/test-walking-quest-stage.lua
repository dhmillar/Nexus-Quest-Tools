local origin={map=19,x=.1,y=.1}
local goal={map=19,x=.2,y=.2}
local ready,empty,refused=false,false,false
local queued={}
local stopCount=0
local AT={db={}}
local function walk(_,_,_,callback)
 if refused then return nil,"offmesh" end
 queued[#queued+1]=callback
 return function()stopCount=stopCount+1 end
end
function AT.IsQuestTurnInNavigation()return ready end
function AT.GetQuestNavigationID()return 42 end
function AT.GetFocusedQuestRouteTargets()return 42,empty and {} or {goal} end
local engine={version=2,minor=7,NavVersion=function()return "test" end,
 WalkBestPath=walk,WalkPath=walk,EstimateWalks=function()error("unexpected estimates")end}
function AT.GetBundledWalkingAPI()return engine end
local now=0
function GetTime()return now end
assert(loadfile("NQT/Walking.lua"))("NQT",AT)
local function refresh()return AT.GetFocusedQuestWalkingPath(42,origin,1000,1000)end
local function route()return {yards=15,targetIndex=1,navVersion="test",waypoints={origin,goal}}end
assert(not refresh() and #queued==1)
local objective=route()
queued[1](objective)
assert(refresh()==objective)
ready=true
assert(not refresh() and #queued==2,"same quest/coordinates must immediately replan on completion")
local turn=route()
queued[2](turn)
assert(refresh()==turn)
AT.CancelQuestWalking()
ready=false
assert(not refresh() and #queued==3)
empty=true
ready=true
queued[3](route())
assert(not refresh() and stopCount>0,"late objective routes are rejected; stale objective is not a turn-in fallback")
empty=false
ready=false
refused=true
assert(not refresh())
ready=true
refused=false
assert(not refresh() and #queued==4,"an objective failure cannot delay a ready-to-turn-in route")
queued[4](turn)
assert(refresh()==turn)
print("PASS route stage transition, rejects late objective paths, new hand-in ignores objective backoff")
