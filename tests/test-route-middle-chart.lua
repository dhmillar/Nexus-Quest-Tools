-- Real terrain; synthetic adjacent chart bounds and native API behavior.
local AT={NQTDB={}}
local x,y=547.3,1593.1
local fromMap,middle,toMap=1420,1422,1421
local world,kind,shift=0,3,0
local noHint=0
local unavailable=false
local function vec(a,b)return {GetXY=function()return a,b end}end
CreateVector2D=vec
local function loc(p)
 if p<=522 then return toMap elseif p>=540 then return fromMap else return middle end
end
local offset={[fromMap]=.5,[toMap]=.6,[middle]=.25}
local function coords(m,a,b)return (a-x)/1000+offset[m],(b-y)/1000+.5 end
C_Map={
 GetMapInfo=function(m)return {mapType=m==middle and kind or 3,parentMapID=1415}end,
 GetWorldPosFromMapPos=function(m,p)
  local a,b=p:GetXY()
  return m==middle and world or 0,vec(x+(a-offset[m])*1000-(m==middle and shift or 0),y+(b-.5)*1000)
 end,
 GetMapPosFromWorldPos=function(w,p,hint)
  assert(w==0)
  local a,b=p:GetXY()
  local m=loc(a)
  if unavailable and m==middle then return end
  if hint and hint~=m then return end
  if not hint then noHint=noHint+1 end
  return m,vec(coords(m,a,b))
 end
}
function GetBuildInfo()return "1.60.1","71139" end
function UnitPosition()return x,y,0,0 end
local pending={}
local delayed,releaseChart,stopOnDelay=0,false,false
C_Timer={After=function(seconds,f)
 if seconds>0 then
  delayed=delayed+1
  if releaseChart then unavailable=false end
 end
 pending[#pending+1]=f
end}
for _,f in ipairs({"NQTDBRouteWorld0","NQTDBDryComponents","NQTDBDryLandmarks","NQTDBWalking"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local from={map=fromMap,x=.5,y=.5}
local a,b=coords(toMap,518,1599.7)
local api=assert(AT.GetBundledWalkingAPI(from))
local function run()
 local result,why
 local cancel=assert(api.WalkPath("real terrain across three map charts",from,{map=toMap,x=a,y=b},function(r,e)result,why=r,e end))
 local n=0
 while #pending>0 do
  n=n+1;assert(n<350);table.remove(pending,1)()
  if delayed>0 and stopOnDelay then cancel();stopOnDelay=false end
 end
 return result,why
end
local route=assert(run(),"the intermediary zone must not discard an existing verified terrain path")
local see={}
for _,p in ipairs(route.waypoints) do see[p.map]=true end
assert(see[fromMap] and see[middle] and see[toMap] and noHint==1,"cache the validated middle chart for consecutive points")
for _,problem in ipairs({"interior","remote","mismatch"})do
 kind=problem=="interior" and 4 or 3
 world=problem=="remote" and 1 or 0
 shift=problem=="mismatch" and 3 or 0
 local bad,why=run()
 assert(not bad and why=="projection","reject "..problem.." map projection")
end
print(("PASS %.1f yd actual outdoor route spans three charts; mismatched, remote and dungeon chart hints rejected"):format(route.yards))

kind,world,shift=3,0,0
assert(delayed==0,"known unsafe chart maps are not treated as a loading delay")
unavailable,releaseChart=true,true
local loaded=assert(run(),"temporary chart gap should reschedule projection, not lose the calculated route")
assert(delayed==1 and #loaded.waypoints==#route.waypoints and loaded.yards==route.yards)
for i,p in ipairs(route.waypoints) do
 local r=loaded.waypoints[i];assert(p.map==r.map and p.x==r.x and p.y==r.y)
end
unavailable,releaseChart,delayed=true,false,0
local stillMissing,why=run()
assert(not stillMissing and why=="projection" and delayed==2,"persistent map absence must stop after two retries")
unavailable,releaseChart,delayed,stopOnDelay=true,true,0,true
local cancelled,reason=run()
assert(not cancelled and not reason and delayed==1,"changing navigation cancels projection even when the chart becomes available")
print("PASS temporary chart gap restores identical actual terrain route without recalculation; retries and cancellation are bounded")
