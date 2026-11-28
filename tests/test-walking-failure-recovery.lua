local AT={db={}}
local now,attempts,ok,why=0,0,false,"offmesh"
local goal={map=19,x=.8,y=.8}
local from={map=19,x=.2,y=.2}
local function compute(_,at,goals,cb)
 attempts=attempts+1
 if not ok then return nil,why end
 cb({waypoints={at,goals[1]},targetIndex=1,yards=100,navVersion="atlas"})
 return function()end
end
local engine={version=2,minor=7,NavVersion=function()return "atlas" end, WalkBestPath=compute,
 EstimateWalks=function()error("unexpected estimate")end,WalkPath=function()error("unexpected separate path")end}
function AT.GetBundledWalkingAPI()return engine end
function AT.GetQuestNavigationID()return 3 end
function AT.GetFocusedQuestRouteTargets()return 3,{goal} end
function GetTime()return now end
assert(loadfile("NQT/Walking.lua"))("NQT",AT)
local function refresh(origin) return AT.GetFocusedQuestWalkingPath(3,origin or from,1000,1000) end
assert(not refresh() and attempts==1)
now=1
assert(not refresh() and attempts==1,"avoid repeated searching with the same inputs")
assert(not refresh({map=19,x=.215,y=.2}) and attempts==1,"don't churn with minor movement")
ok=true
local recovered=assert(refresh({map=19,x=.23,y=.2}))
assert(recovered.waypoints[1].x==.23 and attempts==2,"resume the moment a sufficiently different start is seen")
AT.CancelQuestWalking()
ok=false
local newStart={map=19,x=.3,y=.2}
assert(not refresh(newStart) and attempts==3)
now=2
goal={map=19,x=.65,y=.6}
ok=true
assert(refresh(newStart) and attempts==4,"changed objective must be eligible within the old cooldown")
AT.CancelQuestWalking()
newStart={map=19,x=.4,y=.2}
now,ok,why=5,false,"combat"
assert(not refresh(newStart) and attempts==5)
now=6
assert(not refresh({map=19,x=.5,y=.2}) and attempts==5,"moving cannot bypass general client cooldown")
now,ok=9,true
assert(refresh({map=19,x=.5,y=.2}) and attempts==6)
print("PASS route failures back off for the exact problem, recover after movement or a changed objective, and respect client cooldowns")
