local AT={db={enabled=true,showQuestRoute=true}}
local function vec(x,y) return {GetXY=function() return x,y end} end
CreateVector2D=vec
local map=2521
local t=1600/3
local m={2991,1247.9169921875,-1331.25,4956.25,4231.25}
local x0,y0,x1,y1=m[2],m[3],m[4],m[5]
local function raw(u,v)return x1-(x1-x0)*v,y1-(y1-y0)*u end
local function norm(x,y)return (y1-y)/(y1-y0),(x1-x)/(x1-x0)end
C_Map={
 GetWorldPosFromMapPos=function(id,p)local u,v=p:GetXY();local x,y=raw(u,v);return id==map and 2991 or 0,vec(x,y)end,
 GetMapPosFromWorldPos=function(w,p,id)local x,y=p:GetXY();local u,v=norm(x,y);return id,vec(u,v)end,
 GetBestMapForUnit=function()return map end
}
local pending={}
C_Timer={After=function(_,f) pending[#pending+1]=f end}
local function drain()
 local n=0
 while #pending>0 do n=n+1;assert(n<400,"solver frame budget");table.remove(pending,1)() end
end
local build="71139"
function GetTime()return 100 end
function GetBuildInfo()return "1.60.1",build end
local where,zBias
function UnitPosition()
 if where then local x,y=raw(where.x,where.y);return x,y,where.z+(zBias or 0),2991 end
end
for _,f in ipairs({"NQTDB","NQTDBRouteTiles","NQTDBWalking","Walking"}) do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
local D=AT.NQTDB.RouteTiles
local function point(X,Y)
 local n=D.cells
 local tile=D.tiles[math.floor(X/n)*D.ny+math.floor(Y/n)+1]
 if not tile then return end
 local off=(X%n*n+Y%n)*3+1
 local mask,l,h=tile:byte(off,off+2)
 if mask and mask~=0 then
  local u,v=norm((D.tx+(X+.5)/n)*t,(D.ty+(Y+.5)/n)*t)
  local Z=l+256*h
  if D.layerTransit and Z%2==1 then return end
  return {map=map,x=u,y=v,z=Z<32768 and Z or Z-65536,mask=mask}
 end
end
local n=D.cells
local start,goal
for X=0,n*D.nx-2 do
 for Y=0,n*D.ny-1 do
  local w,g=point(X,Y),point(X+1,Y)
  if w and g and w.mask%2==1 and X%n==n-1 and w.x>.15 and w.x<.8 and w.y>.15 and w.y<.8 then
   start,goal=w,g;break
  end
 end
 if start then break end
end
assert(start and goal,"real seam in data")
where=start
local api=assert(AT.GetBundledWalkingAPI(start))
local cost,route
local cancel=api.EstimateWalks("test",start,{goal,{map=100,x=.4,y=.4}},function(c)cost=c end)
assert(type(cancel)=="function" and not cost)
drain()
assert(cost[1]>7 and cost[2]==false)
api.WalkPath("test",start,goal,function(r)route=r end)
drain()
assert(route and #route.waypoints==2 and math.abs(route.yards-1600/3/67)<.01)
local aborted=api.WalkPath("test",start,goal,function()error("cancelled route delivered")end)
aborted();drain()
local result
function AT.GetQuestNavigationID()return 92461 end
function AT.GetFocusedQuestRouteTargets()return 92461,{goal}end
AT.GetFocusedQuestWalkingPath(92461,start,4000,4000)
drain()
result=AT.GetFocusedQuestWalkingPath(92461,start,4000,4000)
assert(result and result.navVersion==api.NavVersion())
zBias=20
assert(not AT.GetBundledWalkingAPI(start),"wrong floor")
zBias=0
build="expected-to-fail"
assert(not AT.GetBundledWalkingAPI(start))
build="71139"
IsSwimming=function()return true end
assert(not AT.GetBundledWalkingAPI(start))
print(("PASS imported ground route across a real Zephras tile seam (%.2f yd), no external addons, multi-goal, cancel, wrong floor and unsupported build"):format(result.yards))
local samples=AT.NQTDB.ObjectiveSpots[92461][1][4]
local reachable=0
IsSwimming=nil
for _,p in ipairs(samples) do
 local x,y=raw(p[2],p[3])
 local X,Y=math.floor(x/t*n-D.tx*n),math.floor(y/t*n-D.ty*n)
 local w=point(X,Y)
 if w then
  where=w
  local estimate
  api.EstimateWalks("real quest",w,{{map=map,x=p[2],y=p[3]}},function(c)estimate=c end)
  drain()
  if estimate and estimate[1] then reachable=reachable+1 end
 end
end
assert(reachable>0,"real observed New Dawn-area quest pins land on imported grid")
print(("PASS %d real observed quest sample endpoints on the imported dry grid"):format(reachable))
-- Run a longer real world route between two distinct observed quest samples.
local walked
for i=1,#samples do
 for j=i+1,#samples do
    if walked then break end
    local p,b=samples[i],samples[j]
    local x,y=raw(p[2],p[3])
    local w=point(math.floor(x/t*n-D.tx*n),math.floor(y/t*n-D.ty*n))
    if w then
     where=w
     local path
     api.WalkPath("quest corridor",w,{map=map,x=b[2],y=b[3]},function(r)path=r end)
     drain()
     if path and #path.waypoints>=8 and path.yards>=50 then walked=path end
    end
 end
 if walked then break end
end
assert(walked,"real multi-segment quest-area route")
print(("PASS actual multi-segment quest-area route %.1f yd, %d coordinates"):format(walked.yards,#walked.waypoints))
